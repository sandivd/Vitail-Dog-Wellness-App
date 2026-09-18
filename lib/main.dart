import 'password_field.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'walk_screen.dart';
import 'onboarding_view.dart';
import 'dog_date_picker.dart';
import 'dog_photo_sheet.dart';
import 'signup_view.dart';
import 'login_view.dart';
import 'rewards_screen.dart';
import 'profile_screen.dart';
import 'walk_history_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'exercise_data.dart';

const String supabaseUrl = 'https://wvaivqtoriceinqzqeaf.supabase.co';
const String supabaseAnonKey = 'sb_publishable_EsVDR5mB7Ud9ErJ_theXKA_qMwNuw4G';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  runApp(const VitailApp());
}

// Global notifier for Dark Mode
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

class VitailApp extends StatelessWidget {
  const VitailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          title: 'Vitail',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
            useMaterial3: true,
            fontFamily: 'PlusJakartaSans', // Add this line!
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
            useMaterial3: true,
            fontFamily: 'PlusJakartaSans', // Add this line!
          ),
          themeMode: currentMode, 
          home: const LoginScreen(),
        );
      },
    );
  }
}

// ---------------- LOGIN SCREEN ----------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;
      
      if (response != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OnboardingScreen()));
      }
    } catch (e) {
      String errorMessage = 'An error occurred. Please try again.';
      if (e.toString().contains('Invalid login credentials')) {
        errorMessage = 'Incorrect email or password.';
      } else if (e.toString().contains('network') || e.toString().contains('Failed host lookup')) {
        errorMessage = 'No internet connection.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

    Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // 1. Trigger the Google Sign In flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        serverClientId: '919287771219-4r09c1mtjrruriu921rvpntqukjv0uji.apps.googleusercontent.com',
      ).signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        setState(() => _isLoading = false);
        return;
      }

      // 2. Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Sign in to Supabase with the Google ID Token
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      // 5. Check if they already have a profile
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;
      
      if (response != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OnboardingScreen()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoginView(
      emailController: _emailController,
      passwordController: _passwordController,
      isLoading: _isLoading,
      onEmailLogin: _login,
      onGoogleLogin: _signInWithGoogle,
      onSignUp: () => Navigator.push(context,
        MaterialPageRoute(builder: (context) => const RegisterScreen())),
    );
  }
}

// ---------------- REGISTER SCREEN ----------------
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signUp() async {
    if (!PasswordField.isValid(_passwordController.text) || !PasswordField.isValid(_confirmPasswordController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be 6–64 characters.')));
      return;
    }
    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Create the auth user
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      // 2. Create a blank profile row (needed for points/streaks to work)
      // We no longer save the owner's full name here.
      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
      });

      if (!mounted) return;
      // Go to Onboarding to collect Dog details
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OnboardingScreen()));
    } catch (e) {
      String errorMessage = 'An error occurred. Please try again.';
      String errorStr = e.toString().toLowerCase();

      if (errorStr.contains('already registered') || errorStr.contains('user already registered')) {
        errorMessage = 'An account with this email already exists.';
      } else if (errorStr.contains('network') || errorStr.contains('failed host lookup')) {
        errorMessage = 'No internet connection.';
      } else if (errorStr.contains('invalid') || errorStr.contains('email_address_invalid') || errorStr.contains('validate email address')) {
        errorMessage = 'Please enter a valid email address.';
      } else if (errorStr.contains('password')) {
        errorMessage = 'Password must be at least 6 characters.';
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

    Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // 1. Trigger the Google Sign In flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        serverClientId: '919287771219-4r09c1mtjrruriu921rvpntqukjv0uji.apps.googleusercontent.com',
      ).signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        setState(() => _isLoading = false);
        return;
      }

      // 2. Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Sign in to Supabase with the Google ID Token
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      // 5. Check if they already have a profile
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;
      
      if (response != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OnboardingScreen()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignupView(
    emailController: _emailController,
    passwordController: _passwordController,
    confirmPasswordController: _confirmPasswordController,
    isLoading: _isLoading,
    onSignUp: _signUp,
    onGoogleLogin: _signInWithGoogle,
    onSignIn: () => Navigator.pop(context),
  );
}

// ---------------- ONBOARDING SCREEN ----------------
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
  String _ownerActivityLevel = 'moderate'; // Default value

  // The massive list of breeds
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
      maxWidth: 600,       // Downscale to max 600px width
      imageQuality: 70,    // Compress to 70% quality (optimizes JPEG)
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
      
      // 1. Calculate Age dynamically from birthday
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

      // 2. Upload photo to Supabase Storage if user picked one
      if (_imageFile != null) {
        final fileName = '${userId}_dog_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage.from('dog_photos').upload(fileName, File(_imageFile!.path));
        photoUrl = Supabase.instance.client.storage.from('dog_photos').getPublicUrl(fileName);
      }

      // 3. Calculate Exercise Goal using new Engine!
      var target = ExerciseCalculator.calculate(
        breed: _selectedBreed!,
        weightKg: weight,
        ageYears: age,
        ownerActivityLevel: _ownerActivityLevel,
      );

      int dailyGoalMins = target['targetMinutes'];
      double dailyGoalKm = target['kmTarget'];

      // 4. Insert Dog details
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

      // 5. Save initial weight to history
      await Supabase.instance.client.from('weight_history').insert({
        'dog_id': dogResponse['id'],
        'weight_kg': weight,
        'recorded_date': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      
      // 6. Go to the High Paw screen! (Pass both mins and km)
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
    // ADD THESE TWO LINES:
    ownerActivityLevel: _ownerActivityLevel,
    onOwnerActivityChanged: (level) => setState(() => _ownerActivityLevel = level),
    onNext: _saveToDatabase,
    loading: _isLoading,
  );
}

// ---------------- HOME SCREEN ----------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _totalPoints = 0;
  int _dailyStreak = 0;
  bool _isLoading = true;
    int _currentIndex = 0;
  
  // New variables for the Figma UI
  String _dogName = 'Dog';
  String? _dogPhotoUrl;
  double _dailyGoalKm = 3.0;
  int _dailyGoalMins = 60;
  double _currentKm = 0.0;
  int _currentMins = 0;

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
  }

  Future<void> _fetchHomeData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      // 1. Fetch points & streak
      final profileRes = await Supabase.instance.client
          .from('profiles')
          .select('total_points, daily_streak') 
          .eq('id', userId)
          .single();
      
      // 2. Fetch dog details (name, photo, goals)
      final dogRes = await Supabase.instance.client
          .from('dogs')
          .select('dog_name, photo_url, daily_goal_km, daily_goal_minutes')
          .eq('owner_id', userId)
          .limit(1)
          .maybeSingle();

      // 3. Fetch today's walks to calculate current progress
      final today = DateTime.now().toIso8601String().split('T')[0];
      final walksRes = await Supabase.instance.client
          .from('walks')
          .select('distance_meters, duration_seconds')
          .eq('user_id', userId)
          .gte('walk_date', today);

      double kmToday = 0;
      int minsToday = 0;
      for (var walk in walksRes) {
        kmToday += (walk['distance_meters'] as num).toDouble() / 1000;
        minsToday += (walk['duration_seconds'] as num).toInt() ~/ 60;
      }

      setState(() {
        _totalPoints = profileRes['total_points'] ?? 0;
        _dailyStreak = profileRes['daily_streak'] ?? 0;
        _dogName = dogRes?['dog_name'] ?? 'Dog';
        _dogPhotoUrl = dogRes?['photo_url'];
        _dailyGoalKm = (dogRes?['daily_goal_km'] ?? 3.0).toDouble();
        _dailyGoalMins = (dogRes?['daily_goal_minutes'] ?? 60).toInt();
        _currentKm = kmToday;
        _currentMins = minsToday;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Custom SVG Icon paths extracted from Figma 
  static const String homeIconPath = 'M38.8218 39V30.44L45.0018 24.64L51.1818 30.44V39H38.8218ZM40.7218 37.1H49.2818V31.12L45.0018 27.1L40.7218 31.12V37.1Z';
  static const String exploreIconPath = 'M135.001 40.78C130.941 40.78 127.661 37.5 127.661 33.44C127.661 29.38 130.941 26.1 135.001 26.1C139.061 26.1 142.341 29.38 142.341 33.44C142.341 37.5 139.021 40.78 135.001 40.78ZM134.381 27.58C131.621 27.86 129.441 30.04 129.141 32.8H134.381V27.58ZM135.661 27.58V32.78H140.861C140.561 30.04 138.401 27.88 135.661 27.58ZM135.641 34.06V39.3C138.401 39 140.581 36.82 140.861 34.06H135.641ZM129.141 34.08C129.441 36.82 131.621 39.02 134.361 39.3V34.08H129.141Z';
  static const String rewardsIconPath = 'M225.009 39.24L217.309 31.54L224.989 23.86L232.689 31.54L225.009 39.24Z';
  static const String profileIconPath = 'M315.001 39.24C313.948 39.24 312.955 39.04 312.021 38.64C311.088 38.24 310.268 37.6933 309.561 37C308.868 36.2933 308.321 35.4733 307.921 34.54C307.521 33.6067 307.321 32.6133 307.321 31.56C307.321 30.4933 307.521 29.5 307.921 28.58C308.321 27.6467 308.868 26.8267 309.561 26.12C310.268 25.4133 311.088 24.86 312.021 24.46C312.955 24.06 313.948 23.86 315.001 23.86C316.068 23.86 317.061 24.06 317.981 24.46C318.915 24.86 319.728 25.4133 320.421 26.12C321.128 26.8267 321.681 27.6467 322.081 28.58C322.481 29.5 322.681 30.4933 322.681 31.56C322.681 32.6133 322.481 33.6067 322.081 34.54C321.681 35.4733 321.128 36.2933 320.421 37C319.728 37.6933 318.915 38.24 317.981 38.64C317.061 39.04 316.068 39.24 315.001 39.24Z';
  
  @override
  Widget build(BuildContext context) {
    // List of screens for the bottom nav
    final screens = [
      // Index 0: Home
      Container(
        color: const Color(0xFFF4F0E9), // Figma background color
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header (Avatar + Hi Dog Name)
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _dogPhotoUrl != null ? NetworkImage(_dogPhotoUrl!) : null,
                    child: _dogPhotoUrl == null ? const Icon(Icons.pets, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Hi $_dogName!',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF241C24)),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Progress Rings
              Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Ring (KM Progress) - Blue #5F98BD
                      SizedBox(
                        width: 186,
                        height: 186,
                        child: CircularProgressIndicator(
                          value: (_currentKm / _dailyGoalKm).clamp(0.0, 1.0),
                          strokeWidth: 14,
                          color: const Color(0xFF5F98BD),
                          backgroundColor: const Color(0xFF5F98BD).withOpacity(0.2),
                        ),
                      ),
                      // Inner Ring (Minutes Progress) - Green #AEC568
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CircularProgressIndicator(
                          value: (_currentMins / _dailyGoalMins).clamp(0.0, 1.0),
                          strokeWidth: 10,
                          color: const Color(0xFFAEC568),
                          backgroundColor: const Color(0xFFAEC568).withOpacity(0.2),
                        ),
                      ),
                      // Center Text
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // KM Section
                          Text(
                            '${_currentKm.toStringAsFixed(1)}/${_dailyGoalKm.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.w800, // Changed to w800
                              color: Color(0xFF5F98BD), 
                              fontFamily: 'PlusJakartaSans',
                              height: 1.0, 
                            ),
                          ),
                          const Text(
                            'KM',
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.w800, // Changed to w800
                              color: Color(0xFF6B5F66), 
                              fontFamily: 'PlusJakartaSans',
                              height: 1.0, 
                            ),
                          ),
                          const SizedBox(height: 4), 
                          
                          // Mins Section
                          Text(
                            '$_currentMins/$_dailyGoalMins',
                            style: const TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.w800, // Changed to w800
                              color: Color(0xFFAEC568), 
                              fontFamily: 'PlusJakartaSans',
                              height: 1.0, 
                            ),
                          ),
                          const Text(
                            'MINS',
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.w800, // Changed to w800
                              color: Color(0xFF6B5F66), 
                              fontFamily: 'PlusJakartaSans',
                              height: 1.0, 
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Stats Cards (Points & Streak)
              Row(
                children: [
                  Expanded(
                    child: _buildFigmaStatCard('Points earned', '$_totalPoints pts', Icons.star),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFigmaStatCard('Streaks', '$_dailyStreak days', Icons.local_fire_department),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Start Walk Button (Coral #DC755C)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 1; // Switch to Walk tab
                    });
                  },
                  icon: const Icon(Icons.play_arrow, size: 24),
                  label: const Text('Start walk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC755C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // View Walk History Text Button (Kept for functionality)
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const WalkHistoryScreen()));
                  },
                  child: const Text('View Walk History', style: TextStyle(color: Color(0xFF6B5F66))),
                ),
              ),
            ],
          ),
        ),
      ),
      // Index 1: Walk
      const WalkScreen(),
      // Index 2: Rewards
      const RewardsScreen(),
      // Index 3: Profile
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: const Color(0xFFDAD6CD), width: 1)),
        ),
        padding: EdgeInsets.only(
          top: 8.0,
          bottom: MediaQuery.of(context).padding.bottom > 0 ? 16.0 : 8.0, 
        ),
        child: Row(
          children: [
            _buildCustomNavItem(0, 'Home', homeIconPath, '38 24 13 16'),
            _buildCustomNavItem(1, 'Explore', exploreIconPath, '127 26 16 15'),
            _buildCustomNavItem(2, 'Rewards', rewardsIconPath, '217 23 16 17'),
            _buildCustomNavItem(3, 'Profile', profileIconPath, '307 23 16 16'),
          ],
        ),
      ),
    );
  }

  Widget _buildFigmaStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF6B5F66)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF241C24))),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF6B5F66))),
        ],
      ),
    );
  }

  Widget _buildCustomNavItem(int index, String label, String iconPath, String viewBox) {
    bool isActive = _currentIndex == index;
    String hexColor = isActive ? '#0F4C81' : '#6E6A63'; // Your exact Figma colors
    
    // Construct the full SVG string dynamically
    String svgString = '''<svg viewBox="$viewBox" xmlns="http://www.w3.org/2000/svg"><path d="$iconPath" fill="$hexColor"/></svg>''';

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
            if (index == 0) _fetchHomeData();
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.string(svgString, height: 24, width: 24),
            const SizedBox(height: 4),
            Text(
              label, 
              style: TextStyle(
                color: Color(int.parse(hexColor.replaceFirst('#', 'FF'), radix: 16)), 
                fontSize: 12
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestTile(String title, bool isDone, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: isDone ? Colors.green : Colors.grey),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(fontSize: 16, color: isDone ? Colors.grey : Colors.black, decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none)),
          const Spacer(),
          Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? Colors.green : Colors.grey),
        ],
      ),
    );
  }
}

// ---------------- HIGH PAW SCREEN ----------------
class HighPawScreen extends StatelessWidget {
  final String dogName;
  final int dailyGoalMins;
  final double dailyGoalKm;

  const HighPawScreen({
    super.key,
    required this.dogName,
    required this.dailyGoalMins,
    required this.dailyGoalKm,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pets, size: 80, color: Colors.green),
                ),
                const SizedBox(height: 32),
                
                const Text(
                  'High paw!',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on $dogName\'s breed, weight, and your activity level, we recommend:',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                
                // Minutes
                Text(
                  '$dailyGoalMins minutes',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const Text('a day', style: TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 16),
                
                // Distance
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Target Distance: ${dailyGoalKm.toStringAsFixed(1)} km',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[800]),
                  ),
                ),
                const SizedBox(height: 48),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context, 
                        MaterialPageRoute(builder: (context) => const HomeScreen())
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}