import 'onboarding_style.dart';
import 'vitail_colors.dart';
import 'vitail_loading.dart';
import 'vitail_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({
    super.key,
    required this.nameController,
    required this.weightController,
    required this.sex,
    required this.onSex,
    required this.birthdayLabel,
    this.hasBirthday = false,
    required this.onBirthday,
    required this.breeds,
    required this.onBreed,
    required this.onPhoto,
    required this.onNext,
    required this.ownerActivityLevel,
    required this.onOwnerActivityChanged,
    required this.loading,
    this.photo,
    required this.deSexed,
    required this.onDeSexed,
    required this.colourController,
    required this.healthImpact,
    required this.onHealthImpact,
  });

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

  final String? deSexed;
  final ValueChanged<String> onDeSexed;

  final TextEditingController colourController;

  final String? healthImpact;
  final ValueChanged<String> onHealthImpact;

  static const List<String> healthOptions = [
    'No condition',
    "Doesn't affect activity",
    'Moderately affects activity',
    'Heavily affects activity',
  ];

  Widget icon(BuildContext context, String name) => SvgPicture.asset(
    'assets/icons/onboarding-$name.svg',
    width: 24,
    height: 24,
    colorFilter: VitailColors.of(context).isDark
        ? ColorFilter.mode(OnboardingStyle.of(context).muted, BlendMode.srcIn)
        : null,
  );

  InputDecoration decoration(
    BuildContext context,
    String hint, {
    Widget? suffix,
  }) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: VitailColors.of(context).card,
    hintStyle: TextStyle(
      color: OnboardingStyle.of(context).muted,
      fontSize: 14,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    suffixIcon: suffix == null
        ? null
        : Padding(padding: const EdgeInsets.all(14), child: suffix),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: OnboardingStyle.of(context).border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: OnboardingStyle.of(context).border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: OnboardingStyle.of(context).coral),
    ),
  );

  Widget field(
    BuildContext context,
    String label,
    Widget child, {
    String? hint,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (hint != null)
            Text(
              hint,
              style: TextStyle(
                fontSize: 12,
                color: OnboardingStyle.of(context).muted,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      child,
    ],
  );

  Widget choiceRow(
    BuildContext context,
    List<String> values,
    String? selected,
    ValueChanged<String> onChanged, {
    bool upper = true,
  }) => Row(
    children: [
      for (final value in values) ...[
        if (value != values.first) const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            selected: selected == value,
            child: OutlinedButton(
              onPressed: loading ? null : () => onChanged(value),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                backgroundColor: selected == value
                    ? OnboardingStyle.of(context).green
                    : VitailColors.of(context).card,
                foregroundColor: selected == value
                    ? VitailColors.of(
                        context,
                      ).tint(Colors.white, const Color(0xFF211F1D))
                    : OnboardingStyle.of(context).ink,
                side: BorderSide(
                  color: selected == value
                      ? OnboardingStyle.of(context).green
                      : OnboardingStyle.of(context).border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: FittedBox(
                child: Text(
                  upper ? value.toUpperCase() : value,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );

  Widget dropdown(
    BuildContext context,
    String hint,
    String? value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: VitailColors.of(context).card,
      border: Border.all(color: OnboardingStyle.of(context).border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        hint: Text(
          hint,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: OnboardingStyle.of(context).muted,
            fontSize: 14,
          ),
        ),
        dropdownColor: VitailColors.of(context).card,
        borderRadius: BorderRadius.circular(14),
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          color: OnboardingStyle.of(context).ink,
        ),
        icon: icon(context, 'chevron'),
        items: [
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: loading
            ? null
            : (selected) {
                if (selected != null) onChanged(selected);
              },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      useMaterial3: true,
      brightness: Theme.of(context).brightness,
      fontFamily: 'PlusJakartaSans',
      colorScheme: Theme.of(context).colorScheme,
      textTheme: Theme.of(context).textTheme.apply(
        fontFamily: 'PlusJakartaSans',
        bodyColor: OnboardingStyle.of(context).ink,
        displayColor: OnboardingStyle.of(context).ink,
      ),
    ),
    child: Scaffold(
      backgroundColor: OnboardingStyle.of(context).background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (Navigator.canPop(context))
              VitailBackButton(
                color: OnboardingStyle.of(context).ink,
                onPressed: loading ? null : () => Navigator.maybePop(context),
              ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        28,
                        Navigator.canPop(context) ? 0 : 26,
                        28,
                        32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Tell us about your dog',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Photo
                          Center(
                            child: Semantics(
                              button: true,
                              label: 'Choose dog photo',
                              child: InkWell(
                                onTap: loading ? null : onPhoto,
                                borderRadius: BorderRadius.circular(40),
                                child: SizedBox(
                                  width: 88,
                                  height: 86,
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 40,
                                        backgroundColor: OnboardingStyle.of(
                                          context,
                                        ).border,
                                        backgroundImage: photo,
                                        child: photo == null
                                            ? icon(context, 'camera')
                                            : null,
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: OnboardingStyle.of(
                                            context,
                                          ).green,
                                          child: SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 12,
                                                  height: 2,
                                                  child: ColoredBox(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 2,
                                                  height: 12,
                                                  child: ColoredBox(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          field(
                            context,
                            'Name *',
                            TextField(
                              controller: nameController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: decoration(
                                context,
                                "What's your dog's name?",
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          field(
                            context,
                            'Sex *',
                            choiceRow(
                              context,
                              const ['Male', 'Female'],
                              sex,
                              onSex,
                            ),
                          ),
                          const SizedBox(height: 16),

                          field(
                            context,
                            'De-sexed *',
                            choiceRow(
                              context,
                              const ['Yes', 'No'],
                              deSexed,
                              onDeSexed,
                            ),
                          ),
                          const SizedBox(height: 16),

                          field(
                            context,
                            'Weight *',
                            TextField(
                              controller: weightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [DogWeightInputFormatter()],
                              decoration: decoration(
                                context,
                                'E.g. 12',
                                suffix: const Text('kg'),
                              ),
                            ),
                            hint: 'Helps set a walk goal',
                          ),
                          const SizedBox(height: 16),

                          field(
                            context,
                            'Breed *',
                            LayoutBuilder(
                              builder: (context, constraints) => Autocomplete<String>(
                                optionsViewOpenDirection:
                                    OptionsViewOpenDirection.up,
                                optionsBuilder: (value) => breeds.where(
                                  (breed) => breed.toLowerCase().contains(
                                    value.text.toLowerCase(),
                                  ),
                                ),
                                onSelected: onBreed,
                                optionsViewBuilder: (context, select, options) {
                                  final matches = options.toList();
                                  return Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Material(
                                      color: VitailColors.of(context).card,
                                      elevation: 4,
                                      borderRadius: BorderRadius.circular(14),
                                      clipBehavior: Clip.antiAlias,
                                      child: Container(
                                        width: constraints.maxWidth,
                                        constraints: const BoxConstraints(
                                          maxHeight: 240,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: OnboardingStyle.of(
                                              context,
                                            ).border,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: ListView.builder(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          shrinkWrap: true,
                                          itemCount: matches.length,
                                          itemBuilder: (context, index) {
                                            final highlighted =
                                                AutocompleteHighlightedOption.of(
                                                  context,
                                                ) ==
                                                index;
                                            return InkWell(
                                              onTap: () =>
                                                  select(matches[index]),
                                              child: Container(
                                                color: highlighted
                                                    ? OnboardingStyle.of(
                                                        context,
                                                      ).background
                                                    : VitailColors.of(
                                                        context,
                                                      ).card,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 14,
                                                    ),
                                                child: Text(
                                                  matches[index],
                                                  style: TextStyle(
                                                    fontFamily:
                                                        'PlusJakartaSans',
                                                    fontSize: 14,
                                                    color: OnboardingStyle.of(
                                                      context,
                                                    ).ink,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                fieldViewBuilder:
                                    (context, controller, focus, submit) =>
                                        TextField(
                                          controller: controller,
                                          focusNode: focus,
                                          onChanged: (value) => onBreed(
                                            breeds.contains(value)
                                                ? value
                                                : null,
                                          ),
                                          decoration: decoration(
                                            context,
                                            'Select breed',
                                            suffix: icon(context, 'chevron'),
                                          ),
                                        ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          field(
                            context,
                            'Colour / markings',
                            TextField(
                              controller: colourController,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              decoration: decoration(
                                context,
                                'E.g. Black & white',
                              ),
                            ),
                            hint: 'optional',
                          ),
                          const SizedBox(height: 16),

                          field(
                            context,
                            'Date of birth *',
                            TextField(
                              readOnly: true,
                              onTap: loading ? null : onBirthday,
                              controller: null,
                              decoration:
                                  decoration(
                                    context,
                                    birthdayLabel,
                                    suffix: icon(context, 'calendar'),
                                  ).copyWith(
                                    hintStyle: TextStyle(
                                      color: hasBirthday
                                          ? OnboardingStyle.of(context).ink
                                          : OnboardingStyle.of(context).muted,
                                      fontSize: 14,
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          field(
                            context,
                            'Health condition *',
                            dropdown(
                              context,
                              'Select an option',
                              healthImpact,
                              healthOptions,
                              onHealthImpact,
                            ),
                          ),
                          const SizedBox(height: 16),

                          field(
                            context,
                            "Your dog's activity level *",
                            choiceRow(
                              context,
                              const ['Low', 'Moderate', 'High'],
                              ownerActivityLevel.isEmpty
                                  ? null
                                  : ownerActivityLevel[0].toUpperCase() +
                                        ownerActivityLevel.substring(1),
                              (value) =>
                                  onOwnerActivityChanged(value.toLowerCase()),
                            ),
                          ),
                          const SizedBox(height: 32),

                          ElevatedButton(
                            onPressed: loading ? null : onNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: OnboardingStyle.of(
                                context,
                              ).coral,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(56),
                              elevation: 0,
                              shape: const StadiumBorder(),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: VitailLoading(),
                                  )
                                : const Text(
                                    'Next',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class DogWeightInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d+(\.\d*)?$').hasMatch(text)) return oldValue;
    final weight = double.tryParse(text);
    return weight != null && weight >= 0 && weight <= 100 ? newValue : oldValue;
  }
}
