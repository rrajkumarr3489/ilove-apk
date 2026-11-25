import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'auth_screen.dart';
import 'auth_service.dart';

/// Guests may look at everything, but may not add or change anything.
/// Call this before any action that saves data: it returns true when somebody is
/// logged in. If not, it explains why, offers Login / Register / Cancel, opens the
/// register (or login) screen on top of the current screen, and returns true only
/// after a successful sign-in - so the caller carries on exactly where it was.
Future<bool> requireLogin(BuildContext context, {String? whyEn, String? whyTa}) async {
  if (auth.loggedIn) return true;

  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.lock_person_outlined, color: kBrand, size: 32),
      title: Text(app.tr('Please register first', 'முதலில் பதிவு செய்யுங்கள்')),
      content: Text(
        app.tr(
          whyEn ??
              'To add a new bus or timing you must be registered, so we know who added it. '
                  'You can still view all bus timings as a guest.',
          whyTa ??
              'புதிய பேருந்து அல்லது நேரத்தைச் சேர்க்க நீங்கள் பதிவு செய்திருக்க வேண்டும் - யார் சேர்த்தார்கள் என்பது தெரிய வேண்டும். '
                  'விருந்தினராக அனைத்து பேருந்து நேரங்களையும் பார்க்கலாம்.',
        ),
        style: ts(14.5, height: 1.4),
      ),
      actionsOverflowButtonSpacing: 4,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'cancel'),
          child: Text(app.tr('Cancel', 'ரத்து')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'login'),
          child: Text(app.tr('Login', 'உள்நுழை')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, 'register'),
          style: FilledButton.styleFrom(backgroundColor: kBrand),
          child: Text(app.tr('Register', 'பதிவு செய்')),
        ),
      ],
    ),
  );

  if (choice != 'login' && choice != 'register') return false; // cancelled: nothing is allowed
  if (!context.mounted) return false;
  final ok = await Navigator.push<bool>(
    context,
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => AuthScreen(startRegister: choice == 'register'),
    ),
  );
  return ok == true && auth.loggedIn;
}
