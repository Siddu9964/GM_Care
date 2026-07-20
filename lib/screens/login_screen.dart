import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'patient_dashboard.dart';
import 'create_account_screen.dart';

const Color primaryGreen = Color(0xFF1F6B4A);
const Color primaryDark = Color(0xFF053F2C);
const Color backgroundCream = Color(0xFFF3EFE6);

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late Timer _carouselTimer;
  int _currentChipIndex = 0;

  StateSetter? _dialogSetState;

  void _updateState(VoidCallback fn) {
    setState(fn);
    _dialogSetState?.call(() {});
  }

  // Login Form State
  final TextEditingController _loginIdentifierController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  // Forgot Password Form State
  final TextEditingController _forgotIdentifierController = TextEditingController();
  final TextEditingController _forgotNewPasswordController = TextEditingController();
  final TextEditingController _forgotConfirmPasswordController = TextEditingController();

  // Registration Form State
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _aadharController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedTitle = 'Mr';
  String _selectedGender = 'Male';
  bool _isLoading = false;
  bool _obscurePassword = true;
  int _passwordStrength = 0;
  String _selectedBranch = 'Nagarabhavi';

  // ── Biometric ─────────────────────────────────────────────────────────────
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_checkPasswordStrength);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentChipIndex = (_currentChipIndex + 1) % 3;
        });
      }
    });

    _animationController.forward();
    _loadBioState(); // ← load biometric preference on startup
  }

  Future<void> _loadBioState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _bioEnabled = prefs.getBool('bio_enabled') ?? false;
      });
    }
  }

  void _checkPasswordStrength() {
    String p = _passwordController.text;
    int strength = 0;
    if (p.length >= 8) strength++;
    if (p.contains(RegExp(r'[A-Z]'))) strength++;
    if (p.contains(RegExp(r'[0-9]'))) strength++;
    if (p.contains(RegExp(r'[!@#\$&*~]'))) strength++; 
    
    if (strength > 3) strength = 3;
    if (_passwordStrength != strength) {
      _updateState(() { _passwordStrength = strength; });
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_checkPasswordStrength);
    _carouselTimer.cancel();
    _animationController.dispose();
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _forgotIdentifierController.dispose();
    _forgotNewPasswordController.dispose();
    _forgotConfirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _aadharController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showPopup(String title, String message, bool isSuccess, {VoidCallback? onSuccess}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: isSuccess ? primaryGreen.withOpacity(0.2) : Colors.red.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSuccess ? primaryGreen.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                    color: isSuccess ? primaryGreen : Colors.red,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 24, color: primaryDark, height: 1.2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (isSuccess && onSuccess != null) {
                        onSuccess();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSuccess ? primaryDark : Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text('Continue', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loginUser() async {
    if (_loginIdentifierController.text.isEmpty || _loginPasswordController.text.isEmpty) {
      _showPopup('Missing Fields', 'Please enter your credentials to login.', false);
      return;
    }

    _updateState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {
          'Content-Type': 'application/json',
          'X-Hospital-Branch': _selectedBranch,
        },
        body: jsonEncode({
          'username': _loginIdentifierController.text,
          'password': _loginPasswordController.text,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        final userData = responseData['data'] ?? responseData['user'] ?? {};
        final name = userData['first_name'] ?? userData['name'] ?? userData['username'] ?? _loginIdentifierController.text;
        final loc = userData['city'] ?? userData['location'] ?? _selectedBranch;
        final age = userData['age']?.toString() ?? '--';
        final sex = userData['sex'] ?? 'Unknown';
        String rawCookie = response.headers['set-cookie'] ?? '';
        if (rawCookie.isNotEmpty) {
          rawCookie = rawCookie.split(';')[0]; // Extract just the key=value part
        }

        if (mounted) {
          _showPopup('Login Successful!', 'Welcome back.', true, onSuccess: () {
            Navigator.of(context).pop(); // Close dialog
            _navigateToHome(userName: name, location: loc, age: age, sex: sex, cookie: rawCookie);
          });
        }
      } else {
        if (mounted) {
          _showPopup('Login Failed', responseData['message'] ?? 'Could not log in.', false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showPopup('Error', 'An unexpected error occurred: $e', false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_forgotIdentifierController.text.isEmpty || _forgotNewPasswordController.text.isEmpty || _forgotConfirmPasswordController.text.isEmpty) {
      _showPopup('Missing Fields', 'Please fill in all fields.', false);
      return;
    }

    if (_forgotNewPasswordController.text != _forgotConfirmPasswordController.text) {
      _showPopup('Mismatch', 'New password and confirm password do not match.', false);
      return;
    }

    _updateState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.resetPassword),
        headers: {
          'Content-Type': 'application/json',
          'X-Hospital-Branch': _selectedBranch,
        },
        body: jsonEncode({
          'identifier': _forgotIdentifierController.text,
          'new_password': _forgotNewPasswordController.text,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        if (mounted) {
          Navigator.of(context).pop(); // close the forgot password dialog
          _showPopup('Password Reset', 'Your password has been reset successfully. Please login with your new password.', true);
        }
      } else {
        if (mounted) {
          _showPopup('Reset Failed', responseData['message'] ?? 'Could not reset password.', false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showPopup('Error', 'An unexpected error occurred: $e', false);
      }
    } finally {
      if (mounted) {
        _updateState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    _forgotIdentifierController.clear();
    _forgotNewPasswordController.clear();
    _forgotConfirmPasswordController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            _dialogSetState = dialogSetState;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('Reset Password', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: primaryDark)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(label: 'Email / Phone / Name', icon: Icons.person_outline, controller: _forgotIdentifierController),
                  const SizedBox(height: 12),
                  _buildTextField(label: 'New Password', icon: Icons.lock_outline, isPasswordField: true, isObscure: _obscurePassword, onSuffixTap: () { _updateState(() { _obscurePassword = !_obscurePassword; }); }, controller: _forgotNewPasswordController),
                  const SizedBox(height: 12),
                  _buildTextField(label: 'Confirm Password', icon: Icons.lock_outline, isPasswordField: true, isObscure: _obscurePassword, onSuffixTap: () { _updateState(() { _obscurePassword = !_obscurePassword; }); }, controller: _forgotConfirmPasswordController),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: _resetPassword,
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Reset', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _registerUser() async {
    if (_firstNameController.text.isEmpty || _mobileController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
      return;
    }
    _updateState(() { _isLoading = true; });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.patients),
        headers: {
          'Content-Type': 'application/json',
          'X-Hospital-Branch': _selectedBranch,
        },
        body: jsonEncode({
          'title': _selectedTitle,
          'first_name': _firstNameController.text,
          'last_name': _lastNameController.text,
          'sex': _selectedGender,
          'aadhar': _aadharController.text,
          'phone': _mobileController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true || data['message'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account Created Successfully!')));
          if (mounted) {
            Navigator.of(context).pop(); // Close dialog
            _navigateToHome(
              userName: _firstNameController.text, 
              location: _selectedBranch,
              sex: _selectedGender,
            ); // Then navigate
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Registration failed')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Server Error: ${response.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e')));
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _navigateToHome({String? userName, String? location, String? age, String? sex, String cookie = ''}) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => PatientDashboard(
          userName: userName ?? "Jane",
          location: location ?? "New York, NY",
          age: age ?? "--",
          sex: sex ?? "Unknown",
          cookie: cookie,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // ── Biometric Login ────────────────────────────────────────────────────────
  Future<void> _loginWithBiometric(BuildContext dialogCtx) async {
    // 1. Check device support
    final bool canCheck =
        await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    if (!canCheck) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Biometric not available on this device'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // 2. Load saved credentials
    final prefs = await SharedPreferences.getInstance();
    final savedUser   = prefs.getString('bio_username');
    final savedLoc    = prefs.getString('bio_location');
    final savedAge    = prefs.getString('bio_age')    ?? '--';
    final savedSex    = prefs.getString('bio_sex')    ?? 'Unknown';
    final savedCookie = prefs.getString('bio_cookie') ?? '';

    if (savedUser == null || savedLoc == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No saved credentials. Please login with password first.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    // 3. Authenticate with biometric
    bool authenticated = false;
    try {
      authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint to login to GM Care',
        biometricOnly: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Biometric error: $e'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // 4. Navigate on success
    if (authenticated && mounted) {
      Navigator.of(dialogCtx).pop(); // close branch dialog
      _navigateToHome(
        userName: savedUser,
        location: savedLoc,
        age:      savedAge,
        sex:      savedSex,
        cookie:   savedCookie,
      );
    }
  }

  void _showAuthDialog({required bool isLogin}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            _dialogSetState = dialogSetState;
            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
              width: MediaQuery.of(context).size.width > 600 ? 420 : MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F9F4),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: primaryGreen.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 20)),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLogin ? 'Welcome\nBack' : 'Create\nAccount',
                          style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: primaryDark, height: 1.1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isLogin ? 'Please login to continue your restorative healthcare journey.' : 'Join us to access premium healthcare services.',
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    isLogin ? _buildLoginForm() : _buildRegisterForm(),
                  ],
                ),
              ),
            ),
          ),
        );
      });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildHeroSection(context),
                        const SizedBox(height: 32),
                        _buildSectionTitle(Icons.location_on, 'Main Bengaluru Branches'),
                        const SizedBox(height: 12),
                        _buildBranches(),
                        const SizedBox(height: 24),
                        _buildSectionTitle(Icons.medical_services_outlined, 'Key Medical Specialities'),
                        const SizedBox(height: 12),
                        _buildSpecialties(),
                        const SizedBox(height: 24),
                        _buildSectionTitle(Icons.health_and_safety_outlined, 'Insurance & Facilities'),
                        const SizedBox(height: 12),
                        _buildInsurance(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TOP HEADER ---
  Widget _buildHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assetes/gm_logoo.png', height: 48),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GM Hospitals',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
                ),
                Text(
                  'Care. Compassion. Commitment.',
                  style: GoogleFonts.inter(fontSize: 10, color: primaryGreen.withOpacity(0.7), letterSpacing: 0.5),
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: primaryGreen.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.phone_in_talk, color: primaryGreen, size: 16),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('24/7 Helpline', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[600])),
                  Text('+91 99000 13735', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: primaryGreen)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- HERO SECTION ---
  Widget _buildHeroSection(BuildContext context) {
    Widget textContent = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Trusted Care Since Day One',
            style: GoogleFonts.inter(color: primaryGreen, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
        const SizedBox(height: 20),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.1),
            children: const [
              TextSpan(text: 'Healthcare\nYou Can '),
              TextSpan(text: 'Trust', style: TextStyle(color: primaryGreen)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Prominent multi-specialty healthcare centers in Karnataka offering 24/7 emergency care, advanced diagnostics, and surgical treatments.',
          style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[700], height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child));
            },
            child: _currentChipIndex == 0
                ? Container(key: const ValueKey(0), child: _buildStatChip(Icons.people_alt_outlined, '50K+', 'Happy Patients'))
                : _currentChipIndex == 1
                    ? Container(key: const ValueKey(1), child: _buildStatChip(Icons.medical_services_outlined, '24/7', 'Emergency Care'))
                    : Container(key: const ValueKey(2), child: _buildStatChip(Icons.star_border_rounded, '25+', 'Specialities')),
          ),
        ),
      ],
    );

    Widget imageContent = Container(
      height: 350,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: primaryGreen.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 20)),
        ],
        image: const DecorationImage(
          image: AssetImage('assetes/GM_login.jpg'),
          fit: BoxFit.cover,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 5, child: textContent),
              const SizedBox(width: 48),
              Expanded(flex: 5, child: imageContent),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              textContent,
              const SizedBox(height: 32),
              imageContent,
            ],
          );
        }
      },
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: primaryGreen.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primaryGreen, size: 28),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- INFO SECTIONS ---
  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: primaryGreen, size: 24),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildBranches() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 600;
        if (isWide) {
          return Row(
            children: [
              Expanded(child: _buildBranchCard('Nagarabhavi', '611 & 612, Nagarabhavi Main Road, 2nd Stage, Bengaluru – 560072', '+91 99000 13735', 'assetes/GM_login.jpg')),
              const SizedBox(width: 24),
              Expanded(child: _buildBranchCard('Basaveshwaranagar', '#335, 8th Main, 3rd Stage, 4th Block, Bengaluru – 560079', '+91 99000 03527', 'assetes/GM_login.jpg')),
            ],
          );
        } else {
          return Column(
            children: [
              _buildBranchCard('Nagarabhavi', '611 & 612, Nagarabhavi Main Road, 2nd Stage, Bengaluru – 560072', '+91 99000 13735', 'assetes/GM_login.jpg'),
              const SizedBox(height: 16),
              _buildBranchCard('Basaveshwaranagar', '#335, 8th Main, 3rd Stage, 4th Block, Bengaluru – 560079', '+91 99000 03527', 'assetes/GM_login.jpg'),
            ],
          );
        }
      },
    );
  }

  Widget _buildBranchCard(String title, String address, String phone, String imagePath) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBranchCard(
          title: title,
          address: address,
          phone: phone,
          imagePath: imagePath,
          onTap: () => _showBranchOptions(title),
        ),
        const PulsingLoginText(),
      ],
    );
  }

  void _showBranchOptions(String branchName) {
    setState(() {
      _selectedBranch = branchName;
    });
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext dialogCtx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width > 600 ? 420 : MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hospital icon badge
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_hospital_rounded, color: primaryGreen, size: 32),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Welcome to\n$branchName',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'How would you like to continue?',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                   Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            _showAuthDialog(isLogin: true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text('LOGIN', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateAccountScreen(branchName: _selectedBranch),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryGreen,
                            side: const BorderSide(color: primaryGreen, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text('REGISTER', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  // ── Biometric Login button (shown only when enabled) ──────────
                  _buildBiometricButton(dialogCtx),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Biometric Button Widget ─────────────────────────────────────────────────
  Widget _buildBiometricButton(BuildContext dialogCtx) {
    if (!_bioEnabled) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR',
                style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _loginWithBiometric(dialogCtx),
            icon: const Icon(Icons.fingerprint_rounded, size: 22),
            label: Text(
              'Login with Biometric',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF053F2C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialties() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildSpecialtyCard(Icons.favorite_border, 'Emergency & Critical Care', '24/7 trauma & cardiac life support, ICU.', isWide: true)),
                Expanded(child: _buildSpecialtyCard(Icons.child_care, 'Maternity & Gynecology', 'High-risk pregnancy, deliveries, infertility.', isWide: true)),
                Expanded(child: _buildSpecialtyCard(Icons.local_hospital_outlined, 'Surgical Specialities', 'Laparoscopy, orthopedics, urology, oncology.', isWide: true)),
                Expanded(child: _buildSpecialtyCard(Icons.biotech, 'Diagnostics Services', 'Digital X-ray, Ultrasound, ECG, Endoscopy.', isWide: true)),
              ],
            ),
          );
        } else {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildSpecialtyCard(Icons.favorite_border, 'Emergency\nCare', '24/7 trauma & ICU.', isWide: false)),
                  Expanded(child: _buildSpecialtyCard(Icons.child_care, 'Maternity &\nGynecology', 'High-risk pregnancy.', isWide: false)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildSpecialtyCard(Icons.local_hospital_outlined, 'Surgical\nSpecialities', 'Laparoscopy, oncology.', isWide: false)),
                  Expanded(child: _buildSpecialtyCard(Icons.biotech, 'Diagnostics\nServices', 'X-ray, Ultrasound, ECG.', isWide: false)),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildSpecialtyCard(IconData icon, String title, String desc, {required bool isWide}) {
    return Container(
      margin: EdgeInsets.only(right: isWide ? 12 : 8, bottom: isWide ? 0 : 8, left: isWide ? 0 : 4),
      padding: EdgeInsets.all(isWide ? 12 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryGreen.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: primaryGreen.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: primaryGreen, size: isWide ? 24 : 20),
              SizedBox(width: isWide ? 8 : 4),
              Expanded(
                child: Text(title, style: GoogleFonts.inter(fontSize: isWide ? 12 : 11, fontWeight: FontWeight.bold, color: primaryGreen, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          SizedBox(height: isWide ? 8 : 4),
          Text(desc, style: GoogleFonts.inter(fontSize: isWide ? 10 : 9, color: Colors.grey[600], height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildInsurance() {
    return LayoutBuilder(builder: (context, constraints) {
      bool isWide = constraints.maxWidth > 600;
      if (isWide) {
        return Row(
          children: [
            Expanded(child: _buildInsuranceItem(Icons.verified_user_outlined, 'Cashless Hospitalization', 'Accepted by major health insurances and TPAs.')),
            const SizedBox(width: 24),
            Expanded(child: _buildInsuranceItem(Icons.calendar_month_outlined, 'Consultations', 'Walk-ins, booked appointments, and video consultations.')),
          ],
        );
      } else {
        return Column(
          children: [
            _buildInsuranceItem(Icons.verified_user_outlined, 'Cashless Hospitalization', 'Accepted by major health insurances and TPAs.'),
            const SizedBox(height: 16),
            _buildInsuranceItem(Icons.calendar_month_outlined, 'Consultations', 'Walk-ins, booked appointments, and video consultations.'),
          ],
        );
      }
    });
  }

  Widget _buildInsuranceItem(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryGreen.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: backgroundCream, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: primaryGreen),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen)),
                const SizedBox(height: 4),
                Text(desc, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ACTION BUTTONS SECTION REMOVED

  // --- FORM FIELDS ---
  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          label: 'Email, Phone, or ID',
          icon: Icons.person,
          controller: _loginIdentifierController,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Password',
          icon: Icons.lock_outline,
          isPasswordField: true,
          isObscure: _obscurePassword,
          controller: _loginPasswordController,
          onSuffixTap: () { _updateState(() { _obscurePassword = !_obscurePassword; }); },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _showForgotPasswordDialog,
            child: Text('Forgot Password?', style: GoogleFonts.inter(color: primaryGreen, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        _isLoading ? const Center(child: CircularProgressIndicator()) : _buildSubmitButton('Secure Login', _loginUser),
        const SizedBox(height: 24),
        _buildSocialLogin(),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: 'Personal Information',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(flex: 2, child: _buildDropdownField(
                    label: 'Title', 
                    icon: Icons.person_outline, 
                    items: ['Mr', 'Mrs', 'Ms', 'Dr', 'Baby Boy', 'Baby Girl', 'Other'],
                    value: _selectedTitle,
                    onChanged: (v) { if (v != null) _updateState(() { _selectedTitle = v; }); },
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: _buildTextField(label: 'First Name', icon: Icons.person_outline, controller: _firstNameController)),
                ],
              ),
              const SizedBox(height: 8),
              _buildTextField(label: 'Last Name', icon: Icons.person_outline, controller: _lastNameController),
              const SizedBox(height: 8),
              _buildDropdownField(
                label: 'Gender (Optional)', 
                icon: Icons.wc, 
                items: ['Male', 'Female', 'Other'],
                value: _selectedGender,
                onChanged: (v) { if (v != null) _updateState(() { _selectedGender = v; }); },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Contact & Security',
          child: Column(
            children: [
              _buildTextField(
                label: 'Aadhaar Number', 
                icon: Icons.credit_card, 
                keyboardType: TextInputType.number, 
                controller: _aadharController,
                maxLength: 12,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 8),
              _buildTextField(
                label: 'Mobile Number', 
                icon: Icons.phone_outlined, 
                keyboardType: TextInputType.phone, 
                controller: _mobileController,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 8),
              _buildTextField(label: 'Email Address', icon: Icons.alternate_email, keyboardType: TextInputType.emailAddress, controller: _emailController),
              const SizedBox(height: 8),
              _buildTextField(
                label: 'Create Password', 
                icon: Icons.lock_outline, 
                isPasswordField: true, 
                isObscure: _obscurePassword,
                onSuffixTap: () { _updateState(() { _obscurePassword = !_obscurePassword; }); },
                controller: _passwordController,
              ),
              _buildPasswordStrengthIndicator(),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Switch(
              value: true, 
              onChanged: (v) {},
              activeColor: Colors.white,
              activeTrackColor: primaryGreen,
            ),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13),
                  children: const [
                    TextSpan(text: 'Agree to '),
                    TextSpan(text: 'Terms & Privacy Policy', style: TextStyle(color: primaryGreen, decoration: TextDecoration.underline, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _isLoading ? const Center(child: CircularProgressIndicator()) : _buildSubmitButton('Create Account', _registerUser),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(color: primaryGreen.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }


  Widget _buildPasswordStrengthIndicator() {
    Color color1 = _passwordStrength >= 1 ? Colors.red : Colors.grey[300]!;
    Color color2 = _passwordStrength >= 2 ? Colors.orange : Colors.grey[300]!;
    Color color3 = _passwordStrength >= 3 ? Colors.green : Colors.grey[300]!;
    String strengthText = 'Weak';
    if (_passwordStrength == 2) strengthText = 'Medium';
    if (_passwordStrength == 3) strengthText = 'Strong';
    if (_passwordStrength == 0) strengthText = '';

    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 4, right: 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, decoration: BoxDecoration(color: color1, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(width: 4),
              Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, decoration: BoxDecoration(color: color2, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(width: 4),
              Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, decoration: BoxDecoration(color: color3, borderRadius: BorderRadius.circular(2)))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(strengthText, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
              Text('8+ chars, 1 uppercase, 1 number', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    bool isPasswordField = false,
    bool isObscure = false,
    VoidCallback? onSuffixTap,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
    TextEditingController? controller,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent),
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          counterText: '',
          isDense: true,
          labelText: label,
          hintText: hintText,
          hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
          labelStyle: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
          prefixIcon: Icon(icon, color: primaryGreen.withOpacity(0.7), size: 20),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 30),
          suffixIcon: isPasswordField ? IconButton(
            icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey[400], size: 20),
            onPressed: onSuffixTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ) : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 30),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label, 
    required IconData icon, 
    required List<String> items,
    String? value,
    ValueChanged<String?>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundCream.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
          prefixIcon: Icon(icon, color: primaryGreen.withOpacity(0.7), size: 20),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 30),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        icon: const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(Icons.arrow_drop_down, color: Colors.grey),
        ),
        items: items.map((String val) {
          return DropdownMenuItem<String>(
            value: val,
            child: Text(val, style: GoogleFonts.inter()),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubmitButton(String text, [VoidCallback? onPressed]) {
    return ElevatedButton(
      onPressed: onPressed ?? () {
        Navigator.of(context).pop(); // Close dialog first
        _navigateToHome(); // Then navigate
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 20),
        ],
      ),
    );
  }

  Widget _buildSocialLogin() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('OR CONTINUE WITH', style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildSocialButton('Google', Icons.g_mobiledata)),
            const SizedBox(width: 16),
            Expanded(child: _buildSocialButton('Apple', Icons.apple)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Don't have an account? ", style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _showAuthDialog(isLogin: false);
              },
              child: Text("Register Now", style: GoogleFonts.inter(color: primaryDark, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.black87),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }
}

class AnimatedBranchCard extends StatefulWidget {
  final String title;
  final String address;
  final String phone;
  final String imagePath;
  final VoidCallback onTap;

  const AnimatedBranchCard({
    Key? key,
    required this.title,
    required this.address,
    required this.phone,
    required this.imagePath,
    required this.onTap,
  }) : super(key: key);

  @override
  State<AnimatedBranchCard> createState() => _AnimatedBranchCardState();
}

class _AnimatedBranchCardState extends State<AnimatedBranchCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withOpacity(0.1), 
                  blurRadius: 20, 
                  offset: const Offset(0, 10)
                ),
              ],
            ),
            child: Stack(
              children: [
                // Animated Border Layer
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Transform.scale(
                      scale: 1.5,
                      child: Transform.rotate(
                        angle: _controller.value * 2 * 3.1415926535897932,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: SweepGradient(
                              colors: [
                                Colors.transparent,
                                primaryGreen.withOpacity(0.1),
                                primaryGreen.withOpacity(0.8),
                                primaryGreen,
                                primaryGreen.withOpacity(0.8),
                                primaryGreen.withOpacity(0.1),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Inner White Card Layer
                Padding(
                  padding: const EdgeInsets.all(2.5), // Border width
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        onTap: widget.onTap,
                        borderRadius: BorderRadius.circular(22),
                        splashColor: primaryGreen.withOpacity(0.1),
                        highlightColor: primaryGreen.withOpacity(0.05),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: DecorationImage(
                                    image: AssetImage(widget.imagePath),
                                    fit: BoxFit.cover,
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: primaryGreen.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen)),
                                    const SizedBox(height: 8),
                                    Text(widget.address, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700], height: 1.5)),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, size: 14, color: primaryGreen),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            widget.phone, 
                                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: primaryGreen.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_ios, 
                                    size: 14, 
                                    color: primaryGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PulsingLoginText extends StatefulWidget {
  const PulsingLoginText({super.key});
  @override
  _PulsingLoginTextState createState() => _PulsingLoginTextState();
}

class _PulsingLoginTextState extends State<PulsingLoginText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.touch_app_rounded, color: Color(0xFF166534), size: 14),
            const SizedBox(width: 4),
            Text("Tap Card to Login", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF166534))),
          ],
        ),
      ),
    );
  }
}
