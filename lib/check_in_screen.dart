import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckInScreen extends StatefulWidget {
  final int cost;
  final String title;
  final String partnerName;

  const CheckInScreen({
    super.key,
    required this.cost,
    required this.title,
    required this.partnerName,
  });

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  double _swipeValue = 0.0; // 0.0 to 1.0
  bool _isCollected = false;
  bool _isProcessing = false;
  String _dogName = "your dog"; // Default fallback

  @override
  void initState() {
    super.initState();
    _fetchDogName();
  }

  Future<void> _fetchDogName() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('dogs')
          .select('dog_name')
          .eq('owner_id', userId)
          .limit(1)
          .single();
      
      if (mounted) {
        setState(() {
          _dogName = response['dog_name'] ?? "your dog";
        });
      }
    } catch (e) {
      // Silently fail, use default name
    }
  }

  Future<void> _collectReward() async {
    setState(() => _isProcessing = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      // 1. Fetch current points
      final profileRes = await Supabase.instance.client
          .from('profiles')
          .select('total_points')
          .eq('id', userId)
          .single();
      
      int currentPoints = profileRes['total_points'] ?? 0;
      int newPoints = currentPoints - widget.cost;

      // 2. Deduct points
      await Supabase.instance.client.from('profiles').update({
        'total_points': newPoints,
      }).eq('id', userId);

      // 3. Show success screen
      setState(() {
        _isCollected = true;
        _isProcessing = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCollected) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Paw Print Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pets, size: 50, color: Colors.orange),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'Show this at the counter',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 16),
              
              Text(
                'Swipe to collect ${widget.title} for $_dogName at ${widget.partnerName}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),

              // SWIPE MECHANISM
              LayoutBuilder(
                builder: (context, constraints) {
                  double maxDrag = constraints.maxWidth - 70; // 70 is button width
                  return Container(
                    width: double.infinity,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(35),
                    ),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Background Text
                        Center(
                          child: Text(
                            'SWIPE TO COLLECT  →',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        // Draggable Button
                        Positioned(
                          left: _swipeValue * maxDrag,
                          child: GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              setState(() {
                                _swipeValue += details.primaryDelta! / maxDrag;
                                _swipeValue = _swipeValue.clamp(0.0, 1.0);
                              });
                            },
                            onHorizontalDragEnd: (details) {
                              if (_swipeValue > 0.9) {
                                _collectReward(); // Trigger collection!
                              } else {
                                setState(() => _swipeValue = 0.0); // Snap back
                              }
                            },
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: _isProcessing 
                                  ? const CircularProgressIndicator(color: Colors.white) 
                                  : const Icon(Icons.pets, color: Colors.white, size: 30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // SUCCESS SCREEN UI
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Green Checkmark
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 32),
            
            const Text(
              'Collected',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 12),
            
            Text(
              'One ${widget.title} for $_dogName',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            Text(
              '· ${widget.partnerName} ·',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Done', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}