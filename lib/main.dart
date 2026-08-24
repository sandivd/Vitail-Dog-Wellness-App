import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'walk_screen.dart';
import 'rewards_screen.dart';
import 'profile_screen.dart';
import 'venues_screen.dart';
import 'walk_history_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          themeMode: currentMode, // This switches the theme!
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Login', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 8),
              const Text('Please sign in to continue.', style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                obscureText: true,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('LOGIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ", style: TextStyle(color: Colors.grey)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                    child: const Text('Sign up', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create Account', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 8),
              const Text('Start your journey with us today.', style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 32),
              // Removed Full Name Field
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                obscureText: true,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('SIGN UP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? ", style: TextStyle(color: Colors.grey)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('Sign in', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
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
  String _selectedSex = 'Male';
  XFile? _imageFile;
  bool _isLoading = false;

  // The massive list of breeds
  static const List<String> dogBreeds = [
    'Affenpinscher', 'Afghan Hound', 'Airedale Terrier', 'Akbash', 'Akita', 'Alaskan Malamute', 'American Bulldog', 'American Bully', 'American Cocker Spaniel', 'American Eskimo Dog', 'American Foxhound', 'American Hairless Terrier', 'American Pit Bull Terrier', 'American Staffordshire Terrier', 'American Water Spaniel', 'Anatolian Shepherd Dog', 'Appenzeller Sennenhund', 'Australian Cattle Dog', 'Australian Kelpie', 'Australian Shepherd', 'Australian Terrier', 'Azawakh', 'Barbet', 'Basenji', 'Basset Fauve de Bretagne', 'Basset Hound', 'Beagle', 'Bearded Collie', 'Beauceron', 'Bedlington Terrier', 'Belgian Malinois', 'Belgian Sheepdog', 'Belgian Tervuren', 'Bergamasco Sheepdog', 'Berger Picard', 'Bernese Mountain Dog', 'Bichon Frise', 'Biewer Terrier', 'Black and Tan Coonhound', 'Black Russian Terrier', 'Bloodhound', 'Bluetick Coonhound', 'Boerboel', 'Bolognese', 'Border Collie', 'Border Terrier', 'Borzoi', 'Boston Terrier', 'Bouvier des Flandres', 'Boxer', 'Boykin Spaniel', 'Bracco Italiano', 'Braque du Bourbonnais', 'Briard', 'Brittany', 'Brussels Griffon', 'Bull Terrier', 'Bulldog', 'Bullmastiff', 'Cairn Terrier', 'Canaan Dog', 'Cane Corso', 'Cardigan Welsh Corgi', 'Catahoula Leopard Dog', 'Caucasian Shepherd Dog', 'Cavalier King Charles Spaniel', 'Central Asian Shepherd Dog', 'Cesky Terrier', 'Chesapeake Bay Retriever', 'Chihuahua', 'Chinese Crested', 'Chinese Shar-Pei', 'Chinook', 'Chow Chow', 'Clumber Spaniel', 'Cocker Spaniel', 'Collie', 'Coton de Tulear', 'Curly-Coated Retriever', 'Dachshund', 'Dalmatian', 'Dandie Dinmont Terrier', 'Doberman Pinscher', 'Dogo Argentino', 'Dogue de Bordeaux', 'Dutch Shepherd', 'English Cocker Spaniel', 'English Foxhound', 'English Mastiff', 'English Setter', 'English Springer Spaniel', 'English Toy Spaniel', 'Entlebucher Mountain Dog', 'Estrela Mountain Dog', 'Eurasier', 'Field Spaniel', 'Fila Brasileiro', 'Finnish Lapphund', 'Finnish Spitz', 'Flat-Coated Retriever', 'French Bulldog', 'German Pinscher', 'German Shepherd Dog', 'German Shorthaired Pointer', 'German Spitz', 'German Wirehaired Pointer', 'Giant Schnauzer', 'Glen of Imaal Terrier', 'Golden Retriever', 'Gordon Setter', 'Grand Basset Griffon Vendéen', 'Great Dane', 'Great Pyrenees', 'Greater Swiss Mountain Dog', 'Greyhound', 'Griffon Bruxellois', 'Hamiltonstovare', 'Harrier', 'Havanese', 'Hokkaido', 'Hovawart', 'Ibizan Hound', 'Icelandic Sheepdog', 'Irish Red and White Setter', 'Irish Setter', 'Irish Terrier', 'Irish Water Spaniel', 'Irish Wolfhound', 'Italian Greyhound', 'Jack Russell Terrier', 'Japanese Chin', 'Japanese Spitz', 'Japanese Terrier', 'Jindo', 'Kai Ken', 'Kangal Shepherd Dog', 'Keeshond', 'Kerry Blue Terrier', 'King Charles Spaniel', 'Komondor', 'Kooikerhondje', 'Kuvasz', 'Labrador Retriever', 'Lagotto Romagnolo', 'Lakeland Terrier', 'Lancashire Heeler', 'Leonberger', 'Lhasa Apso', 'Löwchen', 'Maltese', 'Manchester Terrier', 'Mastiff', 'Miniature American Shepherd', 'Miniature Bull Terrier', 'Miniature Pinscher', 'Miniature Schnauzer', 'Mudi', 'Neapolitan Mastiff', 'Nederlandse Kooikerhondje', 'Newfoundland', 'Norfolk Terrier', 'Norwegian Buhund', 'Norwegian Elkhound', 'Norwegian Lundehund', 'Norwich Terrier', 'Nova Scotia Duck Tolling Retriever', 'Old English Sheepdog', 'Otterhound', 'Papillon', 'Parson Russell Terrier', 'Patterdale Terrier', 'Pekingese', 'Pembroke Welsh Corgi', 'Peruvian Hairless Dog', 'Pharaoh Hound', 'Plott Hound', 'Pointer', 'Polish Lowland Sheepdog', 'Pomeranian', 'Poodle (Standard, Miniature, Toy)', 'Portuguese Podengo', 'Portuguese Water Dog', 'Presa Canario', 'Pug', 'Puli', 'Pumi', 'Pyrenean Mastiff', 'Pyrenean Shepherd', 'Rat Terrier', 'Redbone Coonhound', 'Rhodesian Ridgeback', 'Rottweiler', 'Russell Terrier', 'Russian Toy', 'Russian Tsvetnaya Bolonka', 'Saint Bernard', 'Saluki', 'Samoyed', 'Schapendoes', 'Schipperke', 'Scottish Deerhound', 'Scottish Terrier', 'Sealyham Terrier', 'Shetland Sheepdog', 'Shiba Inu', 'Shih Tzu', 'Shikoku', 'Siberian Husky', 'Silky Terrier', 'Skye Terrier', 'Sloughi', 'Small Munsterlander', 'Soft Coated Wheaten Terrier', 'Spanish Mastiff', 'Spanish Water Dog', 'Spinone Italiano', 'Staffordshire Bull Terrier', 'Standard Schnauzer', 'Sussex Spaniel', 'Swedish Vallhund', 'Taiwan Dog', 'Thai Ridgeback', 'Tibetan Mastiff', 'Tibetan Spaniel', 'Tibetan Terrier', 'Toy Fox Terrier', 'Treeing Walker Coonhound', 'Vizsla', 'Volpino Italiano', 'Weimaraner', 'Welsh Springer Spaniel', 'Welsh Terrier', 'West Highland White Terrier', 'Whippet', 'Wire Fox Terrier', 'Wirehaired Pointing Griffon', 'Wirehaired Vizsla', 'Xoloitzcuintli', 'Yakutian Laika', 'Yorkshire Terrier'
  ];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,       // Downscale to max 600px width
      imageQuality: 70,    // Compress to 70% quality (optimizes JPEG)
    );
    if (image != null) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  Future<void> _pickBirthday() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthday = picked;
      });
    }
  }

  // Calculate age in years as a double (e.g., 2.5 years)
  double _calculateAge(DateTime bday) {
    final today = DateTime.now();
    int years = today.year - bday.year;
    int months = today.month - bday.month;
    if (months < 0) {
      years--;
      months += 12;
    }
    return years + (months / 12);
  }

  Future<void> _saveToDatabase() async {
    if (_dogNameController.text.isEmpty || _selectedBreed == null || _birthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      double weight = double.tryParse(_weightController.text.trim()) ?? 0.0;
      String? photoUrl;

      // 1. Upload photo to Supabase Storage if user picked one
      if (_imageFile != null) {
        final fileName = '${userId}_dog_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage.from('dog_photos').upload(fileName, File(_imageFile!.path));
        photoUrl = Supabase.instance.client.storage.from('dog_photos').getPublicUrl(fileName);
      }

      // 2. Insert Dog details
      final dogResponse = await Supabase.instance.client.from('dogs').insert({
        'owner_id': userId,
        'dog_name': _dogNameController.text.trim(),
        'breed': _selectedBreed,
        'weight': weight,
        'birthday': _birthday!.toIso8601String().split('T')[0], // YYYY-MM-DD
        'sex': _selectedSex,
        'photo_url': photoUrl,
      }).select().single();

      // 3. Save initial weight to history
      await Supabase.instance.client.from('weight_history').insert({
        'dog_id': dogResponse['id'],
        'weight_kg': weight,
        'recorded_date': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Database Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Dog')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo Picker
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _imageFile != null ? FileImage(File(_imageFile!.path)) : null,
                  child: _imageFile == null
                      ? Icon(Icons.camera_alt, size: 40, color: Colors.grey[600])
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Dog Name
            TextField(
              controller: _dogNameController,
              decoration: const InputDecoration(labelText: 'Your dog\'s name*', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // Breed Dropdown (Autocomplete)
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return dogBreeds.where((String breed) {
                  return breed.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                setState(() {
                  _selectedBreed = selection;
                });
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'Your dog\'s breed*', border: OutlineInputBorder()),
                );
              },
            ),
            const SizedBox(height: 16),

            // Birthday Picker
            InkWell(
              onTap: _pickBirthday,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Your dog\'s birthday*', border: OutlineInputBorder()),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_birthday == null 
                      ? 'Select Date' 
                      : DateFormat('MMM d, yyyy').format(_birthday!)),
                    const Icon(Icons.calendar_today, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Weight
            TextField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: 'Current Weight (kg)*', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // Sex Selector
            const Text('Is your dog male or female?*', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Male')),
                    selected: _selectedSex == 'Male',
                    onSelected: (selected) => setState(() => _selectedSex = 'Male'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Female')),
                    selected: _selectedSex == 'Female',
                    onSelected: (selected) => setState(() => _selectedSex = 'Female'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Finish Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveToDatabase,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: _isLoading ? const CircularProgressIndicator() : const Text('Finish', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
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
  bool _walkTaskDone = false;
  bool _weightTaskDone = false;

  @override
  void initState() {
    super.initState();
    _fetchPoints();
  }

  Future<void> _fetchPoints() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('profiles')
          .select('total_points, daily_streak') 
          .eq('id', userId)
          .single();
      
      setState(() {
        _totalPoints = response['total_points'] ?? 0;
        _dailyStreak = response['daily_streak'] ?? 0; // Now it will grab the real number!
        _isLoading = false;
      });
      _fetchTasks();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTasks() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final response = await Supabase.instance.client
          .from('daily_tasks')
          .select()
          .eq('user_id', userId)
          .eq('task_date', today)
          .maybeSingle();

      setState(() {
        _walkTaskDone = response?['walk_done'] ?? false;
        _weightTaskDone = response?['weight_done'] ?? false;
      });
    } catch (e) {
      // Silently fail
    }
  }

  @override
  Widget build(BuildContext context) {
    // List of screens for the bottom nav
    final screens = [
      // Index 0: Home
      Center(
        child: SingleChildScrollView( // Wrap in SingleChildScrollView to prevent overflow
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pets, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              const Text('Welcome to Vitail!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _isLoading 
                ? const CircularProgressIndicator()
                : Text('Points: $_totalPoints', style: const TextStyle(fontSize: 28, color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('🔥 $_dailyStreak Day Streak!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 24),
              
              // Daily Quests Card
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Daily Quests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildQuestTile('Walk 1km today', _walkTaskDone, Icons.directions_walk),
                      _buildQuestTile('Log dog\'s weight', _weightTaskDone, Icons.scale),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentIndex = 1; // Switch to Walk tab
                  });
                },
                icon: const Icon(Icons.directions_walk),
                label: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Start Walk', style: TextStyle(fontSize: 18)),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const WalkHistoryScreen()));
                },
                child: const Text('View Walk History'),
              ),
            ],
          ),
        ),
      ),
      // Index 1: Walk
      const WalkScreen(),
      // Index 2: Rewards
      const RewardsScreen(),
      // Index 3: Venues
      const VenuesScreen(),
      // Index 4: Profile
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vitail'),
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 0) {
              _fetchPoints(); // Refresh points when returning to Home
            }
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.directions_walk), label: 'Walk'),
          NavigationDestination(icon: Icon(Icons.card_giftcard), label: 'Rewards'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Venues'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
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