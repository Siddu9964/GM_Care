import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'patient_dashboard.dart';
import 'create_account_screen.dart';

const _kPrimary      = Color(0xFF1F6B4A);
const _kPrimaryLight = Color(0xFF26875B);
const _kBg           = Color(0xFFF3EFE6);
const _kSurface      = Color(0xFFFFFFFF);
const _kTextDark     = Color(0xFF143B2A);
const _kTextMuted    = Color(0xFF5A6E64);
const _kBorder       = Color(0xFFDED8CB);

enum _FlowState { enterPhone, login, setPassword }

class FirstTimeMobileScreen extends StatefulWidget {
  final String? initialPhone;
  final String? initialBranch;

  const FirstTimeMobileScreen({
    super.key,
    this.initialPhone,
    this.initialBranch,
  });

  @override
  State<FirstTimeMobileScreen> createState() => _FirstTimeMobileScreenState();
}

class _FirstTimeMobileScreenState extends State<FirstTimeMobileScreen>
    with SingleTickerProviderStateMixin {

  final TextEditingController _phoneCtrl       = TextEditingController();
  final FocusNode             _phoneFocus      = FocusNode();
  final TextEditingController _passCtrl        = TextEditingController();
  final FocusNode             _passFocus       = FocusNode();
  bool _obscurePass    = true;
  final TextEditingController _newPassCtrl     = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();
  final FocusNode             _newPassFocus    = FocusNode();
  final FocusNode             _confirmPassFocus = FocusNode();
  bool _obscureNew     = true;
  bool _obscureConfirm = true;

  _FlowState _flowState = _FlowState.enterPhone;
  bool   _isLoading = false;
  String? _errorMsg;
  Map<String, dynamic>? _foundPatient;
  String _foundBranch = 'Nagarabhavi';

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: 0.0,
    );
    _fadeAnim  = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();

    if (widget.initialBranch != null && widget.initialBranch!.isNotEmpty) {
      _foundBranch = widget.initialBranch!;
    }

    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      _phoneCtrl.text = widget.initialPhone!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onContinue();
      });
    } else {
      _checkExistingSession();
    }

    _phoneFocus.addListener(()       => setState(() {}));
    _passFocus.addListener(()        => setState(() {}));
    _newPassFocus.addListener(()     => setState(() {}));
    _confirmPassFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _phoneCtrl.dispose();       _phoneFocus.dispose();
    _passCtrl.dispose();        _passFocus.dispose();
    _newPassCtrl.dispose();     _newPassFocus.dispose();
    _confirmPassCtrl.dispose(); _confirmPassFocus.dispose();
    super.dispose();
  }

  Future<void> _checkExistingSession() async {
    final prefs     = await SharedPreferences.getInstance();
    final cookie    = prefs.getString('session_cookie')     ?? '';
    final patientId = prefs.getString('session_patient_id') ?? '';
    final name      = prefs.getString('session_name')       ?? '';
    final branch    = prefs.getString('session_branch')     ?? 'Nagarabhavi';
    final age       = prefs.getString('session_age')        ?? '--';
    final sex       = prefs.getString('session_sex')        ?? 'Unknown';
    if (cookie.isNotEmpty && patientId.isNotEmpty && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => PatientDashboard(userName: name, location: branch, cookie: cookie, patientId: patientId, age: age, sex: sex),
      ));
    }
  }

  Future<void> _onContinue() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    final cleanPhone = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length != 10) { setState(() => _errorMsg = 'Please enter a valid 10-digit mobile number.'); return; }
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      const branches = ['Nagarabhavi', 'Basaveshwaranagar'];
      Map<String, dynamic>? foundPatient;
      String foundBranch = 'Nagarabhavi';
      final futures = branches.map((branch) async {
        try {
          final res = await http.get(Uri.parse(ApiConfig.patientSearch(cleanPhone)), headers: {'X-Hospital-Branch': branch, 'Accept': 'application/json'}).timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) {
            final json = jsonDecode(res.body);
            dynamic data = json['data'];
            if (data is Map && data.containsKey('data')) data = data['data'];
            if (data is List) {
              final match = data.where((p) {
                final pPhone = (p['phone']?.toString() ?? '').replaceAll(RegExp(r'\D'), '');
                return pPhone == cleanPhone || pPhone.endsWith(cleanPhone) || cleanPhone.endsWith(pPhone);
              }).toList();
              if (match.isNotEmpty) return {'branch': branch, 'patient': Map<String, dynamic>.from(match.first)};
            }
          }
        } catch (_) {}
        return null;
      });
      final results = await Future.wait(futures);
      for (final r in results) {
        if (r != null) { foundBranch = r['branch'] as String; foundPatient = r['patient'] as Map<String, dynamic>; break; }
      }
      if (!mounted) return;
      if (foundPatient == null) {
        Navigator.of(context).push(_smoothRoute(CreateAccountScreen(branchName: 'Nagarabhavi', initialPhone: cleanPhone)));
      } else {
        final dynamic hp = foundPatient['has_password'];
        final dynamic passVal = foundPatient['password'];
        final bool passwordNotSet = (hp == false || hp == 0 || hp == 'false' || hp == '0') ||
            (passVal != null && passVal.toString().trim().isEmpty);

        setState(() {
          _foundPatient = foundPatient;
          _foundBranch = foundBranch;
          _flowState = passwordNotSet ? _FlowState.setPassword : _FlowState.login;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus(_flowState == _FlowState.login ? _passFocus : _newPassFocus);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _errorMsg = 'Unable to reach GM Hospital server.\nPlease check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    final password   = _passCtrl.text;
    final cleanPhone = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    if (password.isEmpty) { setState(() => _errorMsg = 'Please enter your password.'); return; }
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final branches = [_foundBranch, _foundBranch == 'Nagarabhavi' ? 'Basaveshwaranagar' : 'Nagarabhavi'];
      http.Response? successRes; Map<String, dynamic>? successData; String activeBranch = _foundBranch;
      for (final branch in branches) {
        final res = await http.post(Uri.parse(ApiConfig.login), headers: {'Content-Type': 'application/json', 'X-Hospital-Branch': branch}, body: jsonEncode({'username': cleanPhone, 'password': password})).timeout(const Duration(seconds: 12));
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (res.statusCode == 200 && data['status'] == 'success') { successRes = res; successData = data; activeBranch = branch; break; }
        final msg = (data['message'] ?? '').toString().toLowerCase();
        if (msg.contains('password') && (msg.contains('not set') || msg.contains('not found'))) {
          if (mounted) setState(() { _isLoading = false; _flowState = _FlowState.setPassword; });
          return;
        }
      }
      if (successRes == null || successData == null) { setState(() { _isLoading = false; _errorMsg = 'Incorrect password. Please try again.'; }); return; }
      final userData  = successData['data'] ?? successData['user'] ?? {};
      final name      = userData['first_name']?.toString() ?? '${_foundPatient?['first_name'] ?? ''}'.trim();
      final age       = userData['age']?.toString() ?? '--';
      final sex       = userData['sex']?.toString() ?? 'Unknown';
      final patientId = userData['patient_id']?.toString() ?? _foundPatient?['patient_id']?.toString() ?? '';
      final rawCookie = (successRes.headers['set-cookie'] ?? '').split(';')[0];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_cookie', rawCookie);    await prefs.setString('session_name', name);
      await prefs.setString('session_branch', activeBranch); await prefs.setString('session_patient_id', patientId);
      await prefs.setString('session_age', age);             await prefs.setString('session_sex', sex);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => PatientDashboard(userName: name, location: activeBranch, cookie: rawCookie, age: age, sex: sex, patientId: patientId)), (route) => false);
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _errorMsg = 'Unable to connect to hospital server.\nPlease check your network connection.'; });
    }
  }

  Future<void> _setPasswordAndLogin() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    final cleanPhone = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    final pass = _newPassCtrl.text; final confirm = _confirmPassCtrl.text;
    if (pass.isEmpty)    { setState(() => _errorMsg = 'Please enter a new password.'); return; }
    if (pass.length < 6) { setState(() => _errorMsg = 'Password must be at least 6 characters.'); return; }
    if (pass != confirm) { setState(() => _errorMsg = 'Passwords do not match. Please re-check.'); return; }
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final resetRes = await http.post(Uri.parse(ApiConfig.resetPassword), headers: {'Content-Type': 'application/json', 'X-Hospital-Branch': _foundBranch}, body: jsonEncode({'identifier': cleanPhone, 'new_password': pass})).timeout(const Duration(seconds: 12));
      if (resetRes.statusCode != 200) {
        final body = jsonDecode(resetRes.body);
        setState(() { _isLoading = false; _errorMsg = body['message']?.toString() ?? 'Unable to set password. Please try again.'; }); return;
      }
      final loginRes = await http.post(Uri.parse(ApiConfig.login), headers: {'Content-Type': 'application/json', 'X-Hospital-Branch': _foundBranch}, body: jsonEncode({'username': cleanPhone, 'password': pass})).timeout(const Duration(seconds: 12));
      if (loginRes.statusCode == 200) {
        final loginData = jsonDecode(loginRes.body);
        final userData  = loginData['data'] ?? loginData['user'] ?? {};
        final name      = userData['first_name']?.toString() ?? '${_foundPatient?['first_name'] ?? ''}'.trim();
        final age       = userData['age']?.toString() ?? '--';
        final sex       = userData['sex']?.toString() ?? 'Unknown';
        final patientId = userData['patient_id']?.toString() ?? _foundPatient?['patient_id']?.toString() ?? '';
        final rawCookie = (loginRes.headers['set-cookie'] ?? '').split(';')[0];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_cookie', rawCookie);   await prefs.setString('session_name', name);
        await prefs.setString('session_branch', _foundBranch); await prefs.setString('session_patient_id', patientId);
        await prefs.setString('session_age', age);            await prefs.setString('session_sex', sex);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password created! Welcome to GM Care, $name 🎉', style: GoogleFonts.inter(fontWeight: FontWeight.w600)), backgroundColor: _kPrimary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16)));
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => PatientDashboard(userName: name, location: _foundBranch, cookie: rawCookie, age: age, sex: sex, patientId: patientId)), (route) => false);
      } else {
        if (mounted) setState(() { _isLoading = false; _flowState = _FlowState.login; _errorMsg = 'Password set! Please enter it below to sign in.'; });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _errorMsg = 'Network error. Please check your connection and try again.'; });
    }
  }

  void _resetToPhoneEntry() {
    setState(() { _flowState = _FlowState.enterPhone; _errorMsg = null; _foundPatient = null; _passCtrl.clear(); _newPassCtrl.clear(); _confirmPassCtrl.clear(); });
    WidgetsBinding.instance.addPostFrameCallback((_) => FocusScope.of(context).requestFocus(_phoneFocus));
  }

  PageRouteBuilder<dynamic> _smoothRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, anim, secondaryAnimation, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child),
      ),
    );
  }

  void _primaryAction() {
    switch (_flowState) {
      case _FlowState.enterPhone:  _onContinue();
      case _FlowState.login:       _login();
      case _FlowState.setPassword: _setPasswordAndLogin();
    }
  }

  String get _buttonLabel {
    switch (_flowState) {
      case _FlowState.enterPhone:  return 'Continue';
      case _FlowState.login:       return 'Log In to Account';
      case _FlowState.setPassword: return 'Set Password & Sign In';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPrimary.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPrimary.withValues(alpha: 0.03),
              ),
            ),
          ),
          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset > 0 ? bottomInset + 20 : 32),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _kPrimary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: _kPrimary.withValues(alpha: 0.2)),
                                boxShadow: [
                                  BoxShadow(color: _kPrimary.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
                                ]
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(width: 8, height: 8, decoration: const BoxDecoration(color: _kPrimaryLight, shape: BoxShape.circle)),
                                const SizedBox(width: 10),
                                Text('GM HOSPITALS · BANGALORE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kPrimary)),
                              ]),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              width: 200, height: 180,
                              decoration: BoxDecoration(
                                color: _kSurface,
                                shape: BoxShape.circle,
                                border: Border.all(color: _kBorder.withValues(alpha: 0.8), width: 3),
                                boxShadow: [
                                  BoxShadow(color: _kPrimary.withValues(alpha: 0.12), blurRadius: 40, offset: const Offset(0, 15)),
                                ],
                              ),
                              child: ClipOval(
                                child: Padding(
                                  padding: const EdgeInsets.all(0),
                                  child: Image.asset(
                                    'assetes/gm_logoo.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_hospital_rounded, color: _kPrimary, size: 100),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              _flowState == _FlowState.enterPhone ? 'Your Health,\nJust a Tap Away.' : _flowState == _FlowState.login ? 'Welcome Back!' : 'Secure Your Account',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w900, color: _kTextDark, height: 1.15, letterSpacing: -0.8),
                            ),
                            const SizedBox(height: 12),
                            const SizedBox(height: 36),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                                decoration: BoxDecoration(
                                  color: _kSurface,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: _kBorder),
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 30, offset: const Offset(0, 12))
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_flowState != _FlowState.enterPhone) ...[_buildPatientBanner(), const SizedBox(height: 24)],
                                    Text('Mobile Number', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _kTextDark)),
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: _flowState != _FlowState.enterPhone ? const Color(0xFFEBE6DC) : const Color(0xFFFAF8F5),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: _phoneFocus.hasFocus ? _kPrimary : _kBorder, width: _phoneFocus.hasFocus ? 1.5 : 1.0),
                                      ),
                                      child: Row(children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          decoration: const BoxDecoration(border: Border(right: BorderSide(color: _kBorder))),
                                          child: Row(children: [
                                            const Text('🇮🇳', style: TextStyle(fontSize: 16)),
                                            const SizedBox(width: 8),
                                            Text('+91', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _kTextDark)),
                                          ]),
                                        ),
                                        Expanded(child: TextField(
                                          controller: _phoneCtrl, focusNode: _phoneFocus,
                                          keyboardType: TextInputType.phone,
                                          enabled: _flowState == _FlowState.enterPhone,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: _flowState != _FlowState.enterPhone ? _kTextMuted : _kTextDark),
                                          decoration: InputDecoration(
                                            hintText: '98765 43210',
                                            hintStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0.5, color: const Color(0xFF94A3B8)),
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            disabledBorder: InputBorder.none,
                                            errorBorder: InputBorder.none,
                                            filled: false,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                                          ),
                                          onChanged: (_) { if (_errorMsg != null) setState(() => _errorMsg = null); },
                                          onSubmitted: (_) => _onContinue(),
                                        )),
                                        if (_flowState == _FlowState.enterPhone && _phoneCtrl.text.isNotEmpty)
                                          IconButton(icon: const Icon(Icons.cancel_rounded, size: 20, color: Color(0xFF94A3B8)), onPressed: () { _phoneCtrl.clear(); setState(() => _errorMsg = null); }),
                                        if (_flowState != _FlowState.enterPhone)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: TextButton(
                                              onPressed: _resetToPhoneEntry,
                                              style: TextButton.styleFrom(
                                                foregroundColor: _kPrimary,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                backgroundColor: _kPrimary.withValues(alpha: 0.08),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              child: Text('Change', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800)),
                                            ),
                                          ),
                                      ]),
                                    ),
                                    if (_flowState == _FlowState.login) ...[
                                      const SizedBox(height: 24),
                                      Text('Password', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _kTextDark)),
                                      const SizedBox(height: 12),
                                      _buildPasswordField(controller: _passCtrl, focusNode: _passFocus, obscure: _obscurePass, hint: 'Enter your password', onToggle: () => setState(() => _obscurePass = !_obscurePass), onSubmit: _login),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            TextButton(
                                              onPressed: () {
                                                setState(() { _flowState = _FlowState.setPassword; _errorMsg = null; });
                                                WidgetsBinding.instance.addPostFrameCallback((_) => FocusScope.of(context).requestFocus(_newPassFocus));
                                              },
                                              style: TextButton.styleFrom(foregroundColor: _kPrimary, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                              child: Text('Forgot password?', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (_flowState == _FlowState.setPassword) ...[
                                      const SizedBox(height: 24),
                                      Text('New Password', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _kTextDark)),
                                      const SizedBox(height: 12),
                                      _buildPasswordField(controller: _newPassCtrl, focusNode: _newPassFocus, obscure: _obscureNew, hint: 'Create a strong password', onToggle: () => setState(() => _obscureNew = !_obscureNew), onSubmit: () => FocusScope.of(context).requestFocus(_confirmPassFocus)),
                                      const SizedBox(height: 20),
                                      Text('Confirm Password', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _kTextDark)),
                                      const SizedBox(height: 12),
                                      _buildPasswordField(controller: _confirmPassCtrl, focusNode: _confirmPassFocus, obscure: _obscureConfirm, hint: 'Re-enter your password', onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm), onSubmit: _setPasswordAndLogin),
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () {
                                            setState(() { _flowState = _FlowState.login; _errorMsg = null; });
                                            WidgetsBinding.instance.addPostFrameCallback((_) => FocusScope.of(context).requestFocus(_passFocus));
                                          },
                                          style: TextButton.styleFrom(foregroundColor: _kPrimary, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                          child: Text('Already have a password? Sign in', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800)),
                                        ),
                                      ),
                                    ],
                                    if (_errorMsg != null) ...[
                                      const SizedBox(height: 20),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFECACA))),
                                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          const Icon(Icons.error_rounded, color: Color(0xFFDC2626), size: 18),
                                          const SizedBox(width: 10),
                                          Expanded(child: Text(_errorMsg!, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFFB91C1C), height: 1.4))),
                                        ]),
                                      ),
                                    ],
                                    const SizedBox(height: 28),
                                    SizedBox(
                                      width: double.infinity, height: 56,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _primaryAction,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _kPrimary,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: _kPrimary.withValues(alpha: 0.6),
                                          elevation: 2,
                                          shadowColor: _kPrimary.withValues(alpha: 0.3),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                                Text(_buttonLabel, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                                                const SizedBox(width: 10),
                                                Icon(_flowState == _FlowState.login ? Icons.login_rounded : _flowState == _FlowState.setPassword ? Icons.verified_user_rounded : Icons.arrow_forward_rounded, size: 20),
                                              ]),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            //   const Icon(Icons.security_rounded, size: 14, color: Color(0xFF64748B)),
                            //   const SizedBox(width: 8),
                            //   // Text('Secure 256-bit Encrypted Portal', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextMuted)),
                            // ]),
                            const SizedBox(height: 16),
                            // Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [_buildBranchChip('Nagarabhavi'), _buildBranchChip('Basaveshwaranagar')]),
                          ],
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
    );
  }

  Widget _buildPatientBanner() {
    final fn   = _foundPatient?['first_name']?.toString() ?? '';
    final ln   = _foundPatient?['last_name']?.toString()  ?? '';
    final name = '$fn $ln'.trim();
    final phone = _phoneCtrl.text.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _kPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _kPrimary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.person_pin_rounded, color: _kPrimary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name.isNotEmpty ? name : 'Hospital Patient', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _kTextDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('+91 $phone • $_foundBranch', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool obscure,
    required String hint,
    required VoidCallback onToggle,
    required VoidCallback onSubmit,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _kTextDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
        prefixIcon: const Icon(Icons.lock_rounded, color: _kPrimary, size: 20),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF94A3B8), size: 20),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: _kSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _kPrimary, width: 1.8)),
      ),
      onSubmitted: (_) => onSubmit(),
      onChanged: (_) { if (_errorMsg != null) setState(() => _errorMsg = null); },
    );
  }

  Widget _buildBranchChip(String branch) {
    final active = _foundBranch == branch && _flowState != _FlowState.enterPhone;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? _kPrimary.withValues(alpha: 0.1) : const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? _kPrimary : _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_hospital_rounded, size: 12, color: active ? _kPrimary : _kTextMuted),
          const SizedBox(width: 6),
          Text(branch, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: active ? _kPrimary : _kTextMuted)),
        ],
      ),
    );
  }
}
