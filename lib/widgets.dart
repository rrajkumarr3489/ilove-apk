import 'package:flutter/material.dart';

import 'app_state.dart';
import 'theme.dart';

class FieldSpec {
  final String label;
  final String initial;
  final bool obscure;
  final TextInputType keyboard;

  const FieldSpec(this.label,
      {this.initial = '', this.obscure = false, this.keyboard = TextInputType.text});
}

/// A small dialog with one or more text fields. Returns the typed values, or null when cancelled.
Future<List<String>?> showFieldsDialog(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  required String okLabel,
  String? note,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => _FieldsDialog(title: title, fields: fields, okLabel: okLabel, note: note),
  );
}

class _FieldsDialog extends StatefulWidget {
  final String title;
  final List<FieldSpec> fields;
  final String okLabel;
  final String? note;

  const _FieldsDialog(
      {required this.title, required this.fields, required this.okLabel, this.note});

  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  late final List<TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    _c = [for (final f in widget.fields) TextEditingController(text: f.initial)];
  }

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.note != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(widget.note!, style: ts(13, color: kMuted, height: 1.4)),
              ),
            for (var i = 0; i < widget.fields.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _c[i],
                  obscureText: widget.fields[i].obscure,
                  keyboardType: widget.fields[i].keyboard,
                  decoration: InputDecoration(
                    labelText: widget.fields[i].label,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(app.tr('Cancel', 'ரத்து')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, [for (final c in _c) c.text.trim()]),
          child: Text(widget.okLabel),
        ),
      ],
    );
  }
}

Future<bool> confirmDialog(BuildContext context, String title, String message,
    {String? okLabel}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(app.tr('Cancel', 'ரத்து')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(okLabel ?? app.tr('OK', 'சரி')),
        ),
      ],
    ),
  );
  return r == true;
}

/// தமிழ் | English switch.
class LangToggle extends StatelessWidget {
  final bool onDark;

  const LangToggle({super.key, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    // Listens to the language itself, so the highlighted choice always follows it
    // (a const LangToggle placed in a screen is not rebuilt by that screen).
    return ListenableBuilder(listenable: app, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    Widget chip(String code, String label) {
      final sel = app.lang == code;
      return GestureDetector(
        onTap: () => app.setLang(code),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? (onDark ? Colors.white : kBrand) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: ts(13,
                weight: FontWeight.w700,
                color: sel ? (onDark ? kNavy : Colors.white) : (onDark ? Colors.white : kMuted)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: onDark ? Colors.white54 : kLine),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        chip('ta', 'தமிழ்'),
        chip('en', 'English'),
      ]),
    );
  }
}

/// "I ❤ APK" logo text used on the login and home screens.
class BrandMark extends StatelessWidget {
  final double size;
  final bool onDark;

  const BrandMark({super.key, this.size = 34, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    // The real logo (small PNG inside the app). If it cannot be loaded, the text version is shown.
    return Image.asset(
      'assets/logo.png',
      height: size * 1.9,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => Text.rich(
        TextSpan(
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, height: 1.1),
          children: [
            TextSpan(text: 'I ', style: TextStyle(color: onDark ? Colors.white : kBrand)),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(Icons.favorite, color: const Color(0xFFFF5252), size: size * 0.9),
            ),
            TextSpan(text: ' APK', style: TextStyle(color: onDark ? Colors.white : kNavy)),
          ],
        ),
      ),
    );
  }
}
