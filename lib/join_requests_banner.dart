import 'dart:async';

import 'package:flutter/material.dart';

import 'dog_sharing.dart';
import 'vitail_snack.dart';

class JoinRequestsBanner extends StatefulWidget {
  const JoinRequestsBanner({super.key});

  @override
  State<JoinRequestsBanner> createState() => _JoinRequestsBannerState();
}

class _JoinRequestsBannerState extends State<JoinRequestsBanner> {
  List<JoinRequest> _requests = const <JoinRequest>[];
  final Set<String> _busy = <String>{};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<JoinRequest> requests = await pendingRequestsForMyDogs();
      if (mounted) setState(() => _requests = requests);
    } catch (e) {
      debugPrint('Could not load join requests: ${e.runtimeType}');
    }
  }

  Future<void> _decide(JoinRequest request, bool approve) async {
    setState(() => _busy.add(request.id));
    try {
      await decideJoinRequest(request.id, approve: approve);
      if (!mounted) return;
      setState(() =>
          _requests = _requests.where((r) => r.id != request.id).toList());
      final String who = request.requesterName ?? 'They';
      showVitailSnack(
        context,
        approve ? '$who can now help walk ${request.dogName}.' : 'Request declined.',
        type: approve ? VitailSnackType.success : VitailSnackType.info,
      );
    } catch (e) {
      debugPrint('Could not update join request: ${e.runtimeType}');
      if (mounted) {
        showVitailSnack(
          context,
          "Couldn't update the request. Please try again.",
          type: VitailSnackType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_requests.isEmpty) return const SizedBox.shrink();
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [for (final JoinRequest r in _requests) _card(r, colors)],
      ),
    );
  }

  Widget _card(JoinRequest request, ColorScheme colors) {
    final bool busy = _busy.contains(request.id);
    final String who = request.requesterName ?? 'Someone';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$who wants to help walk ${request.dogName}',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'They used your share code. Only approve people you know.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => _decide(request, false),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : () => _decide(request, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    elevation: 0,
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}