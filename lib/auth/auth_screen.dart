import 'package:flutter/material.dart';

import '../app_state.dart';
import '../bus/bus_api.dart';
import '../screen_header.dart';
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

  InputDecoration _dec(String hint, {Widget? prefix, Widget? suffix}) {
    OutlineInputBorder b(Color c, double w) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      hintStyle: ts(15, color: kMuted),
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix,
      border: b(Colors.transparent, 0),
      enabledBorder: b(Colors.transparent, 0),
      focusedBorder: b(kBrand, 1.6),
      filled: true,
      fillColor: const Color(0xFFF1F3F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      counterText: '',
    );
  }

  Widget _icon(IconData i) => Padding(padding: const EdgeInsets.only(left: 16, right: 14), child: Icon(i, size: 21, color: kMuted));

  /// Text field with a soft blue glow while it is focused.
  Widget _glow(Widget field) {
    return Focus(
      child: Builder(builder: (ctx) {
        final on = Focus.of(ctx).hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: on ? [BoxShadow(color: kBrand.withAlpha(46), blurRadius: 10)] : const [],
          ),
          child: field,
        );
      }),
    );
  }

  Widget _seg(String label, IconData icon, bool on, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _busy ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          decoration: BoxDecoration(
            color: on ? kBrand : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: on ? [BoxShadow(color: kBrand.withAlpha(70), blurRadius: 10, offset: const Offset(0, 4))] : const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: on ? Colors.white : kBrand),
              const SizedBox(width: 8),
              Text(label, style: ts(15.5, weight: FontWeight.w800, color: on ? Colors.white : kBrand)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primary(String label, IconData icon) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: kBrand,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: kBrand.withAlpha(80), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _busy ? null : _submit,
          child: Center(
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 21),
                      const SizedBox(width: 10),
                      Text(label, style: ts(16.5, weight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _guest() {
    return Container(
      height: 52,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFBBD2F5), width: 1.4)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _busy ? null : () => Navigator.pop(context, false),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.explore_rounded, size: 20, color: kBrandDark),
              const SizedBox(width: 10),
              Text(app.tr('Continue as guest', 'விருந்தினராகத் தொடர்க'), style: ts(15, weight: FontWeight.w800, color: kBrandDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _svc(IconData icon, Color bg, Color fg, String label) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, size: 22, color: fg),
        ),
        const SizedBox(height: 6),
        Text(label, style: ts(12, color: kInk)),
      ],
    );
  }

  void _setRegister(bool v) {
    if (_register == v) return;
    setState(() {
      _register = v;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFEAF1FE), Colors.white]),
              ),
              child: CustomPaint(painter: _DotsPainter()),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Row(
                  children: [
                    HeaderButton(icon: Icons.close_rounded, tooltip: app.tr('Close', 'மூடு'), onTap: () => Navigator.pop(context, false)),
                    const Spacer(),
                    const LangToggle(),
                  ],
                ),
                const SizedBox(height: 2),
                Center(child: Image.asset('assets/logo.png', height: 62)),
                const SizedBox(height: 8),
                Center(child: Text('நம் ஊர் • நம் மக்கள் • நம் ஆப்', style: ts(13.5, color: kInk))),
                const SizedBox(height: 18),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: const Color(0xFFEEF3FC), borderRadius: BorderRadius.circular(18)),
                        child: Row(
                          children: [
                            _seg(app.tr('Login', 'உள்நுழை'), Icons.login_rounded, !_register, () => _setRegister(false)),
                            _seg(app.tr('Register', 'பதிவு'), Icons.person_add_alt_1_rounded, _register, () => _setRegister(true)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        _register ? app.tr('Create your account', 'புதிய கணக்கை உருவாக்குங்கள்') : app.tr('Welcome back', 'மீண்டும் வருக'),
                        style: ts(24, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _register
                            ? app.tr('Register once. You stay logged in on this phone.',
                                'ஒரு முறை பதிவு செய்யுங்கள். இந்த போனில் தொடர்ந்து உள்நுழைந்தபடியே இருப்பீர்கள்.')
                            : app.tr('Login with your mobile number.', 'மொபைல் எண்ணுடன் உள்நுழையுங்கள்.'),
                        style: ts(13.5, color: kMuted, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      if (_register) ...[
                        _glow(TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: _dec(app.tr('Your name', 'உங்கள் பெயர்'), prefix: _icon(Icons.person_outline_rounded)),
                        )),
                        const SizedBox(height: 12),
                      ],
                      _glow(TextField(
                        controller: _mobile,
                        keyboardType: TextInputType.phone,
                        maxLength: 14,
                        decoration: _dec(
                          app.tr('Mobile number', 'மொபைல் எண்'),
                          prefix: Padding(
                            padding: const EdgeInsets.only(left: 16, right: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.smartphone_rounded, size: 21, color: kMuted),
                                const SizedBox(width: 12),
                                Text('+91', style: ts(15, weight: FontWeight.w800)),
                                const SizedBox(width: 10),
                                Container(width: 1, height: 22, color: kLine),
                              ],
                            ),
                          ),
                        ),
                      )),
                      const SizedBox(height: 12),
                      if (_register) ...[
                        _glow(TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _dec(app.tr('E-mail (optional)', 'மின்னஞ்சல் (விருப்பம்)'), prefix: _icon(Icons.mail_outline_rounded)),
                        )),
                        const SizedBox(height: 12),
                      ],
                      _glow(TextField(
                        controller: _pass,
                        obscureText: _hide,
                        decoration: _dec(
                          app.tr('Password', 'கடவுச்சொல்'),
                          prefix: _icon(Icons.lock_outline_rounded),
                          suffix: IconButton(
                            icon: Icon(_hide ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 21, color: kInk),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                      )),
                      if (_register) ...[
                        const SizedBox(height: 12),
                        _glow(TextField(
                          controller: _pass2,
                          obscureText: _hide,
                          decoration: _dec(app.tr('Confirm password', 'கடவுச்சொல்லை உறுதிசெய்'), prefix: _icon(Icons.verified_user_outlined)),
                        )),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: kRed.withAlpha(18), borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_rounded, color: kRed, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: ts(13.5, color: kRed, height: 1.35))),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _primary(
                        _register ? app.tr('Register', 'பதிவு செய்') : app.tr('Login', 'உள்நுழை'),
                        _register ? Icons.how_to_reg_rounded : Icons.login_rounded,
                      ),
                      if (!_register)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _forgot,
                            child: Text(app.tr('Forgot password?', 'கடவுச்சொல் மறந்துவிட்டதா?'), style: ts(13.5, weight: FontWeight.w800, color: kBrandDark)),
                          ),
                        )
                      else
                        const SizedBox(height: 8),
                      Row(children: [
                        const Expanded(child: Divider(color: kLine)),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(app.tr('or', 'அல்லது'), style: ts(12.5, color: kMuted))),
                        const Expanded(child: Divider(color: kLine)),
                      ]),
                      const SizedBox(height: 12),
                      _guest(),
                      if (!_register) ...[
                        const SizedBox(height: 16),
                        Center(child: Text(app.tr('Everything in Aruppukottai, in one app', 'அருப்புக்கோட்டை முழுவதும் ஒரே ஆப்பில்'), style: ts(12.5, color: kMuted))),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _svc(Icons.directions_bus_rounded, const Color(0xFFE8F0FE), kBrand, app.tr('Bus', 'பேருந்து')),
                            _svc(Icons.article_outlined, const Color(0xFFE6F4EA), kGreen, app.tr('News', 'செய்தி')),
                            _svc(Icons.restaurant_rounded, const Color(0xFFFEF0E0), const Color(0xFFF57C00), app.tr('Food', 'உணவு')),
                            _svc(Icons.work_outline_rounded, const Color(0xFFE8EAF6), const Color(0xFF3F51B5), app.tr('Jobs', 'வேலை')),
                            _svc(Icons.warning_amber_rounded, const Color(0xFFFCE8E6), kRed, app.tr('Report', 'புகார்')),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton.icon(
                          onPressed: _serverDialog,
                          icon: const Icon(Icons.settings_ethernet_rounded, size: 16, color: kMuted),
                          label: Text(app.tr('Server address', 'சர்வர் முகவரி'), style: ts(12, color: kMuted)),
                        ),
                      ),
                    ],
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

/// Very light dots in the top part of the screen (fade out downwards).
class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (var y = 10.0; y < size.height; y += 16) {
      final a = (40 * (1 - y / size.height)).round();
      final p = Paint()..color = kBrand.withAlpha(a);
      for (var x = 8.0; x < size.width; x += 16) {
        canvas.drawCircle(Offset(x, y), 1, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
