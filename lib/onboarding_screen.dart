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

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _dogNameController = TextEditingController();
  final _weightController = TextEditingController();
  
  String? _selectedBreed;
  DateTime? _birthday;
  String? _selectedSex;
  XFile? _imageFile;
  bool _isLoading = false;
  String _ownerActivityLevel = 'moderate';

  static const List<String> dogBreeds = [
    'Affenpinscher', 'Afghan Hound', 'Airedale Terrier', 'Akita', 'Alaskan Malamute', 'American Bulldog', 'American Eskimo', 'American Foxhound', 'Australian Cattle Dog', 'Australian Shepherd', 'Australian Terrier', 'Basenji', 'Basset Hound', 'Beagle', 'Bearded Collie', 'Bernese Mountain Dog', 'Bichon Frise', 'Black Russian Terrier', 'Bloodhound', 'Border Collie', 'Border Terrier', 'Borzoi', 'Boston Terrier', 'Bouvier des Flandres', 'Boxer', 'Briard', 'Brittany', 'Brussels Griffon', 'Bull Terrier', 'Bullmastiff', 'Cairn Terrier', 'Canaan Dog', 'Cane Corso', 'Cardigan Welsh Corgi', 'Cavalier King Charles Spaniel', 'Chesapeake Bay Retriever', 'Chihuahua', 'Chinese Crested', 'Chinese Shar-Pei', 'Chow Chow', 'Clumber Spaniel', 'Cocker Spaniel', 'Collie', 'Curly-Coated Retriever', 'Dachshund', 'Dalmatian', 'Dandie Dinmont Terrier', 'Doberman Pinscher', 'English Bulldog', 'English Cocker Spaniel', 'English Foxhound', 'English Setter', 'English Springer Spaniel', 'English Toy Spaniel', 'Entlebucher Mountain Dog', 'Field Spaniel', 'Finnish Lapphund', 'Finnish Spitz', 'Flat-Coated Retriever', 'French Bulldog', 'German Pinscher', 'German Shepherd', 'German Shorthaired Pointer', 'German Wirehaired Pointer', 'Giant Schnauzer', 'Golden Retriever', 'Gordon Setter', 'Great Dane', 'Great Pyrenees', 'Greater Swiss Mountain Dog', 'Greyhound', 'Harrier', 'Havanese', 'Ibizan Hound', 'Icelandic Sheepdog', 'Irish Red and White Setter', 'Irish Setter', 'Irish Terrier', 'Irish Water Spaniel', 'Irish Wolfhound', 'Italian Greyhound', 'Japanese Chin', 'Japanese Spitz', 'Keeshond', 'Kerry Blue Terrier', 'Komondor', 'Kuvasz', 'Labrador Retriever', 'Lakeland Terrier', 'Leonberger', 'Lhasa Apso', 'Lowchen', 'Maltese', 'Manchester Terrier', 'Mastiff', 'Miniature Pinscher', 'Miniature Schnauzer', 'Neapolitan Mastiff', 'Newfoundland', 'Norfolk Terrier', 'Norwegian Buhund', 'Norwegian Elkhound', 'Norwegian Lundehund', 'Old English Sheepdog', 'Otterhound', 'Papillon', 'Pekingese', 'Pembroke Welsh Corgi', 'Petit Basset Griffon Vendeen', 'Pharaoh Hound', 'Pointer', 'Pomeranian', 'Poodle (Miniature)', 'Poodle (Standard)', 'Poodle (Toy)', 'Portuguese Podengo', 'Portuguese Water Dog', 'Pudelpointer', 'Pug', 'Pyrenean Mountain Dog', 'Rat Terrier', 'Redbone Coonhound', 'Rhodesian Ridgeback', 'Rottweiler', 'Saint Bernard', 'Saluki', 'Samoyed', 'Schipperke', 'Scottish Deerhound', 'Scottish Terrier', 'Shetland Sheepdog', 'Shiba Inu', 'Shih Tzu', 'Siberian Husky', 'Silky Terrier', 'Skye Terrier', 'Sloughi', 'Smooth Fox Terrier', 'Soft-Coated Wheaten Terrier', 'Spanish Water Dog', 'Spinone Italiano', 'Staffordshire Bull Terrier', 'Standard Schnauzer', 'Sussex Spaniel', 'Swedish Vallhund', 'Thai Ridgeback', 'Tibetan Mastiff', 'Toy Fox Terrier', 'Treeing Walker Coonhound', 'Welsh Springer Spaniel', 'Welsh Terrier', 'West Highland White Terrier', 'Whippet', 'Wire Fox Terrier', 'Wirehaired Dachshund', 'Wirehaired Pointing Griffon', 'Xoloitzcuintli', 'Yorkshire Terrier'
  ];

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
    if (_dogNameController.text.trim().isEmpty || !['Male', 'Female'].contains(_selectedSex)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
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

      int dailyGoalMins = target['targetMinutes'];
      double dailyGoalKm = target['kmTarget'];

      final dogResponse = await Supabase.instance.client.from('dogs').insert({
        'owner_id': userId,
        'dog_name': _dogNameController.text.trim(),
        'breed': _selectedBreed,
        'weight': weight,
        'birthday': _birthday!.toIso8601String().split('T')[0],
        'sex': _selectedSex,
        'photo_url': photoUrl,
        'daily_goal_minutes': dailyGoalMins,
        'daily_goal_km': dailyGoalKm,
        'owner_activity_level': _ownerActivityLevel,
      }).select().single();

      await Supabase.instance.client.from('weight_history').insert({
        'dog_id': dogResponse['id'],
        'weight_kg': weight,
        'recorded_date': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(
          builder: (context) => HighPawScreen(
            dogName: _dogNameController.text.trim(),
            dailyGoalMins: dailyGoalMins,
            dailyGoalKm: dailyGoalKm,
          ),
        ),
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
    breeds: dogBreeds,
    onBreed: (breed) => _selectedBreed = breed,
    onPhoto: _pickImage,
    photo: _imageFile == null ? null : FileImage(File(_imageFile!.path)),
    ownerActivityLevel: _ownerActivityLevel,
    onOwnerActivityChanged: (level) => setState(() => _ownerActivityLevel = level),
    onNext: _saveToDatabase,
    loading: _isLoading,
  );
}