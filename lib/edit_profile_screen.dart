import 'vitail_loading.dart';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dog_date_picker.dart';
import 'exercise_data.dart';
import 'onboarding_view.dart' show DogWeightInputFormatter;

/// Full-screen "Edit profile" editor for the dog's details (Figma design).
/// Pushed from the pencil badge on the Profile screen; pops with `true`
/// when changes were saved so the caller can refresh.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.dog});

  /// The current dog row (all columns), passed from the Profile screen.
  final Map<String, dynamic>? dog;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Design tokens from the Figma file.
  static const background = Color(0xFFF4F0E9);
  static const ink = Color(0xFF211F1D);
  static const muted = Color(0xFF6E6A63);
  static const border = Color(0xFFDAD6CD);
  static const green = Color(0xFFAEC568);
  static const coral = Color(0xFFDC755C);

  final List<String> _breeds = ExerciseCalculator.dogBreeds;

  final _nameController = TextEditingController();
  final _weightController = TextEditingController();

  String? _selectedSex;
  String? _selectedBreed;
  String _initialBreed = '';
  DateTime? _birthday;
  XFile? _newPhoto;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final dog = widget.dog;
    if (dog == null) return;
    _nameController.text = (dog['dog_name'] ?? '') as String;
    _selectedSex = (dog['sex'] ?? 'Male') as String?;
    final breed = dog['breed'] as String?;
    _initialBreed = breed ?? '';
    _selectedBreed = breed != null && _breeds.contains(breed) ? breed : null;
    final weight = (dog['weight'] as num?)?.toDouble();
    _weightController.text = weight == null
        ? ''
        : (weight == weight.roundToDouble()
            ? weight.toInt().toString()
            : weight.toStringAsFixed(1));
    final rawBirthday = dog['birthday'];
    if (rawBirthday != null) {
      final parsed = DateTime.tryParse(rawBirthday.toString());
      if (parsed != null) {
        _birthday = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ helpers

  TextStyle style(double size,
          {Color color = ink, FontWeight weight = FontWeight.w600}) =>
      TextStyle(fontFamily: 'PlusJakartaSans',
          fontSize: size, fontWeight: weight, color: color);

  Widget icon(String name) => SvgPicture.asset('assets/icons/onboarding-$name.svg',
      width: 24, height: 24);

  InputDecoration decoration(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: muted, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        suffixIcon: suffix == null
            ? null
            : Padding(padding: const EdgeInsets.all(12), child: suffix),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: coral)),
      );

  Widget field(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: style(13)),
          const SizedBox(height: 8),
          child,
        ],
      );

  ImageProvider? get _avatarImage {
    if (_newPhoto != null) return FileImage(File(_newPhoto!.path));
    final url = widget.dog?['photo_url'];
    if (url is String && url.isNotEmpty) return CachedNetworkImageProvider(url);
    return null;
  }

  /// Whole years since the selected birthday (drives the read-only Age box).
  int get _ageYears {
    final b = _birthday;
    if (b == null) return 0;
    final now = DateTime.now();
    int years = now.year - b.year;
    int months = now.month - b.month;
    if (months < 0) {
      years--;
      months += 12;
    }
    return years;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  // ------------------------------------------------------------------ actions

  Future<void> _pickPhoto() async {
    FocusScope.of(context).unfocus();
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 70,
    );
    if (image != null && mounted) setState(() => _newPhoto = image);
  }

  Future<void> _pickBirthday() async {
    final picked = await showDogDatePicker(context, initialDate: _birthday);
    if (picked != null && mounted) setState(() => _birthday = picked);
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    final dog = widget.dog;
    if (dog == null) return;

    final name = _nameController.text.trim();
    final weight = double.tryParse(_weightController.text.trim());

    if (name.isEmpty) {
      _snack("Please enter your dog's name");
      return;
    }
    if (_selectedSex == null) {
      _snack('Please select a sex');
      return;
    }
    if (_birthday == null) {
      _snack('Please select a date of birth');
      return;
    }
    if (_selectedBreed == null) {
      _snack('Please select a breed from the list');
      return;
    }
    if (weight == null || weight <= 0) {
      _snack('Please enter a valid weight');
      return;
    }

    setState(() => _isSaving = true);
    final client = Supabase.instance.client;
    final dogId = dog['id'] as String;

    try {
      // 1. Upload the new photo (only if one was picked).
      String? photoUrl;
      if (_newPhoto != null) {
        final fileName =
            'dog_${dogId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await client.storage.from('dog_photos').upload(fileName, File(_newPhoto!.path));
        photoUrl = client.storage.from('dog_photos').getPublicUrl(fileName);
      }

      // 2. If the weight changed, record it through log_weight so the
      //    weight-history graph (and the daily quest) stay in sync.
      final oldWeight = (dog['weight'] as num?)?.toDouble();
      final weightChanged =
          oldWeight == null || (oldWeight - weight).abs() > 0.001;
      if (weightChanged) {
        final now = DateTime.now();
        final today =
            DateTime(now.year, now.month, now.day).toIso8601String().split('T')[0];
        await client.rpc('log_weight', params: {
          'p_dog_id': dogId,
          'p_weight_kg': weight,
          'p_recorded_date': today,
        });
      }

      // 3. Recalculate the exercise recommendation with the (possibly new)
      //    breed / age / weight — same formula as onboarding.
      final now = DateTime.now();
      final birthday = _birthday!;
      int years = now.year - birthday.year;
      int months = now.month - birthday.month;
      if (months < 0) {
        years--;
        months += 12;
      }
      final ageYears = years + months / 12;

      final target = ExerciseCalculator.calculate(
        breed: _selectedBreed!,
        weightKg: weight,
        ageYears: ageYears,
        ownerActivityLevel: (dog['owner_activity_level'] as String?) ?? 'moderate',
      );

      // 4. Persist everything to the dogs table.
      await client.from('dogs').update({
        'dog_name': name,
        'sex': _selectedSex,
        'breed': _selectedBreed,
        'birthday': birthday.toIso8601String().split('T')[0],
        'weight': weight,
        'daily_goal_minutes': target['targetMinutes'],
        'daily_goal_km': target['kmTarget'],
        if (photoUrl != null) 'photo_url': photoUrl,
      }).eq('id', dogId);

      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _snack('Could not save changes: ${e.message}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        _snack('Network error: could not save. Check your connection.');
      }
    }
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Figma-faithful light theme, same approach as the onboarding screen.
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'PlusJakartaSans',
        colorScheme: ColorScheme.fromSeed(seedColor: coral),
        textTheme: ThemeData.light().textTheme.apply(
            fontFamily: 'PlusJakartaSans', bodyColor: ink, displayColor: ink),
      ),
      child: PopScope(
        canPop: !_isSaving,
        child: Scaffold(
          backgroundColor: background,
          body: SafeArea(
            child: widget.dog == null
                ? Center(
                    child: Text('No dog profile found.',
                        style: style(15, color: muted)))
                : SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildAvatarSection(),
                              const SizedBox(height: 16),
                              field(
                                'Name *',
                                TextField(
                                  controller: _nameController,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  decoration:
                                      decoration("What's your dog's name?"),
                                ),
                              ),
                              const SizedBox(height: 16),
                              field('Sex *', _buildSexSelector()),
                              const SizedBox(height: 16),
                              field('Date of birth *', _buildBirthdayField()),
                              const SizedBox(height: 16),
                              field('Breed *', _buildBreedField()),
                              const SizedBox(height: 16),
                              _buildAgeWeightRow(),
                              const SizedBox(height: 32),
                              _buildSaveButton(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child:
              Text('Edit profile', style: style(22, weight: FontWeight.w700)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Back',
            onPressed:
                _isSaving ? null : () => Navigator.maybePop(context),
            icon: SvgPicture.asset('assets/icons/onboarding-back.svg',
                width: 24, height: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarSection() {
    final image = _avatarImage;
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: border,
          backgroundImage: image,
          child: image == null
              ? SvgPicture.asset('assets/icons/onboarding-camera.svg',
                  width: 24, height: 24)
              : null,
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _isSaving ? null : _pickPhoto,
          style: ElevatedButton.styleFrom(
            backgroundColor: coral,
            foregroundColor: Colors.white,
            disabledBackgroundColor: coral.withValues(alpha: 0.6),
            elevation: 0,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
            textStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          child: const Text('Change photo'),
        ),
      ],
    );
  }

  Widget _buildSexSelector() {
    return Row(children: [
      for (final value in ['Male', 'Female']) ...[
        if (value == 'Female') const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            selected: _selectedSex == value,
            child: OutlinedButton(
              onPressed: _isSaving
                  ? null
                  : () => setState(() => _selectedSex = value),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _selectedSex == value ? green : Colors.white,
                foregroundColor: _selectedSex == value ? Colors.white : ink,
                side: BorderSide(
                    color: _selectedSex == value ? green : border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(value.toUpperCase(),
                  style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _buildBirthdayField() {
    final hasBirthday = _birthday != null;
    return TextField(
      readOnly: true,
      controller: null,
      onTap: _isSaving ? null : _pickBirthday,
      decoration: decoration(
        hasBirthday
            ? DateFormat('d MMMM yyyy').format(_birthday!)
            : 'Select date of birth',
        suffix: icon('calendar'),
      ).copyWith(
        hintStyle:
            TextStyle(color: hasBirthday ? ink : muted, fontSize: 14),
      ),
    );
  }

  Widget _buildBreedField() {
    return LayoutBuilder(builder: (context, constraints) {
      return Autocomplete<String>(
        initialValue: TextEditingValue(text: _initialBreed),
        optionsBuilder: (value) => _breeds
            .where((b) => b.toLowerCase().contains(value.text.toLowerCase())),
        onSelected: (breed) => setState(() => _selectedBreed = breed),
        optionsViewBuilder: (context, select, options) {
          final matches = options.toList();
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: constraints.maxWidth,
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(14)),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final highlighted =
                        AutocompleteHighlightedOption.of(context) == index;
                    return InkWell(
                      onTap: () => select(matches[index]),
                      child: Container(
                        color: highlighted ? background : Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Text(matches[index],
                            style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                color: ink,
                                fontWeight: FontWeight.w500)),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
        fieldViewBuilder: (context, controller, focus, submit) => TextField(
          controller: controller,
          focusNode: focus,
          onChanged: (value) => setState(
              () => _selectedBreed = _breeds.contains(value) ? value : null),
          decoration: decoration('Select breed', suffix: icon('chevron')),
        ),
      );
    });
  }

  Widget _buildAgeWeightRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field('Age (years)', _buildAgeField())),
        const SizedBox(width: 13),
        Expanded(
          child: field(
            'Weight (kg)',
            TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [DogWeightInputFormatter()],
              decoration: decoration('E.g. 12'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgeField() {
    // Age is derived from date of birth — a live preview, not an input.
    // Styled flat/recessed (page-coloured fill) so it reads as a computed
    // value sitting next to the crisp white Weight input.
    final hasBirthday = _birthday != null;
    return Semantics(
      label: hasBirthday ? 'Age: $_ageYears years' : 'Age not set',
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: background, // same beige as the page — reads as "not editable"
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Text(
          hasBirthday ? '$_ageYears' : '—',
          style: style(14,
              color: hasBirthday ? ink : muted, weight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: coral,
          foregroundColor: Colors.white,
          disabledBackgroundColor: coral.withValues(alpha: 0.6),
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: VitailLoading())
            : const Text('Save changes',
                style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
      ),
    );
  }
}