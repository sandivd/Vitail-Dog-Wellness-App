import 'package:flutter/material.dart';
import 'home_screen.dart';

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