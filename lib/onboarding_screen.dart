import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'onboarding_view.dart';
import 'dog_date_picker.dart';
import 'dog_photo_sheet.dart';
import 'exercise_data.dart';
import 'high_paw_screen.dart';
import 'onboarding_goal_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _dogNameController = TextEditingController();
  final _weightController = TextEditingController();
  final _colourController = TextEditingController();
  
  String? _selectedBreed;
  DateTime? _birthday;
  String? _selectedSex;
    String? _deSexed;
  String? _walkTime;
  XFile? _imageFile;
  bool _isLoading = false;
  String _ownerActivityLevel = 'moderate';

  bool _dogSaved = false;
  int? _dailyGoalMins;
  double? _dailyGoalKm;

  Future<void> _pickImage() async {
    FocusScope.of(context).unfocus();
    final browse = await showDogPhotoSheet(context,
      photo: _imageFile == null ? null : FileImage(File(_imageFile!.path)));
    if (browse != true || !mounted) return;
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 70,
    );
    if (image != null && mounted) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  Future<void> _pickBirthday() async {
    final picked = await showDogDatePicker(context, initialDate: _birthday);
    if (picked != null && mounted) {
      setState(() {
        _birthday = picked;
      });
    }
  }

    Future<void> _saveToDatabase() async {
    if (_dogNameController.text.trim().isEmpty ||
        !['Male', 'Female'].contains(_selectedSex)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (!_dogSaved) {
        final userId = Supabase.instance.client.auth.currentUser!.id;

        double age = 0.0;
        final today = DateTime.now();
        int years = today.year - _birthday!.year;
        int months = today.month - _birthday!.month;
        if (months < 0) {
          years--;
          months += 12;
        }
        age = years + (months / 12);

        double weight = double.tryParse(_weightController.text.trim()) ?? 0.0;
        String? photoUrl;

        if (_imageFile != null) {
          final fileName = '${userId}_dog_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await Supabase.instance.client.storage.from('dog_photos').upload(fileName, File(_imageFile!.path));
          photoUrl = Supabase.instance.client.storage.from('dog_photos').getPublicUrl(fileName);
        }

        var target = ExerciseCalculator.calculate(
          breed: _selectedBreed!,
          weightKg: weight,
          ageYears: age,
          ownerActivityLevel: _ownerActivityLevel,
        );

        _dailyGoalMins = target['targetMinutes'];
        _dailyGoalKm = target['kmTarget'];

        final dogResponse = await Supabase.instance.client.from('dogs').insert({
          'owner_id': userId,
          'dog_name': _dogNameController.text.trim(),
          'breed': _selectedBreed,
          'weight': weight,
          'birthday': _birthday!.toIso8601String().split('T')[0],
          'sex': _selectedSex,
          'photo_url': photoUrl,
          'daily_goal_minutes': _dailyGoalMins,
          'daily_goal_km': _dailyGoalKm,
          'owner_activity_level': _ownerActivityLevel,
        }).select().single();

        await Supabase.instance.client.from('weight_history').insert({
          'dog_id': dogResponse['id'],
          'weight_kg': weight,
          'recorded_date': DateTime.now().toIso8601String(),
        });

        _dogSaved = true;
      }

      if (!mounted) return;

      startOnboardingGoals(
        context,
        nextScreenBuilder: (goals) {
          debugPrint('Onboarding goals: $goals');
          return HighPawScreen(
            dogName: _dogNameController.text.trim(),
            dailyGoalMins: _dailyGoalMins!,
            dailyGoalKm: _dailyGoalKm!,
            breed: _selectedBreed,
          );
        },
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Database Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _dogNameController.dispose();
    _weightController.dispose();
    _colourController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OnboardingView(
    nameController: _dogNameController,
    weightController: _weightController,
    sex: _selectedSex,
    onSex: (sex) => setState(() => _selectedSex = sex),
    hasBirthday: _birthday != null,
    birthdayLabel: _birthday == null ? 'Select date of birth' : DateFormat('MMM d, yyyy').format(_birthday!),
    onBirthday: _pickBirthday,
    breeds: ExerciseCalculator.dogBreeds,
    onBreed: (breed) => _selectedBreed = breed,
    onPhoto: _pickImage,
    photo: _imageFile == null ? null : FileImage(File(_imageFile!.path)),
    ownerActivityLevel: _ownerActivityLevel,
    onOwnerActivityChanged: (level) => setState(() => _ownerActivityLevel = level),
    onNext: _saveToDatabase,
    loading: _isLoading,
    deSexed: _deSexed,
    onDeSexed: (value) => setState(() => _deSexed = value),
    colourController: _colourController,
    walkTime: _walkTime,
    onWalkTime: (value) => setState(() => _walkTime = value),
  );
}