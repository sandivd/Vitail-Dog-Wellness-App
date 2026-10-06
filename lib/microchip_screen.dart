import 'vitail_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_screen.dart';
import 'onboarding_goal_screen.dart';
import 'onboarding_style.dart';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'certificate_reader.dart';
import 'certificate_scanner.dart';

String? microchipNumberError(String raw) {
  final String value = raw.trim();
  if (value.isEmpty) return 'Enter your dog\'s 15-digit microchip number.';
  if (!RegExp(r'^\d{15}$').hasMatch(value)) {
    return 'A microchip number is exactly 15 digits.';
  }
  if (value.startsWith('999')) {
    return 'Numbers starting with 999 are test codes, not registered chips.';
  }
  return null;
}

enum _View { form, verified, failed, submitted }

class MicrochipScreen extends StatefulWidget {
  const MicrochipScreen({super.key, this.dogId});

  final String? dogId;

  @override
  State<MicrochipScreen> createState() => _MicrochipScreenState();
}

class _MicrochipScreenState extends State<MicrochipScreen> {
  final TextEditingController _numberController = TextEditingController();

  _View _view = _View.form;
  bool _uploadTab = false;
  static const int _maxBytes = 10 * 1024 * 1024;

  PlatformFile? _certificate;
  bool _uploading = false;

    bool _scanning = false;
  CertificateReading? _reading;
  String? _dogName;
  DateTime? _dogBirthday;

  @override
  void initState() {
    super.initState();
    _loadDog();
  }

  Future<void> _loadDog() async {
    final String? dogId = widget.dogId;
    if (dogId == null) return;
    try {
      final Map<String, dynamic>? dog = await Supabase.instance.client
          .from('dogs')
          .select('dog_name, birthday')
          .eq('id', dogId)
          .maybeSingle();
      if (dog == null) return;
      _dogName = dog['dog_name'] as String?;
      final String? birthday = dog['birthday'] as String?;
      _dogBirthday = birthday == null ? null : DateTime.tryParse(birthday);
    } catch (e) {
      debugPrint('Could not load dog details: ${e.runtimeType}');
    }
  }

  Future<void> _readCertificate(PlatformFile file) async {
    try {
      final String text = await extractCertificateText(file);
      final CertificateReading reading = readCertificateText(
        text,
        dogName: _dogName,
        dogBirthday: _dogBirthday,
      );
      if (mounted && identical(_certificate, file)) {
        setState(() => _reading = reading);
      }
    } catch (e) {
      debugPrint('Certificate reader failed: ${e.runtimeType}');
    } finally {
      if (mounted && identical(_certificate, file)) {
        setState(() => _scanning = false);
      }
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.pushReplacement<void, void>(
      context,
      onboardingFadeRoute<void>(const HomeScreen()),
    );
  }

  void _verify() {
    FocusScope.of(context).unfocus();
    final String? error = microchipNumberError(_numberController.text);
    setState(() => _view = error == null ? _View.verified : _View.failed);
  }

  void _back() {
    switch (_view) {
      case _View.form:
        Navigator.maybePop(context);
      case _View.failed:
      case _View.verified:
      case _View.submitted:
        setState(() => _view = _View.form);
    }
  }

    void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      default:
        return 'image/jpeg';
    }
  }

    Future<void> _pickCertificate() async {
    if (_uploading) return;
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (file == null || !mounted) return;
    final int? bytes = await file.length();
    if (!mounted) return;
    if (bytes == null || bytes == 0) {
      _showMessage("We couldn't read that file. Try another one.");
      return;
    }
    if (bytes > _maxBytes) {
      _showMessage('That file is over 10 MB. Try a smaller scan or photo.');
      return;
    }
    setState(() {
      _certificate = file;
      _reading = null;
      _scanning = true;
    });
    await _readCertificate(file);
  }

  Future<void> _submitCertificate() async {
    final PlatformFile? file = _certificate;
    final String? dogId = widget.dogId;
    final CertificateReading? reading = _reading;
    if (file == null) {
      _showMessage('Choose your certificate first.');
      return;
    }
    final SupabaseClient client = Supabase.instance.client;
    final String? userId = client.auth.currentUser?.id;
    if (dogId == null || file.path == null || userId == null) {
      _showMessage('Something went wrong. Please try again.');
      return;
    }

    final String extension = file.name.split('.').last.toLowerCase();
    final String storagePath =
        '$userId/$dogId/${DateTime.now().millisecondsSinceEpoch}.$extension';

    setState(() => _uploading = true);
    try {
      await client.storage.from('microchip_certificates').upload(
            storagePath,
            File(file.path!),
            fileOptions: FileOptions(contentType: _contentType(extension)),
          );
      try {
        await client.from('microchip_submissions').insert({
          'dog_id': dogId,
          'file_path': storagePath,
          'extracted_microchip': reading?.microchipNumber,
          'reader_flags': reading == null
              ? <String>['reader_failed']
              : reading.issues.map((issue) => issue.name).toList(),
        });
      } catch (_) {
        await client.storage.from('microchip_certificates').remove([storagePath]);
        rethrow;
      }
      if (!mounted) return;
      setState(() {
        _certificate = null;
        _view = _View.submitted;
      });
    } catch (e) {
      debugPrint('Certificate upload failed: $e');
      if (mounted) _showMessage("Couldn't upload your certificate. Please try again.");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _submitButton() => ElevatedButton(
        onPressed: _certificate == null ||
                _uploading ||
                _scanning ||
                _reading?.canSubmit == false
            ? null
            : _submitCertificate,
        style: OnboardingStyle.primaryButton,
        child: _uploading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: OnboardingStyle.muted),
              )
            : Text('Submit certificate',
                style: OnboardingStyle.text(16, color: Colors.white)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingStyle.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: _back,
                  icon: OnboardingStyle.icon('back'),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Container(
                      alignment: Alignment.topCenter,
                      padding: EdgeInsets.only(
                          top: constraints.maxHeight * 0.10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            layoutBuilder:
                                (currentChild, previousChildren) => Stack(
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
          title: 'Microchip verified',
          message:
              'Nice, you\'re all set to redeem reward coupons too.',
          onContinue: _finish,
        );
      case _View.failed:
        return _failed();
            case _View.submitted:
        return _result(
          title: 'Certificate submitted',
          message:
              'We\'ve received your certificate. We\'ll verify it and get back to you within 24 hours.',
            icon: 'clock',
            onContinue: _finish,
        );
    }
  }

  Widget _title(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: OnboardingStyle.text(22, weight: FontWeight.w700, height: 1.3),
      );

  Widget _helper(String text) => Text(
        text,
        style: OnboardingStyle.text(12,
            color: OnboardingStyle.muted, weight: FontWeight.w500, height: 1.5),
      );

  Widget _tabs() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFEAE5DC),
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
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              style: OnboardingStyle.text(
                13,
                color: active ? OnboardingStyle.ink : OnboardingStyle.muted,
                weight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );

  Widget _skipLink() => Center(
        child: TextButton(
          onPressed: _finish,
          child: Text(
            'Skip for now, use the app as a tracker & journal',
            textAlign: TextAlign.center,
            style: OnboardingStyle.text(12,
                color: OnboardingStyle.muted, weight: FontWeight.w500),
          ),
        ),
      );

  Widget _numberForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _title("Add your dog's microchip"),
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
              Text('Microchip number',
                  style: OnboardingStyle.text(13, weight: FontWeight.w600)),
              const Spacer(),
              Text('optional',
                  style: OnboardingStyle.text(12,
                      color: OnboardingStyle.muted, weight: FontWeight.w500)),
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
            style: OnboardingStyle.text(14, weight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: '15-digit number',
              hintStyle: OnboardingStyle.text(14,
                  color: OnboardingStyle.muted, weight: FontWeight.w400),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              enabledBorder: _fieldBorder(OnboardingStyle.border),
              focusedBorder: _fieldBorder(OnboardingStyle.coral),
              border: _fieldBorder(OnboardingStyle.border),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _verify,
            style: OnboardingStyle.primaryButton,
            child: Text('Verify',
                style: OnboardingStyle.text(16, color: Colors.white)),
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
            child: _title("Add your dog's microchip"),
          ),
          const SizedBox(height: 20),
          _tabs(),
          const SizedBox(height: 14),
          _helper(
            'Optional: upload your dog\'s microchip certificate and we\'ll verify it for you.',
          ),
          const SizedBox(height: 20),
          _uploadBox(dashed: false),
          _readingSummary(),
          const SizedBox(height: 20),
          _submitButton(),
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
          _readingSummary(),
          const SizedBox(height: 20),
          _submitButton(),
          const SizedBox(height: 14),
          Text(
            'We\'ll review your certificate and get back to you within 1\u20132 business days.',
            textAlign: TextAlign.center,
            style: OnboardingStyle.text(12,
                color: OnboardingStyle.muted, weight: FontWeight.w500, height: 1.5),
          ),
          const SizedBox(height: 8),
          _skipLink(),
        ],
      );

  Widget _result({
    required String title,
    required String message,
    required VoidCallback onContinue,
    String icon = 'badge-check',
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _title(title),
          const SizedBox(height: 28),
          Center(child: OnboardingBadge(icon: icon)),          
          const SizedBox(height: 24),
          Text(
            message,
            textAlign: TextAlign.center,
            style: OnboardingStyle.text(13,
                color: OnboardingStyle.muted, weight: FontWeight.w500, height: 1.5),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: onContinue,
            style: OnboardingStyle.primaryButton,
            child: Text('Continue',
                style: OnboardingStyle.text(16, color: Colors.white)),
          ),
        ],
      );

    Widget _uploadBox({required bool dashed}) {
    final PlatformFile? file = _certificate;
    final Widget inner = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: dashed ? null : Border.all(color: OnboardingStyle.border),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFF2EFE9),
              shape: BoxShape.circle,
            ),
            child: VitailIcon(file == null ? 'arrow-up' : 'circle-check',
                size: 18, color: OnboardingStyle.muted),
          ),
          const SizedBox(height: 12),
          Text(
            file == null ? 'Upload microchip certificate' : file.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: OnboardingStyle.text(14, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            file == null ? 'PDF, JPG or PNG' : 'Tap to choose a different file',
            style: OnboardingStyle.text(12,
                color: OnboardingStyle.muted, weight: FontWeight.w500),
          ),
        ],
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _uploading ? null : _pickCertificate,
      child: dashed
          ? CustomPaint(painter: const _DashedBorderPainter(), child: inner)
          : inner,
    );
  }

    Widget _readingSummary() {
    if (_certificate == null) return const SizedBox.shrink();
    if (_scanning) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: OnboardingStyle.coral),
            ),
            const SizedBox(width: 10),
            Text('Reading your certificate…',
                style: OnboardingStyle.text(12,
                    color: OnboardingStyle.muted, weight: FontWeight.w500)),
          ],
        ),
      );
    }
    final CertificateReading? reading = _reading;
    final List<Widget> rows = <Widget>[];
    if (reading == null) {
      rows.add(_readingRow(
        Icons.info_outline,
        "We couldn't read this file automatically. You can still submit it and our team will check it.",
        OnboardingStyle.muted,
      ));
    } else {
      final String? number = reading.microchipNumber;
      if (number != null) {
        rows.add(_readingRow(Icons.check_circle_outline,
            'Microchip number found: ${_groupDigits(number)}', OnboardingStyle.ink));
      }
      for (final CertificateIssue issue in reading.issues) {
        rows.add(_readingRow(
          issue.blocksSubmit ? Icons.error_outline : Icons.info_outline,
          issue.message,
          issue.blocksSubmit ? OnboardingStyle.coral : OnboardingStyle.muted,
        ));
      }
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }

  Widget _readingRow(IconData icon, String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: OnboardingStyle.text(12,
                      color: color, weight: FontWeight.w500, height: 1.4)),
            ),
          ],
        ),
      );

  String _groupDigits(String digits) => [
        for (int i = 0; i < digits.length; i += 3)
          digits.substring(i, i + 3 > digits.length ? digits.length : i + 3),
      ].join(' ');

  OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color),
      );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = OnboardingStyle.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(16),
      ));

    const double dash = 6;
    const double gap = 5;

    for (final metric in path.computeMetrics()) {      
      double distance = 0;
      while (distance < metric.length) {
        final double next = distance + dash;
        canvas.drawPath(
          metric.extractPath(
              distance, next.clamp(0, metric.length).toDouble()),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}