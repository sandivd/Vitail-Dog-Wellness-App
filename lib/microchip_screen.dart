import 'vitail_colors.dart';
import 'microchip_validation.dart';
import 'vitail_icon.dart';
import 'vitail_back_button.dart';
export 'microchip_validation.dart' show microchipNumberError;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';
import 'onboarding_goal_screen.dart';
import 'onboarding_style.dart';
import 'vitail_snack.dart';
import 'all_set_screen.dart';

enum _View { form, verified, failed, submitted }

class MicrochipScreen extends StatefulWidget {
  const MicrochipScreen({
    super.key,
    this.isFromProfile = false,
    this.initialNumber,
    this.dogId,
  });

  final bool isFromProfile;
  final String? initialNumber;
  final String? dogId;

  @override
  State<MicrochipScreen> createState() => _MicrochipScreenState();
}

class _MicrochipScreenState extends State<MicrochipScreen> {
  VitailColors get _colors => VitailColors.of(context);

  OnboardingStyle get _style => OnboardingStyle.of(context);

  late final TextEditingController _numberController;

  _View _view = _View.form;
  bool _uploadTab = false;
  File? _certificateFile;
  String? _certificateFileName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController(text: widget.initialNumber ?? '');
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _finish() {
    if (widget.isFromProfile) {
      Navigator.pop(context, true);
    } else {
      final String? dogId = widget.dogId;
      Navigator.pushReplacement<void, void>(
        context,
        onboardingFadeRoute<void>(
          dogId == null ? const HomeScreen() : AllSetScreen(dogId: dogId),
        ),
      );
    }
  }

  Future<void> _verifyAndSave() async {
    FocusScope.of(context).unfocus();
    final String? error = microchipNumberError(_numberController.text);
    if (error != null) {
      setState(() => _view = _View.failed);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not signed in');

      final chipNumber = _numberController.text.trim();

      var query = client
          .from('dogs')
          .update({'microchip_number': chipNumber})
          .eq('owner_id', userId);
      if (widget.dogId != null && widget.dogId!.isNotEmpty) {
        query = query.eq('id', widget.dogId!);
      }
      final saved = await query.select('id').single();
      if (saved['id'] == null) throw StateError('Dog was not updated');

      if (!mounted) return;
      setState(() => _view = _View.verified);
    } catch (_) {
      if (!mounted) return;
      showVitailSnack(
        context,
        'Could not save microchip number. Please try again.',
        type: VitailSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

    Future<void> _submitCertificate() async {
    if (_certificateFile == null) {
      showVitailSnack(
        context,
        'Please select a certificate file first.',
        type: VitailSnackType.error,
      );
      return;
    }

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    final dogId = widget.dogId;
    if (userId == null || dogId == null || dogId.isEmpty) {
      showVitailSnack(
        context,
        'Something went wrong. Please try again.',
        type: VitailSnackType.error,
      );
      return;
    }

    final ext =
        _certificateFileName != null && _certificateFileName!.contains('.')
        ? _certificateFileName!.split('.').last.toLowerCase()
        : 'jpg';
    const contentTypes = {
      'pdf': 'application/pdf',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'heic': 'image/heic',
    };
    final storagePath =
        '$userId/$dogId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    setState(() => _isSaving = true);
    try {
      await client.storage
          .from('microchip_certificates')
          .upload(
            storagePath,
            _certificateFile!,
            fileOptions: FileOptions(
              contentType: contentTypes[ext] ?? 'application/octet-stream',
            ),
          );
      try {
        await client.from('microchip_submissions').insert({
          'dog_id': dogId,
          'file_path': storagePath,
        });
      } catch (_) {
        await client.storage
            .from('microchip_certificates')
            .remove([storagePath]);
        rethrow;
      }

      if (!mounted) return;
      setState(() => _view = _View.submitted);
    } catch (e) {
      debugPrint('Certificate upload failed: $e');
      if (!mounted) return;
      showVitailSnack(
        context,
        'Could not upload certificate. Please try again.',
        type: VitailSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickCertificate() async {
    FocusScope.of(context).unfocus();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _style.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _style.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: VitailIcon('camera', color: _style.ink),
                title: Text(
                  'Take photo of certificate',
                  style: _style.text(14, weight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: VitailIcon('images', color: _style.ink),
                title: Text(
                  'Choose from photo library',
                  style: _style.text(14, weight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading: VitailIcon('paperclip', color: _style.ink),
                title: Text(
                  'Choose document (PDF, JPG, PNG)',
                  style: _style.text(14, weight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(ctx, 'file'),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == null) return;

    try {
      if (action == 'file') {
        // Direct call to FilePicker.pickFiles (no .platform)
        final dynamic result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        );
        if (result != null) {
          String? pickedPath;
          String? pickedName;

          if (result is List && result.isNotEmpty) {
            final dynamic first = result.first;
            pickedPath = first.path as String?;
            pickedName = first.name as String?;
          } else {
            final dynamic files = result.files;
            if (files is List && files.isNotEmpty) {
              final dynamic first = files.first;
              pickedPath = first.path as String?;
              pickedName = first.name as String?;
            }
          }

          if (pickedPath != null) {
            setState(() {
              _certificateFile = File(pickedPath!);
              _certificateFileName = pickedName ?? 'certificate';
            });
          }
        }
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 85,
        );
        if (picked != null) {
          setState(() {
            _certificateFile = File(picked.path);
            _certificateFileName = picked.name;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        showVitailSnack(
          context,
          'Could not access file or camera.',
          type: VitailSnackType.error,
        );
      }
    }
  }

  void _back() {
    switch (_view) {
      case _View.form:
        Navigator.maybePop(context);
      case _View.failed:
        setState(() => _view = _View.form);
      case _View.verified:
      case _View.submitted:
        _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _style.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: VitailBackButton(onPressed: _back, color: _style.ink),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Container(
                      alignment: Alignment.topCenter,
                      padding: EdgeInsets.only(
                        top: constraints.maxHeight * 0.08,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            layoutBuilder: (currentChild, previousChildren) =>
                                Stack(
                                  alignment: Alignment.topCenter,
                                  children: <Widget>[
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                ),
                            child: KeyedSubtree(
                              key: ValueKey<String>('$_view-$_uploadTab'),
                              child: _body(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_view) {
      case _View.form:
        return _uploadTab ? _uploadForm() : _numberForm();
      case _View.verified:
        return _result(
          title: 'Microchip accepted',
          message:
              'Your number meets the format requirements. Rewards are unlocked.',
          onContinue: _finish,
        );
      case _View.failed:
        return _failed();
      case _View.submitted:
        return _result(
          title: 'Certificate submitted',
          message:
              'Your certificate has been saved for review. Uploading it alone does not unlock rewards. You can enter a valid microchip number to unlock rewards.',
          onContinue: _finish,
        );
    }
  }

  Widget _title(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: _style.text(22, weight: FontWeight.w700, height: 1.3),
  );

  Widget _helper(String text) => Text(
    text,
    style: _style.text(
      12,
      color: _style.muted,
      weight: FontWeight.w500,
      height: 1.5,
    ),
  );

  Widget _tabs() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: _colors.tint(const Color(0xFFEAE5DC)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        _tab('Enter number', !_uploadTab, () {
          setState(() => _uploadTab = false);
        }),
        _tab('Upload certificate', _uploadTab, () {
          setState(() => _uploadTab = true);
        }),
      ],
    ),
  );

  Widget _tab(String label, bool active, VoidCallback onTap) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _colors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: _style.text(
            13,
            color: active ? _style.ink : _style.muted,
            weight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );

  Widget _skipLink() {
    if (widget.isFromProfile) {
      return const SizedBox.shrink();
    }
    return Center(
      child: TextButton(
        onPressed: _finish,
        child: Text(
          'Skip for now, use the app as a tracker & journal',
          textAlign: TextAlign.center,
          style: _style.text(12, color: _style.muted, weight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _numberForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: _title(
          widget.initialNumber != null && widget.initialNumber!.isNotEmpty
              ? "Update your dog's microchip"
              : "Add your dog's microchip",
        ),
      ),
      const SizedBox(height: 20),
      _tabs(),
      const SizedBox(height: 14),
      _helper(
        'Optional: Needed only to redeem reward coupons. You can still track walks and keep a journal without it.',
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Text(
            'Microchip number',
            style: _style.text(13, weight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            'optional',
            style: _style.text(
              12,
              color: _style.muted,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      TextField(
        controller: _numberController,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(15),
        ],
        style: _style.text(14, weight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: '15-digit number',
          hintStyle: _style.text(
            14,
            color: _style.muted,
            weight: FontWeight.w400,
          ),
          filled: true,
          fillColor: _colors.card,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          enabledBorder: _fieldBorder(_style.border),
          focusedBorder: _fieldBorder(_style.coral),
          border: _fieldBorder(_style.border),
        ),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _isSaving ? null : _verifyAndSave,
        style: _style.primaryButton,
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                widget.initialNumber != null && widget.initialNumber!.isNotEmpty
                    ? 'Update & Verify'
                    : 'Verify',
                style: _style.text(16, color: Colors.white),
              ),
      ),
      const SizedBox(height: 8),
      _skipLink(),
    ],
  );

  Widget _uploadForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: _title(
          widget.initialNumber != null && widget.initialNumber!.isNotEmpty
              ? "Update your dog's microchip"
              : "Add your dog's microchip",
        ),
      ),
      const SizedBox(height: 20),
      _tabs(),
      const SizedBox(height: 14),
      _helper(
        'Optional: Needed only to redeem reward coupons. You can still track walks and keep a journal without it.',
      ),
      const SizedBox(height: 20),
      _uploadBox(dashed: false),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _isSaving ? null : _submitCertificate,
        style: _style.primaryButton,
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Submit certificate',
                style: _style.text(16, color: Colors.white),
              ),
      ),
      const SizedBox(height: 8),
      _skipLink(),
    ],
  );

  Widget _failed() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: _title("We couldn't verify that number"),
      ),
      const SizedBox(height: 12),
      _helper(
        'Double-check the number on your dog\'s chip, or upload a certificate and we\'ll confirm it for you.',
      ),
      const SizedBox(height: 24),
      _uploadBox(dashed: true),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _isSaving ? null : _submitCertificate,
        style: _style.primaryButton,
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Submit certificate',
                style: _style.text(16, color: Colors.white),
              ),
      ),
      const SizedBox(height: 10),
      Center(
        child: TextButton(
          onPressed: () => setState(() => _view = _View.form),
          child: Text(
            'Try entering number again',
            style: _style.text(
              13,
              color: _style.coral,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'We\'ll review your certificate and get back to you within 1–2 business days.',
        textAlign: TextAlign.center,
        style: _style.text(
          12,
          color: _style.muted,
          weight: FontWeight.w500,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 8),
      _skipLink(),
    ],
  );

  Widget _result({
    required String title,
    required String message,
    required VoidCallback onContinue,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 8),
      _title(title),
      const SizedBox(height: 28),
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _style.green.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: VitailIcon('badge-check', size: 28, color: _style.green),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        message,
        textAlign: TextAlign.center,
        style: _style.text(
          13,
          color: _style.muted,
          weight: FontWeight.w500,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 28),
      ElevatedButton(
        onPressed: onContinue,
        style: _style.primaryButton,
        child: Text(
          widget.isFromProfile ? 'Done' : 'Continue',
          style: _style.text(16, color: Colors.white),
        ),
      ),
    ],
  );

  Widget _uploadBox({required bool dashed}) {
    final isPdf = _certificateFileName?.toLowerCase().endsWith('.pdf') ?? false;

    final Widget inner = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: _colors.card,
        borderRadius: BorderRadius.circular(16),
        border: dashed ? null : Border.all(color: _style.border),
      ),
      child: _certificateFile == null
          ? Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _colors.tint(const Color(0xFFF2EFE9)),
                    shape: BoxShape.circle,
                  ),
                  child: VitailIcon('arrow-up', size: 18, color: _style.muted),
                ),
                const SizedBox(height: 12),
                Text(
                  'Upload microchip certificate',
                  style: _style.text(14, weight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to take photo or choose document',
                  style: _style.text(
                    12,
                    color: _style.muted,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: isPdf
                      ? Container(
                          width: 54,
                          height: 54,
                          color: _colors.tint(
                            const Color(0xFFFBEFED),
                            const Color(0xFF3C2926),
                          ),
                          child: VitailIcon(
                            'file-text',
                            color: _style.coral,
                            size: 28,
                          ),
                        )
                      : Image.file(
                          _certificateFile!,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 54,
                            height: 54,
                            color: _colors.tint(const Color(0xFFF2EFE9)),
                            child: VitailIcon('file', color: _style.muted),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _certificateFileName ?? 'Certificate',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _style.text(14, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ready to submit · Tap to change',
                        style: _style.text(
                          12,
                          color: _style.green,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: VitailIcon('x', size: 20, color: _style.muted),
                  onPressed: () => setState(() {
                    _certificateFile = null;
                    _certificateFileName = null;
                  }),
                ),
              ],
            ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _pickCertificate,
      child: dashed
          ? CustomPaint(
              painter: _DashedBorderPainter(_style.border),
              child: inner,
            )
          : inner,
    );
  }

  OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      );

    const double dash = 6;
    const double gap = 5;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length).toDouble()),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
