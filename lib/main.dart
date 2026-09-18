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
import 'package:cached_network_image/cached_network_image.dart';

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
            fontFamily: 'PlusJakartaSans',
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
            useMaterial3: true,
            fontFamily: 'PlusJakartaSans',
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
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        serverClientId: '919287771219-4r09c1mtjrruriu921rvpntqukjv0uji.apps.googleusercontent.com',
      ).signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
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
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
      });

      if (!mounted) return;
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
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        serverClientId: '919287771219-4r09c1mtjrruriu921rvpntqukjv0uji.apps.googleusercontent.com',
      ).signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
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

// ---------------- HOME SCREEN ----------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _totalPoints = 0;
  int _dailyStreak = 0;
  bool _isLoading = true;
  
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
      
      final profileRes = await Supabase.instance.client
          .from('profiles')
          .select('total_points, daily_streak') 
          .eq('id', userId)
          .single();
      
      final dogRes = await Supabase.instance.client
          .from('dogs')
          .select('dog_name, photo_url, daily_goal_km, daily_goal_minutes')
          .eq('owner_id', userId)
          .limit(1)
          .maybeSingle();

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

  // Custom Line Icons from Figma
  static const String homeIconSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M15 21V13C15 12.7348 14.8946 12.4804 14.7071 12.2929C14.5196 12.1054 14.2652 12 14 12H10C9.73478 12 9.48043 12.1054 9.29289 12.2929C9.10536 12.4804 9 12.7348 9 13V21" stroke="[[COLOR]]" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M3 9.99999C2.99993 9.70906 3.06333 9.42161 3.18579 9.15771C3.30824 8.8938 3.4868 8.65979 3.709 8.47199L10.709 2.47199C11.07 2.1669 11.5274 1.99951 12 1.99951C12.4726 1.99951 12.93 2.1669 13.291 2.47199L20.291 8.47199C20.5132 8.65979 20.6918 8.8938 20.8142 9.15771C20.9367 9.42161 21.0001 9.70906 21 9.99999V19C21 19.5304 20.7893 20.0391 20.4142 20.4142C20.0391 20.7893 19.5304 21 19 21H5C4.46957 21 3.96086 20.7893 3.58579 20.4142C3.21071 20.0391 3 19.5304 3 19V9.99999Z" stroke="[[COLOR]]" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

  static const String exploreIconSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M15 20.7648C14.6897 20.7648 14.3836 20.6926 14.106 20.5538L9.894 18.4478C9.6164 18.3091 9.31033 18.2369 9 18.2369C8.68967 18.2369 8.3836 18.3091 8.106 18.4478L4.447 20.2778C4.29436 20.3541 4.12473 20.3901 3.95426 20.3823C3.78379 20.3745 3.61816 20.3232 3.47312 20.2332C3.32808 20.1433 3.20846 20.0178 3.12565 19.8686C3.04284 19.7194 2.99958 19.5515 3 19.3808V6.61784C3.0001 6.43218 3.05189 6.25021 3.14956 6.09231C3.24722 5.93442 3.38692 5.80683 3.553 5.72384L8.106 3.44684C8.3836 3.30812 8.68967 3.23591 9 3.23591C9.31033 3.23591 9.6164 3.30812 9.894 3.44684L14.106 5.55284C14.3836 5.69156 14.6897 5.76377 15 5.76377M15 5.76377C15.3103 5.76377 15.6164 5.69156 15.894 5.55284L19.553 3.72284C19.7056 3.6466 19.8751 3.61065 20.0455 3.61841C20.2159 3.62617 20.3814 3.67738 20.5265 3.76717C20.6715 3.85696 20.7911 3.98235 20.874 4.13142C20.9569 4.28049 21.0003 4.44828 21 4.61884V17.3828C20.9999 17.5685 20.9481 17.7505 20.8505 17.9084C20.7528 18.0663 20.6131 18.1938 20.447 18.2768L15.894 20.5538C15.6164 20.6926 15.3103 20.7648 15 20.7648M15 5.76377V20.7648M9 3.23591V18.2358" stroke="[[COLOR]]" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

  static const String rewardsIconSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M12 6.99995V20.9999M12 6.99995C11.6383 5.50935 11.0154 4.23501 10.2127 3.34311C9.41003 2.45121 8.46469 1.98314 7.5 1.99995C6.83696 1.99995 6.20107 2.26334 5.73223 2.73218C5.26339 3.20102 5 3.83691 5 4.49995C5 5.16299 5.26339 5.79887 5.73223 6.26772C6.20107 6.73656 6.83696 6.99995 7.5 6.99995M12 6.99995C12.3617 5.50935 12.9846 4.23501 13.7873 3.34311C14.59 2.45121 15.5353 1.98314 16.5 1.99995C17.163 1.99995 17.7989 2.26334 18.2678 2.73218C18.7366 3.20102 19 3.83691 19 4.49995C19 5.16299 18.7366 5.79887 18.2678 6.26772C17.7989 6.73656 17.163 6.99995 16.5 6.99995M20 10.9999V18.9999C20 19.5304 19.7893 20.0391 19.4142 20.4142C19.0391 20.7892 18.5304 20.9999 18 20.9999H6C5.46957 20.9999 4.96086 20.7892 4.58579 20.4142C4.21071 20.0391 4 19.5304 4 18.9999V10.9999" stroke="[[COLOR]]" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M20 7H4C3.44772 7 3 7.44772 3 8V10C3 10.5523 3.44772 11 4 11H20C20.5523 11 21 10.5523 21 10V8C21 7.44772 20.5523 7 20 7Z" stroke="[[COLOR]]" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

  static const String profileIconSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M12 13C14.7614 13 17 10.7614 17 8C17 5.23858 14.7614 3 12 3C9.23858 3 7 5.23858 7 8C7 10.7614 9.23858 13 12 13Z" stroke="[[COLOR]]" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M20 21C20 18.8783 19.1571 16.8434 17.6569 15.3431C16.1566 13.8429 14.1217 13 12 13C9.87827 13 7.84344 13.8429 6.34315 15.3431C4.84285 16.8434 4 18.8783 4 21" stroke="[[COLOR]]" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F0E9),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFDC755C)),
        ),
      );
    }

    final screens = [
      // Index 0: Home
      Container(
        color: const Color(0xFFF4F0E9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _dogPhotoUrl != null 
                        ? CachedNetworkImageProvider(_dogPhotoUrl!) 
                        : null,
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
              
              Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
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
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_currentKm.toStringAsFixed(1)}/${_dailyGoalKm.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.w800, 
                              color: Color(0xFF5F98BD), 
                              fontFamily: 'PlusJakartaSans',
                              height: 1.0, 
                            ),
                          ),
                          const Text(
                            'KM',
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.w800, 
                              color: Color(0xFF6B5F66), 
                              fontFamily: 'PlusJakartaSans',
                              height: 1.0, 
                            ),
                          ),
                          const SizedBox(height: 4), 
                          
                          Text(
                            '$_currentMins/$_dailyGoalMins',
                            style: const TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.w800, 
                              color: Color(0xFFAEC568), 
                              fontFamily: 'PlusJakartaSans',
                              height: 1.0, 
                            ),
                          ),
                          const Text(
                            'MINS',
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.w800, 
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
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 1;
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
      const WalkScreen(),
      const RewardsScreen(),
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
            _buildCustomNavItem(0, 'Home', homeIconSvg),
            _buildCustomNavItem(1, 'Explore', exploreIconSvg),
            _buildCustomNavItem(2, 'Rewards', rewardsIconSvg),
            _buildCustomNavItem(3, 'Profile', profileIconSvg),
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

  Widget _buildCustomNavItem(int index, String label, String svgString) {
    bool isActive = _currentIndex == index;
    String hexColor = isActive ? '#4E6B45' : '#6E6A63'; 
    
    String coloredSvg = svgString.replaceAll('[[COLOR]]', hexColor);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _currentIndex = index;
            if (index == 0) _fetchHomeData();
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.string(coloredSvg, height: 24, width: 24),
            const SizedBox(height: 4),
            Text(
              label, 
              style: TextStyle(
                color: Color(int.parse(hexColor.replaceFirst('#', 'FF'), radix: 16)), 
                fontSize: 12,
                fontFamily: 'PlusJakartaSans',
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              )
            ),
          ],
        ),
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
                
                Text(
                  '$dailyGoalMins minutes',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const Text('a day', style: TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 16),
                
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