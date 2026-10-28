import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'theme.dart';

/// The short line added at the end of everything that is shared from the app.
String shareFooter() => app.tr('Shared from I Love APK - Aruppukottai', 'I Love APK (அருப்புக்கோட்டை) செயலியிலிருந்து பகிரப்பட்டது');

/// Opens a bottom sheet with WhatsApp, Facebook, Telegram, SMS and Copy.
/// [text] is the message; [link] (optional) is the page the message points to (Facebook needs a link).
Future<void> showShareSheet(BuildContext context, {required String text, String link = ''}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => _ShareSheet(text: text, link: link),
  );
}

class _ShareOption {
  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;

  const _ShareOption(this.label, this.icon, this.color, this.onTap);
}

class _ShareSheet extends StatelessWidget {
  final String text;
  final String link;

  const _ShareSheet({required this.text, required this.link});

  Future<void> _open(ScaffoldMessengerState messenger, String url) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(app.tr('This app is not installed on your phone.', 'இந்த செயலி உங்கள் போனில் இல்லை.'))));
    }
  }

  Future<void> _copy(ScaffoldMessengerState messenger) async {
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(app.tr('Copied. You can paste it anywhere.', 'நகலெடுக்கப்பட்டது. எங்கும் ஒட்டலாம்.'))));
  }

  @override
  Widget build(BuildContext context) {
    final enc = Uri.encodeComponent(text);
    final messenger = ScaffoldMessenger.of(context);
    final options = <_ShareOption>[
      _ShareOption('WhatsApp', Icons.chat, const Color(0xFF25D366), () async {
        Navigator.pop(context);
        await _open(messenger, 'https://wa.me/?text=$enc');
      }),
      _ShareOption('Facebook', Icons.facebook, const Color(0xFF1877F2), () async {
        Navigator.pop(context);
        if (link.isNotEmpty) {
          await _open(messenger, 'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(link)}&quote=$enc');
        } else {
          // Facebook only shares links, so the text is copied and Facebook opens for pasting.
          await Clipboard.setData(ClipboardData(text: text));
          messenger.showSnackBar(SnackBar(
              content: Text(app.tr('Text copied. Paste it in your Facebook post.', 'எழுத்து நகலெடுக்கப்பட்டது. Facebook பதிவில் ஒட்டுங்கள்.'))));
          await _open(messenger, 'https://www.facebook.com');
        }
      }),
      _ShareOption('Telegram', Icons.send, const Color(0xFF229ED9), () async {
        Navigator.pop(context);
        await _open(messenger, 'https://t.me/share/url?url=${Uri.encodeComponent(link.isEmpty ? 'https://t.me' : link)}&text=$enc');
      }),
      _ShareOption('SMS', Icons.sms, const Color(0xFF8E24AA), () async {
        Navigator.pop(context);
        await _open(messenger, 'sms:?body=$enc');
      }),
      _ShareOption(app.tr('Copy', 'நகலெடு'), Icons.copy, kNavy, () async {
        Navigator.pop(context);
        await _copy(messenger);
      }),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 14),
            Text(app.tr('Share', 'பகிர்'), style: ts(18, weight: FontWeight.w900)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 18,
              runSpacing: 16,
              children: [
                for (final o in options)
                  InkWell(
                    onTap: o.onTap,
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          CircleAvatar(radius: 26, backgroundColor: o.color, child: Icon(o.icon, color: Colors.white, size: 26)),
                          const SizedBox(height: 6),
                          Text(o.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
