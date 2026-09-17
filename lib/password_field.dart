import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Keeps visibility local to each field without changing its controller or value.
class PasswordField extends StatefulWidget {
  static bool isValid(String value) => value.trim().characters.length >= 6 && value.characters.length <= 64;
  const PasswordField({super.key, required this.controller, required this.decoration,
    required this.autofillHints, required this.textInputAction, this.onSubmitted,
    this.style});
  final TextEditingController controller;
  final InputDecoration decoration;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final TextStyle? style;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;
  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller, obscureText: _hidden,
    autocorrect: false, enableSuggestions: false,
    keyboardType: TextInputType.visiblePassword,
    inputFormatters: [LengthLimitingTextInputFormatter(64)],
    autofillHints: widget.autofillHints, textInputAction: widget.textInputAction,
    onSubmitted: widget.onSubmitted, style: widget.style,
    decoration: widget.decoration.copyWith(
      suffixIcon: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: IconButton(
        tooltip: '${_hidden ? 'Show' : 'Hide'} ${widget.decoration.hintText?.toLowerCase() ?? 'password'}',
        onPressed: () => setState(() => _hidden = !_hidden),
        icon: SizedBox(width: 24, height: 24, child: Center(
          child: SvgPicture.asset('assets/icons/${_hidden ? 'lucide-eye-closed' : 'lucide-eye'}.svg',
            width: _hidden ? 24 : 22, height: _hidden ? 24 : 16,
            excludeFromSemantics: true),
        )),
      )),
    ),
  );
}
