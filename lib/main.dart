import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'walk_screen.dart';
import 'rewards_screen.dart';
import 'profile_screen.dart';
import 'venues_screen.dart';

const String supabaseUrl = 'https://wvaivqtoriceinqzqeaf.supabase.co';
const String supabaseAnonKey = 'sb_publishable_EsVDR5mB7Ud9ErJ_theXKA_qMwNuw4G';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  runApp(const VitailApp());
}

class VitailApp extends StatelessWidget {
  const VitailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vitail',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
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

    Future<void> _authenticate(bool isLogin) async {
    setState(() => _isLoading = true);
    try {
      if (isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      // Check if user already has a profile
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;
      
      // If profile exists, go to Home. If not, go to Onboarding.
      if (response != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Vitail', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : () => _authenticate(true),
              child: const Text('Log In'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isLoading ? null : () => _authenticate(false),
              child: const Text('Sign Up'),
            ),
          ],
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
  final _ownerNameController = TextEditingController();
  final _dogNameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveToDatabase() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
        'full_name': _ownerNameController.text.trim(),
      });

      // Convert text to numbers, defaulting to 0.0 if empty
      double age = double.tryParse(_ageController.text.trim()) ?? 0.0;
      double weight = double.tryParse(_weightController.text.trim()) ?? 0.0;

      await Supabase.instance.client.from('dogs').insert({
        'owner_id': userId,
        'dog_name': _dogNameController.text.trim(),
        'breed': _breedController.text.trim(),
        'age': age,
        'weight': weight,
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your profile')),
      body: SingleChildScrollView( // Wrapped in SingleChildScrollView so keyboard doesn't cover fields
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ownerNameController,
              decoration: const InputDecoration(labelText: 'Your Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dogNameController,
              decoration: const InputDecoration(labelText: 'Dog\'s Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _breedController,
              decoration: const InputDecoration(labelText: 'Dog Breed (e.g., Golden Retriever)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageController,
                    decoration: const InputDecoration(labelText: 'Age (years)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveToDatabase,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Save & Continue'),
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
  bool _isLoading = true;

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
          .select('total_points')
          .eq('id', userId)
          .single();
      
      setState(() {
        _totalPoints = response['total_points'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // List of screens for the bottom nav
    final screens = [
      // Index 0: Home
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 100, color: Colors.green),
            const SizedBox(height: 16),
            const Text('Welcome to Vitail!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _isLoading 
              ? const CircularProgressIndicator()
              : Text('Points: $_totalPoints', style: const TextStyle(fontSize: 28, color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WalkScreen()),
                );
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
          ],
        ),
      ),
      // Index 1: Walk (Placeholder, usually triggered by button, but added for nav)
      const Center(child: Text('Walk Page')),
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
}