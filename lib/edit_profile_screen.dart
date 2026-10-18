import 'vitail_colors.dart';
import 'dart:io';
import 'vitail_back_button.dart';

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
import 'vitail_snack.dart';

/// Full-screen "Edit profile" editor for the dog's details (Figma design).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.dog});

  /// The current dog row (all columns), passed from the Profile screen.
  final Map<String, dynamic>? dog;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get background => Theme.of(context).colorScheme.surface;
  Color get ink => Theme.of(context).colorScheme.onSurface;
  Color get muted => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get border => Theme.of(context).colorScheme.outline;
  Color get green => Theme.of(context).colorScheme.tertiary;
  Color get coral => Theme.of(context).colorScheme.primary;
  Color get fieldFill => _isDark ? const Color(0xFF1E1E1E) : Colors.white;

  final List<String> _breeds = ExerciseCalculator.dogBreeds;

  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _dailyMinutesController = TextEditingController();
  final _dailyKmController = TextEditingController();

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

    final minutes = dog['daily_goal_minutes'];
    if (minutes != null) {
      _dailyMinutesController.text = minutes.toString();
    }

    final km = (dog['daily_goal_km'] as num?)?.toDouble();
    if (km != null) {
      _dailyKmController.text = km == km.roundToDouble()
          ? km.toInt().toString()
          : km.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _dailyMinutesController.dispose();
    _dailyKmController.dispose();
    super.dispose();
  }

  TextStyle style(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) => TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: size,
    fontWeight: weight,
    color: color ?? ink,
  );

  Widget icon(String name) => SvgPicture.asset(
    'assets/icons/onboarding-$name.svg',
    width: 24,
    height: 24,
    colorFilter: _isDark
        ? const ColorFilter.mode(Color(0xFFF4F0E9), BlendMode.srcIn)
        : null,
  );

  InputDecoration decoration(String hint, {Widget? suffix}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: muted, fontSize: 14),
    filled: true,
    fillColor: fieldFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    suffixIcon: suffix == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [suffix],
            ),
          ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: coral),
    ),
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
    final manualMins = int.tryParse(_dailyMinutesController.text.trim());
    final manualKm = double.tryParse(_dailyKmController.text.trim());

    if (name.isEmpty) {
      showVitailSnack(
        context,
        "Please enter your dog's name",
        type: VitailSnackType.error,
      );
      return;
    }
    if (_selectedSex == null) {
      showVitailSnack(
        context,
        'Please select a sex',
        type: VitailSnackType.error,
      );
      return;
    }
    if (_birthday == null) {
      showVitailSnack(
        context,
        'Please select a date of birth',
        type: VitailSnackType.error,
      );
      return;
    }
    if (_selectedBreed == null) {
      showVitailSnack(
        context,
        'Please select a breed from the list',
        type: VitailSnackType.error,
      );
      return;
    }
    if (weight == null || weight <= 0) {
      showVitailSnack(
        context,
        'Please enter a valid weight',
        type: VitailSnackType.error,
      );
      return;
    }

    setState(() => _isSaving = true);
    final client = Supabase.instance.client;
    final dogId = dog['id'] as String;

    try {
      // 1. Upload new photo if picked
      String? photoUrl;
      if (_newPhoto != null) {
        final fileName =
            'dog_${dogId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await client.storage
            .from('dog_photos')
            .upload(fileName, File(_newPhoto!.path));
        photoUrl = client.storage.from('dog_photos').getPublicUrl(fileName);
      }

      // 2. Log weight if changed
      final oldWeight = (dog['weight'] as num?)?.toDouble();
      final weightChanged =
          oldWeight == null || (oldWeight - weight).abs() > 0.001;
      if (weightChanged) {
        final now = DateTime.now();
        final today = DateTime(
          now.year,
          now.month,
          now.day,
        ).toIso8601String().split('T')[0];
        await client.rpc(
          'log_weight',
          params: {
            'p_dog_id': dogId,
            'p_weight_kg': weight,
            'p_recorded_date': today,
          },
        );
      }

      // 3. Fallback calculation if daily goals left empty
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
        ownerActivityLevel:
            (dog['owner_activity_level'] as String?) ?? 'moderate',
        healthCondition: (dog['health_condition'] as String?) ?? 'no_condition',
      );

      // 4. Update the dog row with manual goals if provided
      await client
          .from('dogs')
          .update({
            'dog_name': name,
            'sex': _selectedSex,
            'breed': _selectedBreed,
            'birthday': birthday.toIso8601String().split('T')[0],
            'weight': weight,
            'daily_goal_minutes': manualMins ?? target['targetMinutes'],
            'daily_goal_km': manualKm ?? target['kmTarget'],
            if (photoUrl != null) 'photo_url': photoUrl,
          })
          .eq('id', dogId);

      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostgrestException {
      if (mounted) {
        setState(() => _isSaving = false);
        showVitailSnack(
          context,
          'Could not save changes. Please try again.',
          type: VitailSnackType.error,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        showVitailSnack(
          context,
          'Network error: could not save. Check your connection.',
          type: VitailSnackType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: widget.dog == null
              ? Center(
                  child: Text(
                    'No dog profile found.',
                    style: style(15, color: muted),
                  ),
                )
              : SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildAvatarSection(),
                            const SizedBox(height: 20),
                            field(
                              'Name *',
                              TextField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: decoration(
                                  "What's your dog's name?",
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            field('Sex *', _buildSexSelector()),
                            const SizedBox(height: 16),
                            field('Date of birth', _buildBirthdayField()),
                            const SizedBox(height: 16),
                            field('Breed', _buildBreedField()),
                            const SizedBox(height: 16),
                            _buildAgeWeightRow(),
                            const SizedBox(height: 24),
                            _buildDailyGoalsSection(),
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
    );
  }

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(
            'Edit profile',
            style: style(22, weight: FontWeight.w700),
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: VitailBackButton(
            onPressed: _isSaving ? null : () => Navigator.maybePop(context),
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
          radius: 46,
          backgroundColor: VitailColors.of(
            context,
          ).tint(const Color(0xFFE2DDD5), VitailColors.of(context).avatar),
          backgroundImage: image,
          child: image == null
              ? SvgPicture.asset(
                  'assets/icons/onboarding-camera.svg',
                  width: 28,
                  height: 28,
                  colorFilter: _isDark
                      ? ColorFilter.mode(muted, BlendMode.srcIn)
                      : null,
                )
              : null,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _isSaving ? null : _pickPhoto,
          style: ElevatedButton.styleFrom(
            backgroundColor: coral,
            foregroundColor: Colors.white,
            disabledBackgroundColor: coral.withValues(alpha: 0.6),
            elevation: 0,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            textStyle: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Change photo'),
        ),
      ],
    );
  }

  Widget _buildSexSelector() {
    return Row(
      children: [
        for (final value in ['Male', 'Female']) ...[
          if (value == 'Female') const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              selected: _selectedSex == value,
              child: OutlinedButton(
                onPressed: _isSaving
                    ? null
                    : () => setState(() => _selectedSex = value),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: _selectedSex == value ? green : fieldFill,
                  foregroundColor: _selectedSex == value ? Colors.white : ink,
                  side: BorderSide(
                    color: _selectedSex == value ? green : border,
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  value.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBirthdayField() {
    final hasBirthday = _birthday != null;
    return TextField(
      readOnly: true,
      controller: null,
      onTap: _isSaving ? null : _pickBirthday,
      decoration:
          decoration(
            hasBirthday
                ? DateFormat('d MMMM yyyy').format(_birthday!)
                : 'Select date of birth',
            suffix: icon('calendar'),
          ).copyWith(
            hintStyle: TextStyle(
              color: hasBirthday ? ink : muted,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
    );
  }

  Widget _buildBreedField() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<String>(
          initialValue: TextEditingValue(text: _initialBreed),
          optionsBuilder: (value) => _breeds.where(
            (b) => b.toLowerCase().contains(value.text.toLowerCase()),
          ),
          onSelected: (breed) => setState(() => _selectedBreed = breed),
          optionsViewBuilder: (context, select, options) {
            final matches = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: fieldFill,
                elevation: 4,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  width: constraints.maxWidth,
                  constraints: const BoxConstraints(maxHeight: 240),
                  decoration: BoxDecoration(
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                          color: highlighted ? background : fieldFill,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Text(
                            matches[index],
                            style: style(14, weight: FontWeight.w500),
                          ),
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
              () => _selectedBreed = _breeds.contains(value) ? value : null,
            ),
            decoration: decoration('Select breed', suffix: icon('chevron')),
          ),
        );
      },
    );
  }

  Widget _buildAgeWeightRow() {
    final hasBirthday = _birthday != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: field(
            'Age (years)',
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: fieldFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Text(
                hasBirthday ? '$_ageYears' : '—',
                style: style(
                  15,
                  color: hasBirthday ? ink : muted,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: field(
            'Weight (kg)',
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [DogWeightInputFormatter()],
              decoration: decoration('12'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyGoalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily goals', style: style(18, weight: FontWeight.w700)),
        const SizedBox(height: 12),
        field(
          'Daily activity (minutes)',
          TextField(
            controller: _dailyMinutesController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: decoration(
              '30',
              suffix: Text(
                'min / day',
                style: TextStyle(
                  color: muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        field(
          'Daily distance (km)',
          TextField(
            controller: _dailyKmController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: decoration(
              '2.0',
              suffix: Text(
                'km / day',
                style: TextStyle(
                  color: muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set a goal that suits your dog’s routine.',
          style: style(12.5, color: muted, weight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 56,
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
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Save changes',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
