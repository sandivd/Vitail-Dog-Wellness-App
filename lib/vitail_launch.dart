import 'dart:async';
import 'package:flutter/material.dart';

/// Plays once per app launch while the destination prepares underneath it.
class VitailLaunch extends StatefulWidget {
  const VitailLaunch({super.key, required this.child});
  final Widget child;

  @override
  State<VitailLaunch> createState() => _VitailLaunchState();
}

class _VitailLaunchState extends State<VitailLaunch> {
  Timer? _animationTimer;
  Timer? _holdTimer;
  Timer? _watchdog;
  bool _started = false;
  bool _revealed = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // A missing/undecodable asset must never block entry to the app.
    _watchdog = Timer(const Duration(seconds: 6), _reveal);
  }

  void _start() {
    if (_started || !mounted) return;
    _started = true;
    _animationTimer = Timer(const Duration(milliseconds: 3360), _reveal);
  }

  void _reveal() {
    if (!mounted || _revealed) return;
    _watchdog?.cancel();
    _animationTimer?.cancel();
    setState(() => _revealed = true);
    _holdTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _finished = true);
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _holdTimer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion && !_revealed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: !_finished, child: widget.child),
        if (!_finished)
          Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: Center(
              child: Semantics(
                label: 'Vitail',
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 158,
                        child: Image.asset(
                          _revealed || reducedMotion
                              ? 'assets/brand/vitail-mark.png'
                              : 'assets/brand/vitail-launch.webp',
                          fit: BoxFit.contain,
                          frameBuilder: (context, child, frame, synchronous) {
                            if (frame != null && !_started && !reducedMotion) {
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => _start(),
                              );
                            }
                            return child;
                          },
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.pets, size: 96),
                        ),
                      ),
                      const SizedBox(height: 24),
                      AnimatedOpacity(
                        opacity: _revealed ? 1 : 0,
                        duration: reducedMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 350),
                        child: Image.asset(
                          'assets/brand/vitail-title.png',
                          width: 260,
                          height: 92,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
