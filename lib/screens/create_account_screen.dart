import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'first_time_mobile_screen.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const _kPrimary  = Color(0xFF14532D); // Deep Medical Emerald
const _kBg       = Color(0xFFF8FAFC);
const _kSurface      = Color(0xFFFFFFFF);
const _kTextDark     = Color(0xFF0F172A);
const _kTextMuted    = Color(0xFF64748B);
const _kBorder       = Color(0xFFE2E8F0);

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

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _ageCtrl       = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  String _selectedGender = 'Male';
  String _selectedBranch = 'Nagarabhavi';
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;
  String? _errorMsg;

  final List<String> _genders  = ['Male', 'Female', 'Other'];
  final List<String> _branches = ['Nagarabhavi', 'Basaveshwaranagar'];

  @override
  void initState() {
    super.initState();
    _selectedBranch = widget.branchName;
    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      _phoneCtrl.text = widget.initialPhone!;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
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
    if (_isLoading) return; // Prevent multi-taps
    FocusScope.of(context).unfocus();

    final error = _validate();
    if (error != null) {
      setState(() => _errorMsg = error);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final cleanPhone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');

    try {
      // Step 1: Create patient profile in HMS backend
      final regRes = await http.post(
        Uri.parse(ApiConfig.patients),
        headers: {
          'Content-Type': 'application/json',
          'X-Hospital-Branch': _selectedBranch,
        },
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

      // Duplicate phone check
      if (regRes.statusCode == 400 || regRes.statusCode == 409) {
        final msg = (regData['message'] ?? '').toString().toLowerCase();
        if (msg.contains('phone') || msg.contains('mobile') || msg.contains('exists')) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showDuplicateDialog(cleanPhone);
          return;
        }
        setState(() {
          _isLoading = false;
          _errorMsg  = regData['message']?.toString() ?? 'Registration failed. Please try again.';
        });
        return;
      }

      if (regRes.statusCode != 200 && regRes.statusCode != 201) {
        setState(() {
          _isLoading = false;
          _errorMsg  = regData['message']?.toString() ?? 'Registration could not be completed.';
        });
        return;
      }

      // Registration successful — redirect to login screen
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account created! Please sign in with your new password.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: _kPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => FirstTimeMobileScreen(
            initialPhone: cleanPhone,
            initialBranch: _selectedBranch,
          ),
        ),
        (route) => false,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg  = 'Unable to connect to hospital server. Please check your internet connection.';
        });
      }
    }
  }

  void _showDuplicateDialog(String phone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline_rounded, color: _kPrimary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Already Registered',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17, color: _kTextDark),
              ),
            ),
          ],
        ),
        content: Text(
          'This mobile number is already registered in our hospital records. Please sign in with your password.',
          style: GoogleFonts.inter(fontSize: 13.5, color: _kTextMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: _kTextMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => FirstTimeMobileScreen(
                    initialPhone: phone,
                    initialBranch: _selectedBranch,
                  ),
                ),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('Log In', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kTextDark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 8, 24, bottomInset > 0 ? bottomInset + 20 : 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    Text(
                      'New Patient Profile',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _kTextDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create your GM Care health account in a few simple steps.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _kTextMuted,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Verified Mobile Display ─────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_android_rounded, color: _kTextMuted, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            '+91 ${_phoneCtrl.text}',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _kTextDark,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 12, color: _kPrimary),
                                const SizedBox(width: 4),
                                Text(
                                  'Pre-filled',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _kPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Personal Details ────────────────────────────────────
                    Text(
                      'Personal Details',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(_firstNameCtrl, 'First Name *', Icons.person_outline_rounded),
                    const SizedBox(height: 12),
                    _buildTextField(_lastNameCtrl, 'Last Name', Icons.person_outline_rounded),
                    const SizedBox(height: 16),

                    // ── Gender Chips ────────────────────────────────────────
                    Text(
                      'Gender',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kTextMuted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: _genders.map((g) {
                        final selected = _selectedGender == g;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedGender = g),
                            child: Container(
                              margin: EdgeInsets.only(right: g != _genders.last ? 8 : 0),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selected ? _kPrimary : _kSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected ? _kPrimary : _kBorder,
                                ),
                              ),
                              child: Text(
                                g,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: selected ? Colors.white : _kTextDark,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),
                    _buildTextField(
                      _ageCtrl,
                      'Age',
                      Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                    ),

                    const SizedBox(height: 24),

                    // ── Hospital Branch ─────────────────────────────────────
                    Text(
                      'Preferred Hospital Branch',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: _branches.map((b) {
                        final selected = _selectedBranch == b;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedBranch = b),
                            child: Container(
                              margin: EdgeInsets.only(right: b != _branches.last ? 8 : 0),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: selected ? _kPrimary : _kSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected ? _kPrimary : _kBorder,
                                ),
                              ),
                              child: Text(
                                b,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: selected ? Colors.white : _kTextDark,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // ── Email (Optional) ────────────────────────────────────
                    _buildTextField(_emailCtrl, 'Email (Optional)', Icons.email_outlined, keyboardType: TextInputType.emailAddress),

                    const SizedBox(height: 24),

                    // ── Password ────────────────────────────────────────────
                    Text(
                      'Create App Password',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPasswordField(
                      controller: _passCtrl,
                      label: 'Password * (min 6 characters)',
                      obscure: _obscurePass,
                      onToggle: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                    const SizedBox(height: 12),
                    _buildPasswordField(
                      controller: _confirmCtrl,
                      label: 'Confirm Password *',
                      obscure: _obscureConfirm,
                      onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),

                    // ── Error Banner ────────────────────────────────────────
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFDC2626),
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMsg!,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFB91C1C),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── Submit Button ───────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _kPrimary.withValues(alpha: 0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : Text(
                                'Complete Registration & Continue',
                                style: GoogleFonts.inter(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Back to mobile number entry',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _kTextMuted,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: _kTextDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF94A3B8)),
          prefixIcon: Icon(icon, color: _kPrimary, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onChanged: (_) {
          if (_errorMsg != null) setState(() => _errorMsg = null);
        },
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: _kTextDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: _kPrimary, size: 18),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: const Color(0xFF94A3B8),
              size: 18,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onChanged: (_) {
          if (_errorMsg != null) setState(() => _errorMsg = null);
        },
      ),
    );
  }
}
