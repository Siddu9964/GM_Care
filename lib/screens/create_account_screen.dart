import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/api_config.dart';

class CreateAccountScreen extends StatefulWidget {
  final String branchName;
  const CreateAccountScreen({Key? key, this.branchName = 'Nagarabhavi'}) : super(key: key);

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  bool _obscurePassword = true;
  bool _agreeToTerms = false;
  String? _selectedGender;
  bool _isLoading = false;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  // Colors matching the UI design
  final Color _primaryDark = const Color(0xFF053F2C); // Very dark green for text and button
  final Color _primaryGreen = const Color(0xFF1B5E43); // Medium green for links/icons
  final Color _bgColor = const Color(0xFFE9F0EB); // Soft greenish-beige gradient base
  final Color _lightGrey = const Color(0xFF9E9E9E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE9F2ED),
              Color(0xFFDFE9E3),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Account',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: _primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join a community of focused professionals.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildFormCard(),
                      const SizedBox(height: 32),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                            children: [
                              const TextSpan(text: 'Already have an account? '),
                              TextSpan(
                                text: 'Log in',
                                style: TextStyle(
                                  color: _primaryDark,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: _primaryDark,
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'AGRI',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _primaryDark,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 16.0, top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildBottomButton(Icons.login, 'Back to Login'),
          _buildBottomButton(Icons.help_outline, 'Help'),
        ],
      ),
    );
  }

  Widget _buildBottomButton(IconData icon, String label) {
    return InkWell(
      onTap: () {
        if (label == 'Back to Login') {
          Navigator.pop(context);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: _primaryDark.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputField(
            label: 'FIRST NAME',
            hint: 'Julian',
            controller: _firstNameController,
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: 'LAST NAME',
            hint: 'St. James',
            controller: _lastNameController,
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildDropdownField()),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildInputField(
                  label: 'AGE',
                  hint: '25',
                  keyboardType: TextInputType.number,
                  controller: _ageController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: 'EMAIL ADDRESS',
            hint: 'julian@aesthetic.co',
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            controller: _emailController,
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: 'PHONE NUMBER',
            hint: '+1 (555) 000-0000',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            controller: _phoneController,
          ),
          const SizedBox(height: 20),
          _buildPasswordField(),
          const SizedBox(height: 24),
          _buildTermsCheckbox(),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _registerUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: _primaryDark.withOpacity(0.3),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Begin Journey',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.grey[600],
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: _primaryDark,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: Colors.grey[400],
              fontSize: 15,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20, color: _lightGrey)
                : null,
            prefixIconConstraints: prefixIcon != null
                ? const BoxConstraints(minWidth: 40)
                : const BoxConstraints(minWidth: 0),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFEEEEEE), width: 1.5),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _primaryDark, width: 2),
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('GENDER IDENTITY'),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.people_outline, size: 20, color: _primaryGreen),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFEEEEEE), width: 1.5),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _primaryDark, width: 2),
            ),
            isDense: true,
          ),
          hint: Text(
            'Select identity',
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: _primaryDark,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          value: _selectedGender,
          items: ['Male', 'Female', 'Non-Binary', 'Other']
              .map((label) => DropdownMenuItem(
                    value: label,
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _primaryDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedGender = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('CREATE PASSWORD'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: _primaryDark,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Min. 8 characters',
            hintStyle: GoogleFonts.inter(
              color: Colors.grey[400],
              fontSize: 15,
            ),
            prefixIcon: Icon(Icons.lock_outline, size: 20, color: _lightGrey),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: _lightGrey,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 40),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent),
            ),
            isDense: true,
          ),
        ),
        // Password strength indicator dashes
        Row(
          children: List.generate(
            5,
            (index) => Expanded(
              child: Container(
                height: 3,
                margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreeToTerms,
            onChanged: (value) {
              setState(() {
                _agreeToTerms = value ?? false;
              });
            },
            activeColor: _primaryDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            side: const BorderSide(color: Color(0xFFCCCCCC), width: 1.5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontSize: 12,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms of Service',
                  style: TextStyle(
                    color: _primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: ' and\nacknowledge the '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(
                    color: _primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
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
                BoxShadow(color: isSuccess ? _primaryGreen.withOpacity(0.2) : Colors.red.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSuccess ? _primaryGreen.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                    color: isSuccess ? _primaryGreen : Colors.red,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 24, color: _primaryDark, height: 1.2),
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
                      backgroundColor: isSuccess ? _primaryDark : Colors.red,
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

  Future<void> _registerUser() async {
    if (!_agreeToTerms) {
      _showPopup('Terms Required', 'Please agree to the Terms of Service to continue.', false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.patients),
        headers: {
          'Content-Type': 'application/json',
          'X-Hospital-Branch': widget.branchName,
        },
        body: jsonEncode({
          'title': 'Mr', 
          'first_name': _firstNameController.text,
          'last_name': _lastNameController.text,
          'sex': _selectedGender ?? 'Other',
          'age': int.tryParse(_ageController.text),
          'aadhar': '', 
          'phone': _phoneController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          _showPopup('Success!', 'Your account has been created successfully.', true, onSuccess: () {
            Navigator.pop(context);
          });
        }
      } else {
        if (mounted) {
          _showPopup('Registration Failed', 'Could not complete registration. ${response.body}', false);
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
}
