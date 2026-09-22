import 'vitail_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key, required this.nameController,
    required this.weightController, required this.sex, required this.onSex,
    required this.birthdayLabel, this.hasBirthday = false, required this.onBirthday, required this.breeds,
    required this.onBreed, required this.onPhoto, required this.onNext,
    required this.ownerActivityLevel, required this.onOwnerActivityChanged,
    required this.loading, this.photo});
  
  final TextEditingController nameController, weightController;
  final String? sex;
  final String birthdayLabel;
  final bool hasBirthday;
  final ValueChanged<String> onSex;
  final ValueChanged<String?> onBreed;
  final List<String> breeds;
  final VoidCallback onBirthday, onPhoto, onNext;
  final String ownerActivityLevel; // 'low', 'moderate', 'high'
  final ValueChanged<String> onOwnerActivityChanged;
  final bool loading;
  final ImageProvider? photo;
  
  static const background = Color(0xFFF4F0E9);
  static const ink = Color(0xFF211F1D);
  static const border = Color(0xFFDAD6CD);
  static const green = Color(0xFFAEC568);
  static const coral = Color(0xFFCD533B);

  Widget icon(String name) => SvgPicture.asset('assets/icons/onboarding-$name.svg', width: 24, height: 24);
  InputDecoration decoration(String hint, {Widget? suffix}) => InputDecoration(
    hintText: hint, filled: true, fillColor: Colors.white,
    hintStyle: const TextStyle(color: Color(0xFF6E6A63), fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    suffixIcon: suffix == null ? null : Padding(padding: const EdgeInsets.all(14), child: suffix),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: coral)),
  );
  Widget field(String label, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    const SizedBox(height: 6), child,
  ]);

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(useMaterial3: true, brightness: Brightness.light,
      fontFamily: 'PlusJakartaSans', colorScheme: ColorScheme.fromSeed(seedColor: coral),
      textTheme: ThemeData.light().textTheme.apply(fontFamily: 'PlusJakartaSans', bodyColor: ink, displayColor: ink)),
    child: Scaffold(backgroundColor: background,
      body: SafeArea(child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(padding: const EdgeInsets.fromLTRB(28, 26, 28, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                const Text('Tell us about your dog', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                if (Navigator.canPop(context)) Positioned(left: -24, top: -6,
                  child: IconButton(tooltip: 'Back', onPressed: loading ? null : () => Navigator.maybePop(context),
                    icon: icon('back'))),
              ]),
              const SizedBox(height: 32),
              Center(child: Semantics(button: true, label: 'Choose dog photo',
                child: InkWell(onTap: loading ? null : onPhoto, borderRadius: BorderRadius.circular(40),
                  child: SizedBox(width: 88, height: 86, child: Stack(children: [
                    CircleAvatar(radius: 40, backgroundColor: border, backgroundImage: photo,
                      child: photo == null ? icon('camera') : null),
                    const Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 14, backgroundColor: green,
                      child: SizedBox(width: 12, height: 12, child: Stack(alignment: Alignment.center, children: [
                        SizedBox(width: 12, height: 2, child: ColoredBox(color: Colors.white)),
                        SizedBox(width: 2, height: 12, child: ColoredBox(color: Colors.white)),
                      ])))),
                  ])),
                ))),
              const SizedBox(height: 16),
              field('Name *', TextField(controller: nameController, textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next, decoration: decoration("What's your dog's name?"))),
              const SizedBox(height: 16),
              field('Sex *', Row(children: [for (final value in ['Male', 'Female']) ...[
                if (value == 'Female') const SizedBox(width: 10),
                Expanded(child: Semantics(selected: sex == value,
                  child: OutlinedButton(onPressed: loading ? null : () => onSex(value),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52),
                      backgroundColor: sex == value ? green : Colors.white,
                      foregroundColor: sex == value ? Colors.white : ink,
                      side: BorderSide(color: sex == value ? green : border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: Text(value.toUpperCase(), style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w600)))))
              ]])),
              const SizedBox(height: 16),
              field('Date of birth', TextField(readOnly: true, onTap: loading ? null : onBirthday,
                controller: null, decoration: decoration(birthdayLabel, suffix: icon('calendar')).copyWith(
                  hintStyle: TextStyle(color: hasBirthday ? ink : const Color(0xFF6E6A63), fontSize: 14)))),
              const SizedBox(height: 16),
              field('Weight', TextField(controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DogWeightInputFormatter()],
                decoration: decoration('E.g. 12', suffix: const Text('kg')))),
              const SizedBox(height: 16),
              field('Breed', LayoutBuilder(builder: (context, constraints) => Autocomplete<String>(
                optionsViewOpenDirection: OptionsViewOpenDirection.up,
                optionsBuilder: (value) => breeds.where((breed) => breed.toLowerCase().contains(value.text.toLowerCase())),
                onSelected: onBreed,
                optionsViewBuilder: (context, select, options) {
                  final matches = options.toList();
                  return Align(alignment: Alignment.bottomLeft,
                    child: Material(color: Colors.white, elevation: 4,
                      borderRadius: BorderRadius.circular(14), clipBehavior: Clip.antiAlias,
                      child: Container(width: constraints.maxWidth,
                        constraints: const BoxConstraints(maxHeight: 240),
                        decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(14)),
                        child: ListView.builder(padding: const EdgeInsets.symmetric(vertical: 6), shrinkWrap: true,
                          itemCount: matches.length, itemBuilder: (context, index) {
                            final highlighted = AutocompleteHighlightedOption.of(context) == index;
                            return InkWell(onTap: () => select(matches[index]),
                              child: Container(color: highlighted ? background : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                child: Text(matches[index], style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                  fontSize: 14, color: ink, fontWeight: FontWeight.w500))));
                          }),
                      )));
                },
                fieldViewBuilder: (context, controller, focus, submit) => TextField(
                  controller: controller, focusNode: focus,
                  onChanged: (value) => onBreed(breeds.contains(value) ? value : null),
                  decoration: decoration('Select breed', suffix: icon('chevron'))),
              ))),
              const SizedBox(height: 16),
              // NEW: Owner Activity Level Selector
              field('Your activity level *', Row(children: [for (final value in ['Low', 'Moderate', 'High']) ...[
                if (value != 'Low') const SizedBox(width: 10),
                Expanded(child: Semantics(selected: ownerActivityLevel == value.toLowerCase(),
                  child: OutlinedButton(onPressed: loading ? null : () => onOwnerActivityChanged(value.toLowerCase()),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52),
                      backgroundColor: ownerActivityLevel == value.toLowerCase() ? green : Colors.white,
                      foregroundColor: ownerActivityLevel == value.toLowerCase() ? Colors.white : ink,
                      side: BorderSide(color: ownerActivityLevel == value.toLowerCase() ? green : border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: FittedBox(child: Text(value.toUpperCase(), style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w600)))))),
              ]])),
              const SizedBox(height: 32),
              ElevatedButton(onPressed: loading ? null : onNext,
                style: ElevatedButton.styleFrom(backgroundColor: coral, foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56), elevation: 0, shape: const StadiumBorder()),
                child: loading ? const SizedBox(width: 22, height: 22, child: VitailLoading())
                  : const Text('Next', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 16, fontWeight: FontWeight.w600))),
            ]),
          ),
        )),
      )),
    ),
  );
}

/// Allows optional decimal kilograms between 0 and 100, including partial edits.
class DogWeightInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d+(\.\d*)?$').hasMatch(text)) return oldValue;
    final weight = double.tryParse(text);
    return weight != null && weight >= 0 && weight <= 100 ? newValue : oldValue;
  }
}