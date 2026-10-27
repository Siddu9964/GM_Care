import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'first_time_mobile_screen.dart';

const _kPrimary      = Color(0xFF1F6B4A);
const _kPrimaryLight = Color(0xFF26875B);
const _kBg           = Color(0xFFF3EFE6);
const _kSurface      = Color(0xFFFFFFFF);
const _kTextDark     = Color(0xFF143B2A);
const _kTextMuted    = Color(0xFF5A6E64);
const _kBorder       = Color(0xFFDED8CB);

class CreateAccountScreen extends StatefulWidget {
  final String branchName;
  final String? initialPhone;

  const CreateAccountScreen({
    super.key,
    this.branchName = 'Nagarabhavi',
    this.initialPhone,
  });

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> with SingleTickerProviderStateMixin {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _ageCtrl       = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  final _firstNameFocus = FocusNode();
  final _lastNameFocus  = FocusNode();
  final _emailFocus     = FocusNode();
  final _ageFocus       = FocusNode();
  final _passFocus      = FocusNode();
  final _confirmFocus   = FocusNode();

  String _selectedGender = 'Male';
  String _selectedBranch = 'Nagarabhavi';
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;
  String? _errorMsg;

  final List<String> _genders  = ['Male', 'Female', 'Other'];
  final List<String> _branches = ['Nagarabhavi', 'Basaveshwaranagar'];

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _selectedBranch = widget.branchName;
    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      _phoneCtrl.text = widget.initialPhone!;
    }

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: 0.0,
    );
    _fadeAnim  = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();

    // Listeners for focus effects
    _firstNameFocus.addListener(() => setState(() {}));
    _lastNameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _ageFocus.addListener(() => setState(() {}));
    _passFocus.addListener(() => setState(() {}));
    _confirmFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose(); _firstNameFocus.dispose();
    _lastNameCtrl.dispose();  _lastNameFocus.dispose();
    _emailCtrl.dispose();     _emailFocus.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();       _ageFocus.dispose();
    _passCtrl.dispose();      _passFocus.dispose();
    _confirmCtrl.dispose();   _confirmFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final cleanPhone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (_firstNameCtrl.text.trim().isEmpty) return 'Please enter your First Name.';
    if (cleanPhone.length != 10) return 'Valid 10-digit phone number is required.';
    if (_passCtrl.text.isEmpty) return 'Please create a password.';
    if (_passCtrl.text.length < 6) return 'Password must be at least 6 characters.';
    if (_passCtrl.text != _confirmCtrl.text) return 'Passwords do not match.';
    return null;
  }

  Future<void> _register() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    final error = _validate();
    if (error != null) {
      setState(() => _errorMsg = error);
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });
    final cleanPhone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');

    try {
      final regRes = await http.post(
        Uri.parse(ApiConfig.patients),
        headers: { 'Content-Type': 'application/json', 'X-Hospital-Branch': _selectedBranch },
        body: jsonEncode({
          'title':      _selectedGender == 'Male' ? 'Mr' : (_selectedGender == 'Female' ? 'Ms' : 'Other'),
          'first_name': _firstNameCtrl.text.trim(),
          'last_name':  _lastNameCtrl.text.trim(),
          'sex':        _selectedGender,
          'age':        int.tryParse(_ageCtrl.text.trim()) ?? 0,
          'phone':      cleanPhone,
          'email':      _emailCtrl.text.trim(),
          'password':   _passCtrl.text,
        }),
      ).timeout(const Duration(seconds: 12));

      final regData = jsonDecode(regRes.body) as Map<String, dynamic>;

      if (regRes.statusCode == 400 || regRes.statusCode == 409) {
        final msg = (regData['message'] ?? '').toString().toLowerCase();
        if (msg.contains('phone') || msg.contains('mobile') || msg.contains('exists')) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showDuplicateDialog(cleanPhone);
          return;
        }
        setState(() { _isLoading = false; _errorMsg = regData['message']?.toString() ?? 'Registration failed.'; });
        return;
      }

      if (regRes.statusCode != 200 && regRes.statusCode != 201) {
        setState(() { _isLoading = false; _errorMsg = regData['message']?.toString() ?? 'Registration could not be completed.'; });
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account created! Welcome to GM Care 🎉', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: _kPrimary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16)
        ),
      );
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => FirstTimeMobileScreen(initialPhone: cleanPhone, initialBranch: _selectedBranch)), (route) => false);
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _errorMsg = 'Unable to connect to hospital server.'; });
    }
  }

  void _showDuplicateDialog(String phone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _kPrimary.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.info_rounded, color: _kPrimary, size: 24)),
          const SizedBox(width: 14),
          Expanded(child: Text('Already Registered', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: _kTextDark))),
        ]),
        content: Text('This mobile number is already registered. Would you like to sign in instead?', style: GoogleFonts.inter(fontSize: 14, color: _kTextMuted, height: 1.5)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: _kTextMuted, fontWeight: FontWeight.w700))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => FirstTimeMobileScreen(initialPhone: phone, initialBranch: _selectedBranch)), (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: Text('Log In', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _kSurface, shape: BoxShape.circle, border: Border.all(color: _kBorder)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _kTextDark, size: 16),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned(top: -40, right: -40, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: _kPrimary.withValues(alpha: 0.04)))),
          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, bottomInset > 0 ? bottomInset + 20 : 32),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('New Patient Profile', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: _kTextDark, letterSpacing: -0.8)),
                            const SizedBox(height: 8),
                            Text('Join GM Care to manage your health records, appointments, and bills digitally.', style: GoogleFonts.inter(fontSize: 14.5, color: _kTextMuted, height: 1.5)),
                            const SizedBox(height: 28),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _kBorder),
                              ),
                              child: Row(children: [
                                const Icon(Icons.verified_user_rounded, color: _kPrimary, size: 18),
                                const SizedBox(width: 12),
                                Text('+91 ${_phoneCtrl.text}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _kTextDark, letterSpacing: 1.0)),
                                const Spacer(),
                                Text('Pre-filled', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _kPrimary, letterSpacing: 0.5)),
                              ]),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: _kSurface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: _kBorder),
                                boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 8))],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('Personal Details'),
                                  const SizedBox(height: 16),
                                  _buildTextField(_firstNameCtrl, _firstNameFocus, 'First Name *', Icons.person_rounded),
                                  const SizedBox(height: 16),
                                  _buildTextField(_lastNameCtrl, _lastNameFocus, 'Last Name', Icons.person_outline_rounded),
                                  const SizedBox(height: 20),
                                  Text('Gender', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _kTextMuted)),
                                  const SizedBox(height: 10),
                                  Row(children: _genders.map((g) => Expanded(child: _buildChoiceChip(g, _selectedGender == g, () => setState(() => _selectedGender = g)))).toList()),
                                  const SizedBox(height: 16),
                                  _buildTextField(_ageCtrl, _ageFocus, 'Age', Icons.cake_rounded, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)]),
                                  const SizedBox(height: 32),
                                  _buildSectionTitle('Hospital Preference'),
                                  const SizedBox(height: 12),
                                  Row(children: _branches.map((b) => Expanded(child: _buildChoiceChip(b, _selectedBranch == b, () => setState(() => _selectedBranch = b), isBranch: true))).toList()),
                                  const SizedBox(height: 32),
                                  _buildSectionTitle('Security'),
                                  const SizedBox(height: 16),
                                  _buildTextField(_emailCtrl, _emailFocus, 'Email (Optional)', Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress),
                                  const SizedBox(height: 16),
                                  _buildPasswordField(_passCtrl, _passFocus, 'New Password *', _obscurePass, () => setState(() => _obscurePass = !_obscurePass)),
                                  const SizedBox(height: 16),
                                  _buildPasswordField(_confirmCtrl, _confirmFocus, 'Confirm Password *', _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
                                  if (_errorMsg != null) ...[
                                    const SizedBox(height: 24),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFECACA))),
                                      child: Row(children: [const Icon(Icons.error_rounded, color: Color(0xFFDC2626), size: 18), const SizedBox(width: 10), Expanded(child: Text(_errorMsg!, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFB91C1C))))]),
                                    ),
                                  ],
                                  const SizedBox(height: 32),
                                  SizedBox(
                                    width: double.infinity, height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _register,
                                      style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white, elevation: 2, shadowColor: _kPrimary.withValues(alpha: 0.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                      child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : Text('Complete Registration', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: TextButton.styleFrom(foregroundColor: _kTextMuted),
                                child: Text('Back to mobile entry', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
                              ),
                            ),
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

  Widget _buildSectionTitle(String title) {
    return Row(children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: _kTextDark, letterSpacing: -0.2)),
    ]);
  }

  Widget _buildChoiceChip(String label, bool selected, VoidCallback onTap, {bool isBranch = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _kPrimary : _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? _kPrimary : _kBorder),
          boxShadow: selected ? [BoxShadow(color: _kPrimary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: isBranch ? 12 : 13.5, color: selected ? Colors.white : _kTextDark)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, FocusNode focus, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, List<TextInputFormatter>? inputFormatters}) {
    return TextField(
      controller: ctrl,
      focusNode: focus,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _kTextDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 14, color: focus.hasFocus ? _kPrimary : const Color(0xFF94A3B8), fontWeight: focus.hasFocus ? FontWeight.w700 : FontWeight.w500),
        prefixIcon: Icon(icon, color: focus.hasFocus ? _kPrimary : const Color(0xFF94A3B8), size: 20),
        filled: true,
        fillColor: _kSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _kPrimary, width: 1.8)),
      ),
      onChanged: (_) { if (_errorMsg != null) setState(() => _errorMsg = null); },
    );
  }

  Widget _buildPasswordField(TextEditingController ctrl, FocusNode focus, String label, bool obscure, VoidCallback onToggle) {
    return TextField(
      controller: ctrl,
      focusNode: focus,
      obscureText: obscure,
      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _kTextDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 14, color: focus.hasFocus ? _kPrimary : const Color(0xFF94A3B8), fontWeight: focus.hasFocus ? FontWeight.w700 : FontWeight.w500),
        prefixIcon: Icon(Icons.lock_rounded, color: focus.hasFocus ? _kPrimary : const Color(0xFF94A3B8), size: 20),
        suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF94A3B8), size: 20), onPressed: onToggle),
        filled: true,
        fillColor: _kSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _kPrimary, width: 1.8)),
      ),
      onChanged: (_) { if (_errorMsg != null) setState(() => _errorMsg = null); },
    );
  }
}
