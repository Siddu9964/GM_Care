import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'patient_dashboard.dart';
import 'create_account_screen.dart';

const _kPrimary      = Color(0xFF14532D);
const _kPrimaryLight = Color(0xFF16A34A);
const _kBg           = Color(0xFFF8FAFC);
const _kSurface      = Color(0xFFFFFFFF);
const _kTextDark     = Color(0xFF0F172A);
const _kTextMuted    = Color(0xFF64748B);
const _kBorder       = Color(0xFFE2E8F0);

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
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    _fadeAnim  = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
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
        // Known patient found in hospital database.
        // By default, display the normal login form (Password field).
        // ONLY if the password is confirmed to NOT be set, show setPassword.
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
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, anim, secondaryAnimation, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child),
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
      case _FlowState.login:       return 'Log In';
      case _FlowState.setPassword: return 'Set Password & Sign In';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset > 0 ? bottomInset + 20 : 24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFBBF7D0))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: _kPrimaryLight, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('GM HOSPITALS · BANGALORE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: _kPrimary)),
                          ]),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: 84, height: 84,
                          decoration: BoxDecoration(color: _kSurface, shape: BoxShape.circle, border: Border.all(color: _kBorder, width: 1.5), boxShadow: [BoxShadow(color: _kPrimary.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))]),
                          child: ClipOval(child: Padding(padding: const EdgeInsets.all(12), child: Image.asset('assetes/gm_logoo.png', fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_hospital_rounded, color: _kPrimary, size: 42)))),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _flowState == _FlowState.enterPhone ? 'Your Health,\nJust a Tap Away.' : _flowState == _FlowState.login ? 'Welcome Back!' : 'Create Your Password',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: _kTextDark, height: 1.2, letterSpacing: -0.6),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _flowState == _FlowState.enterPhone
                              ? 'Access appointments, prescriptions, and health records securely with your mobile number.'
                              : _flowState == _FlowState.login
                                  ? 'Enter your password to access your health records.'
                                  : 'Your hospital record was found. Set a password to access GM Care.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: _kTextMuted, height: 1.5),
                        ),
                        const SizedBox(height: 32),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                            decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _kBorder), boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 24, offset: const Offset(0, 10))]),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_flowState != _FlowState.enterPhone) ...[_buildPatientBanner(), const SizedBox(height: 20)],
                                Text('Mobile Number', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark)),
                                const SizedBox(height: 4),
                                Text('Enter your 10-digit number to proceed', style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
                                const SizedBox(height: 12),
                                Container(
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: _flowState != _FlowState.enterPhone ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _phoneFocus.hasFocus ? _kPrimary : _kBorder, width: _phoneFocus.hasFocus ? 1.5 : 1.0),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: const BoxDecoration(border: Border(right: BorderSide(color: _kBorder))),
                                      child: Row(children: [
                                        const Text('🇮🇳', style: TextStyle(fontSize: 15)),
                                        const SizedBox(width: 4),
                                        Text('+91', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: _kTextDark)),
                                      ]),
                                    ),
                                    Expanded(child: TextField(
                                      controller: _phoneCtrl, focusNode: _phoneFocus,
                                      keyboardType: TextInputType.phone,
                                      enabled: _flowState == _FlowState.enterPhone,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: _flowState != _FlowState.enterPhone ? _kTextMuted : _kTextDark),
                                      decoration: InputDecoration(hintText: '98765 43210', hintStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0.5, color: const Color(0xFF94A3B8)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 10)),
                                      onChanged: (_) { if (_errorMsg != null) setState(() => _errorMsg = null); },
                                      onSubmitted: (_) => _onContinue(),
                                    )),
                                    if (_flowState == _FlowState.enterPhone && _phoneCtrl.text.isNotEmpty)
                                      IconButton(icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)), onPressed: () { _phoneCtrl.clear(); setState(() => _errorMsg = null); }),
                                    if (_flowState != _FlowState.enterPhone)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: TextButton(
                                          onPressed: _resetToPhoneEntry,
                                          style: TextButton.styleFrom(
                                            foregroundColor: _kPrimary,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text('Change', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                        ),
                                      ),
                                  ]),
                                ),
                                if (_flowState == _FlowState.login) ...[
                                  const SizedBox(height: 20),
                                  Text('Password', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark)),
                                  const SizedBox(height: 10),
                                  _buildPasswordField(controller: _passCtrl, focusNode: _passFocus, obscure: _obscurePass, hint: 'Enter your password', onToggle: () => setState(() => _obscurePass = !_obscurePass), onSubmit: _login),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _flowState = _FlowState.setPassword;
                                                _errorMsg = null;
                                              });
                                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                                FocusScope.of(context).requestFocus(_newPassFocus);
                                              });
                                            },
                                            style: TextButton.styleFrom(
                                              foregroundColor: _kTextMuted,
                                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: Text(
                                              'First time? Set password',
                                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _flowState = _FlowState.setPassword;
                                              _errorMsg = null;
                                            });
                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                              FocusScope.of(context).requestFocus(_newPassFocus);
                                            });
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor: _kPrimary,
                                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text('Forgot password?', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (_flowState == _FlowState.setPassword) ...[
                                  const SizedBox(height: 20),
                                  Text('New Password', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark)),
                                  const SizedBox(height: 10),
                                  _buildPasswordField(controller: _newPassCtrl, focusNode: _newPassFocus, obscure: _obscureNew, hint: 'Create a strong password', onToggle: () => setState(() => _obscureNew = !_obscureNew), onSubmit: () => FocusScope.of(context).requestFocus(_confirmPassFocus)),
                                  const SizedBox(height: 16),
                                  Text('Confirm Password', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark)),
                                  const SizedBox(height: 10),
                                  _buildPasswordField(controller: _confirmPassCtrl, focusNode: _confirmPassFocus, obscure: _obscureConfirm, hint: 'Re-enter your password', onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm), onSubmit: _setPasswordAndLogin),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _flowState = _FlowState.login;
                                          _errorMsg = null;
                                        });
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          FocusScope.of(context).requestFocus(_passFocus);
                                        });
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: _kPrimary,
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text('Already have a password? Sign in', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ],
                                if (_errorMsg != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
                                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 17),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(_errorMsg!, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500, color: const Color(0xFFB91C1C), height: 1.3))),
                                    ]),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity, height: 52,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _primaryAction,
                                    style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white, disabledBackgroundColor: _kPrimary.withValues(alpha: 0.6), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                    child: _isLoading
                                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                            Text(_buttonLabel, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                                            const SizedBox(width: 8),
                                            Icon(_flowState == _FlowState.login ? Icons.login_rounded : _flowState == _FlowState.setPassword ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 18),
                                          ]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text('256-bit Encrypted · Official GM Care Portal', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextMuted)),
                        ]),
                        const SizedBox(height: 12),
                        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [_buildBranchChip('Nagarabhavi'), _buildBranchChip('Basaveshwaranagar')]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientBanner() {
    final fn   = _foundPatient?['first_name']?.toString() ?? '';
    final ln   = _foundPatient?['last_name']?.toString()  ?? '';
    final name = '$fn $ln'.trim();
    final phone = _phoneCtrl.text.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: _kPrimary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.isNotEmpty ? name : 'GM Hospital Patient',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _kTextDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      '+91 $phone',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kTextMuted,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _foundBranch,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _kPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: _kPrimary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
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
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focusNode.hasFocus ? _kPrimary : _kBorder,
          width: focusNode.hasFocus ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscure,
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _kTextDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: _kPrimary, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
              onPressed: onToggle,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          ),
          onSubmitted: (_) => onSubmit(),
          onChanged: (_) {
            if (_errorMsg != null) setState(() => _errorMsg = null);
          },
        ),
      ),
    );
  }

  Widget _buildBranchChip(String branch) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Text('🏥 $branch', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
    );
  }
}
