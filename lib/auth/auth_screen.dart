import 'package:flutter/material.dart';

import '../app_state.dart';
import '../bus/bus_api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth_service.dart';

/// Login and Register on one screen. Opened on top of the current screen; closes with
/// `true` after a successful login/registration so the caller can carry on where it was.
class AuthScreen extends StatefulWidget {
  final bool startRegister;

  const AuthScreen({super.key, this.startRegister = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _mobile = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  late bool _register = widget.startRegister;
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _mobile.dispose();
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  String _digits(String s) {
    final b = StringBuffer();
    for (final c in s.runes) {
      if (c >= 48 && c <= 57) b.writeCharCode(c);
    }
    var d = b.toString();
    if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
    if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
    return d;
  }

  String? _validate() {
    final m = _digits(_mobile.text);
    if (m.length != 10 || !'6789'.contains(m[0])) {
      return app.tr('Enter a valid 10-digit mobile number.',
          'சரியான 10 இலக்க மொபைல் எண்ணை உள்ளிடவும்.');
    }
    if (_register && _name.text.trim().length < 2) {
      return app.tr('Enter your name.', 'உங்கள் பெயரை உள்ளிடவும்.');
    }
    if (_pass.text.length < 6) {
      return app.tr('Password must be at least 6 characters.',
          'கடவுச்சொல் குறைந்தது 6 எழுத்துகள் இருக்க வேண்டும்.');
    }
    if (_register && _pass.text != _pass2.text) {
      return app.tr('The two passwords do not match.', 'இரண்டு கடவுச்சொற்களும் பொருந்தவில்லை.');
    }
    if (!app.serverConfigured) {
      return app.tr('Set the server address first (link at the bottom).',
          'முதலில் சர்வர் முகவரியை அமைக்கவும் (கீழே உள்ள இணைப்பு).');
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final m = _digits(_mobile.text);
      if (_register) {
        await auth.register(
            mobile: m, name: _name.text.trim(), password: _pass.text, email: _email.text.trim());
      } else {
        await auth.login(m, _pass.text);
      }
      if (mounted) Navigator.pop(context, true);
      return;
    } catch (e) {
      if (mounted) setState(() => _error = BusApi.friendly(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _serverDialog() async {
    final r = await showFieldsDialog(
      context,
      title: app.tr('Server address', 'சர்வர் முகவரி'),
      note: app.tr('Example: https://api.yoursite.com', 'எ.கா: https://api.yoursite.com'),
      fields: [FieldSpec(app.tr('Address', 'முகவரி'), initial: app.serverText, keyboard: TextInputType.url)],
      okLabel: app.tr('Save', 'சேமி'),
    );
    if (r == null) return;
    await app.setServer(r[0]);
    if (mounted) setState(() => _error = null);
  }

  void _forgot() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(app.tr('Forgot password?', 'கடவுச்சொல் மறந்துவிட்டதா?')),
        content: Text(app.tr(
            'Please contact the I Love APK team. They will reset your password after checking your mobile number.',
            'I Love APK குழுவைத் தொடர்பு கொள்ளுங்கள். உங்கள் மொபைல் எண்ணைச் சரிபார்த்து கடவுச்சொல்லை மாற்றித் தருவார்கள்.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(app.tr('OK', 'சரி'))),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon, {Widget? suffix, String? prefix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      prefixText: prefix,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: Colors.white,
      counterText: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: kBg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kNavy, kBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: app.tr('Close', 'மூடு'),
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    const Spacer(),
                    const LangToggle(onDark: true),
                  ],
                ),
                const SizedBox(height: 18),
                const BrandMark(size: 40, onDark: true),
                const SizedBox(height: 6),
                Text('I Love Aruppukottai',
                    style: ts(17, weight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text('நம் ஊர் • நம் மக்கள் • நம் ஆப்',
                    style: ts(14, color: const Color(0xFFFFD6B8))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _register
                      ? app.tr('Create your account', 'புதிய கணக்கை உருவாக்குங்கள்')
                      : app.tr('Welcome back', 'மீண்டும் வருக'),
                  style: ts(22, weight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _register
                      ? app.tr('Register once. You stay logged in on this phone.',
                          'ஒரு முறை பதிவு செய்யுங்கள். இந்த போனில் தொடர்ந்து உள்நுழைந்தபடியே இருப்பீர்கள்.')
                      : app.tr('Login with your mobile number.', 'மொபைல் எண்ணுடன் உள்நுழையுங்கள்.'),
                  style: ts(14, color: kMuted),
                ),
                const SizedBox(height: 18),
                if (_register) ...[
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: _dec(app.tr('Your name', 'உங்கள் பெயர்'), Icons.person_outline),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  maxLength: 14,
                  decoration: _dec(app.tr('Mobile number', 'மொபைல் எண்'), Icons.phone_android, prefix: '+91 '),
                ),
                const SizedBox(height: 12),
                if (_register) ...[
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _dec(app.tr('E-mail (optional)', 'மின்னஞ்சல் (விருப்பம்)'), Icons.mail_outline),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _pass,
                  obscureText: _hide,
                  decoration: _dec(
                    app.tr('Password', 'கடவுச்சொல்'),
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(_hide ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                ),
                if (_register) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass2,
                    obscureText: _hide,
                    decoration: _dec(app.tr('Confirm password', 'கடவுச்சொல்லை உறுதிசெய்'), Icons.lock_outline),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kRed.withAlpha(18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: kRed, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: ts(13.5, color: kRed, height: 1.35))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: kBrand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(
                            _register ? app.tr('Register', 'பதிவு செய்') : app.tr('Login', 'உள்நுழை'),
                            style: ts(16, weight: FontWeight.w800, color: Colors.white),
                          ),
                  ),
                ),
                if (!_register)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgot,
                      child: Text(app.tr('Forgot password?', 'கடவுச்சொல் மறந்துவிட்டதா?')),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _register
                          ? app.tr('Already have an account?', 'ஏற்கனவே கணக்கு உள்ளதா?')
                          : app.tr('New here?', 'புதிதாக வருகிறீர்களா?'),
                      style: ts(14, color: kMuted),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _register = !_register;
                                _error = null;
                              }),
                      child: Text(
                        _register ? app.tr('Login', 'உள்நுழை') : app.tr('Create account', 'கணக்கு உருவாக்கு'),
                        style: ts(14, weight: FontWeight.w800, color: kBrand),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context, false),
                    child: Text(app.tr('Not now - continue as guest', 'இப்போது வேண்டாம் - விருந்தினராகத் தொடர்க'),
                        style: ts(14, weight: FontWeight.w700, color: kBlue)),
                  ),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: _serverDialog,
                    icon: const Icon(Icons.settings_ethernet, size: 16),
                    label: Text(app.tr('Server address', 'சர்வர் முகவரி'), style: ts(12.5, color: kMuted)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
