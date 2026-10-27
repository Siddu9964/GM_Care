import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/notification_service.dart';
import 'first_time_mobile_screen.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'patient_dashboard.dart';
import 'appointments_screen.dart';

// ─── Project Color Theme ──────────────────────────────────────────────────────
const _kGreen        = Color(0xFF1F6B4A);
const _kGreenLight   = Color(0xFF26875B);
const _kGreenDark    = Color(0xFF143B2A);
const _kGreenAccent  = Color(0xFF1F6B4A);
const _kDark         = Color(0xFF143B2A);
const _kBg           = Color(0xFFF3EFE6);

class AccountScreen extends StatefulWidget {
  final String userName;
  final String location;
  final String age;
  final String sex;
  final String cookie;
  final String patientId;

  const AccountScreen({
    super.key,
    required this.userName,
    required this.location,
    required this.age,
    required this.sex,
    required this.cookie,
    this.patientId = '',
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with TickerProviderStateMixin {

  late AnimationController _heroCtrl;
  late AnimationController _itemsCtrl;
  late Animation<double>   _heroScale;
  late Animation<double>   _itemsFade;

  Map<String, dynamic> _patient = {};
  bool _isLoading = true;
  String? _error;

  bool _notifEnabled     = true;
  bool _apptReminders    = true;
  bool _billingAlerts    = true;
  bool _healthTips       = false;

  // Added state for Biometric & Image
  bool _bioEnabled = false;
  bool _isAuthenticating = false;
  String? _localAvatarPath;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _heroCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _itemsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _heroScale = CurvedAnimation(parent: _heroCtrl,  curve: Curves.easeOutBack);
    _itemsFade = CurvedAnimation(parent: _itemsCtrl, curve: Curves.easeOut);
    _loadPrefs();
    _load();
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _itemsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _bioEnabled = prefs.getBool('bio_enabled') ?? false;
        _localAvatarPath = prefs.getString('avatar_path');
        _notifEnabled = true;
        prefs.setBool('notifications_push', true);
        _apptReminders = prefs.getBool('notifications_appointment') ?? true;
        _billingAlerts = prefs.getBool('notifications_billing') ?? true;
      });
    }
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final uri = Uri.parse(ApiConfig.patientSearch(widget.userName));
      final r = await http.get(uri, headers: {
        'Accept': 'application/json',
        'X-Hospital-Branch': widget.location,
        if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
      }).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        dynamic d = j['data'];
        if (d is Map && d.containsKey('data')) d = d['data'];
        if (d is List && d.isNotEmpty) {
          _patient = Map<String, dynamic>.from(d[0]);
        } else if (d is Map && d.isNotEmpty) {
          _patient = Map<String, dynamic>.from(d);
        } else {
          _error = 'Patient record not found.';
        }
      } else {
        _error = 'Server error (${r.statusCode})';
      }
    } catch (e) {
      _error = 'Network error. Check connection.';
    }
    setState(() => _isLoading = false);
    _heroCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 250));
    _itemsCtrl.forward();
  }

  // ── Getters from Table: patient ──────────────────────────────────────────
  String get _patientId  => _patient['patient_id']?.toString() ?? 'N/A';
  String get _firstName  => _patient['first_name']?.toString() ?? widget.userName;
  String get _lastName   => _patient['last_name']?.toString()  ?? '';
  String get _fullName   => '$_firstName ${_lastName.trim()}'.trim();
  String get _phone      => _patient['phone']?.toString()       ?? 'N/A';
  String get _email      => _patient['email']?.toString()       ?? 'N/A';
  String get _birthDate  => _patient['birth_date']?.toString()  ?? 'N/A';
  String get _bloodGroup => _patient['blood_group']?.toString() ?? 'N/A';
  String get _gender     => _patient['sex']?.toString()         ?? widget.sex;
  String get _occupation => _patient['occupation']?.toString()  ?? 'N/A';
  String get _aadhar {
    final a = _patient['aadhar']?.toString() ?? '';
    if (a.isEmpty || a.length < 4) return 'N/A';
    return 'XXXX XXXX ${a.substring(a.length - 4)}';
  }
  String get _address {
    final parts = <String>[];
    for (final k in ['address', 'area', 'city', 'state', 'pincode']) {
      final v = (_patient[k] ?? '').toString().trim();
      if (v.isNotEmpty) parts.add(v);
    }
    return parts.isNotEmpty ? parts.join(', ') : 'N/A';
  }
  String get _age {
    if (_patient['age'] != null) return '${_patient['age']}';
    return widget.age != '--' ? widget.age : 'N/A';
  }
  String get _initials {
    final fn = _firstName.trim();
    final ln = _lastName.trim();
    if (fn.isEmpty) return '?';
    return ln.isNotEmpty ? '${fn[0]}${ln[0]}'.toUpperCase() : fn[0].toUpperCase();
  }

  Widget _buildFallbackAvatar() {
    if (_localAvatarPath != null) {
      final f = File(_localAvatarPath!);
      if (f.existsSync()) {
        return Image.file(f, fit: BoxFit.cover, width: 112, height: 112);
      }
    }
    return Center(
      child: Text(_initials,
        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _toast(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: ok ? _kGreen : const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Feature Implementations ───────────────────────────────────────────────
  Future<void> _pickAvatar({required ImageSource source}) async {
    final picker  = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      preferredCameraDevice: source == ImageSource.camera ? CameraDevice.front : CameraDevice.rear,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (picked != null) {
      if (mounted) setState(() => _isLoading = true);
      
      try {
        final targetId = (_patient['patient_id'] != null && _patient['patient_id'].toString().isNotEmpty)
            ? _patient['patient_id'].toString()
            : widget.userName;
        final uri = Uri.parse(ApiConfig.patientImageUpload(targetId));
        var request = http.MultipartRequest('POST', uri);
        request.headers.addAll({
          'Accept': 'application/json',
          'X-Hospital-Branch': widget.location,
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        });
        
        request.files.add(await http.MultipartFile.fromPath('image', picked.path));
        
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('avatar_path', picked.path);
          try {
            final resJson = jsonDecode(response.body);
            final newUrl = resJson['data']?['url'];
            if (newUrl != null) {
              _patient['image'] = newUrl;
            }
          } catch (_) {}
          if (mounted) {
            setState(() {
              _localAvatarPath = picked.path;
              // Clear previous network image cache if any so new avatar can reload
              imageCache.clear();
              imageCache.clearLiveImages();
            });
          }
          _toast('Profile picture updated!');
        } else {
          String errMsg = 'Failed to upload image (${response.statusCode})';
          try {
            final resJson = jsonDecode(response.body);
            if (resJson['error'] != null) {
              errMsg = resJson['error'];
            } else if (resJson['message'] != null) {
              errMsg = resJson['message'];
            }
          } catch (_) {}
          _toast(errMsg, ok: false);
        }
      } catch (e) {
        _toast('Upload error: $e', ok: false);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('avatar_path');
    if (mounted) setState(() => _localAvatarPath = null);
    _toast('Profile picture removed');
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Update Profile Photo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kDark)),
          const SizedBox(height: 6),
          Text('Choose how to update your photo', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 24),
          // Selfie option
          _avatarOptionTile(
            icon: Icons.camera_front_rounded,
            label: 'Take a Selfie',
            sub: 'Use the front camera',
            color: _kGreen,
            onTap: () { Navigator.pop(ctx); _pickAvatar(source: ImageSource.camera); },
          ),
          const SizedBox(height: 12),
          // Gallery option
          _avatarOptionTile(
            icon: Icons.photo_library_rounded,
            label: 'Choose from Gallery',
            sub: 'Pick an existing photo',
            color: _kGreen,
            onTap: () { Navigator.pop(ctx); _pickAvatar(source: ImageSource.gallery); },
          ),
          if (_localAvatarPath != null) ...[
            const SizedBox(height: 12),
            _avatarOptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Remove Photo',
              sub: 'Use initials instead',
              color: const Color(0xFFDC2626),
              onTap: () { Navigator.pop(ctx); _removeAvatar(); },
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ]),
      ))),
    );
  }

  Widget _avatarOptionTile({required IconData icon, required String label, required String sub, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18), width: 1.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.8), color]),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kDark)),
            Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color),
        ]),
      ),
    );
  }

  Future<void> _toggleBiometric() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    try {
      bool canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) {
        _toast('Biometric not available on device', ok: false);
        _isAuthenticating = false;
        return;
      }

      bool didAuth = await _auth.authenticate(
        localizedReason: 'Please authenticate to toggle biometric login',
        biometricOnly: true,
      );

      if (didAuth) {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _bioEnabled = !_bioEnabled;
        });
        await prefs.setBool('bio_enabled', _bioEnabled);

        if (_bioEnabled) {
          // ── Save session credentials for biometric auto-login ──────────────
          await prefs.setString('bio_username', widget.userName);
          await prefs.setString('bio_location', widget.location);
          await prefs.setString('bio_age',      widget.age);
          await prefs.setString('bio_sex',      widget.sex);
          await prefs.setString('bio_cookie',   widget.cookie);
          _toast('Biometric Login Enabled ✓');
        } else {
          // ── Clear saved credentials when disabled ──────────────────────────
          await prefs.remove('bio_username');
          await prefs.remove('bio_location');
          await prefs.remove('bio_age');
          await prefs.remove('bio_sex');
          await prefs.remove('bio_cookie');
          _toast('Biometric Login Disabled');
        }
      }
    } catch (e) {
      if (!e.toString().contains('authInProgress')) {
        _toast('Biometric error: $e', ok: false);
      }
    } finally {
      _isAuthenticating = false;
    }
  }

  // ── Dialogs & Sheets ──────────────────────────────────────────────────────

  void _showLogout() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 10))],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEF4444)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.logout_rounded, size: 28, color: Colors.white),
              ),
              const SizedBox(height: 18),
              const Text('Logout?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kDark)),
              const SizedBox(height: 8),
              Text('Are you sure you want to sign out of GM Care?', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final prefs = await SharedPreferences.getInstance();
                        
                        // ── Clear Session & Biometric Data ────────────────────
                        // This prevents FirstTimeMobileScreen from auto-logging back in
                        await prefs.remove('session_cookie');
                        await prefs.remove('session_name');
                        await prefs.remove('session_branch');
                        await prefs.remove('session_patient_id');
                        await prefs.remove('session_age');
                        await prefs.remove('session_sex');
                        
                        await prefs.remove('bio_cookie');
                        await prefs.remove('bio_username');
                        await prefs.remove('bio_age');
                        await prefs.remove('bio_sex');
                        await prefs.remove('bio_patient_id');

                        if (!mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const FirstTimeMobileScreen()),
                          (_) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfile() {
    final phoneCtrl      = TextEditingController()..text = _phone == 'N/A' ? '' : _phone;
    final emailCtrl      = TextEditingController()..text = _email == 'N/A' ? '' : _email;
    final aadharCtrl     = TextEditingController()..text = (_patient['aadhar'] ?? '').toString();
    final occupationCtrl = TextEditingController()..text = _occupation == 'N/A' ? '' : _occupation;
    final addressCtrl    = TextEditingController()..text = (_patient['address'] ?? '').toString();
    final cityCtrl       = TextEditingController()..text = (_patient['city'] ?? '').toString();
    final allowedBlood   = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    String rawBlood      = (_patient['blood_group'] ?? '').toString().trim();
    String normalizedBlood = rawBlood
        .replaceAll(RegExp(r'\s*\+?ve', caseSensitive: false), '+')
        .replaceAll(RegExp(r'\s*\-?ve', caseSensitive: false), '-')
        .toUpperCase();
    String? blood = allowedBlood.contains(normalizedBlood)
        ? normalizedBlood
        : (allowedBlood.contains(rawBlood.toUpperCase()) ? rawBlood.toUpperCase() : null);
    bool saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => _sheet(ctx, 'Edit Profile', Icons.edit_rounded, _kGreen, [
          _sheetField('Phone Number', phoneCtrl, Icons.phone_rounded, TextInputType.phone, maxLength: 10),
          _sheetField('Email Address', emailCtrl, Icons.email_rounded, TextInputType.emailAddress),
          _sheetField('Aadhaar Number', aadharCtrl, Icons.credit_card_rounded, TextInputType.number, maxLength: 12, hintText: '12-digit Aadhaar number'),
          _sheetField('Occupation', occupationCtrl, Icons.work_outline_rounded, TextInputType.text, hintText: 'e.g. Engineer, Business, Student'),
          _sheetField('Address', addressCtrl, Icons.home_rounded, TextInputType.streetAddress),
          _sheetField('City', cityCtrl, Icons.location_city_rounded, TextInputType.text),
          _dropdownField('Blood Group', blood, allowedBlood, Icons.bloodtype_rounded, (v) => ss(() => blood = v)),
          const SizedBox(height: 8),
          _sheetButton(saving, 'Save Changes', Icons.save_rounded, _kGreen, () async {
            ss(() => saving = true);
            await _saveProfile(
              phone: phoneCtrl.text, 
              email: emailCtrl.text, 
              aadhar: aadharCtrl.text,
              occupation: occupationCtrl.text,
              address: addressCtrl.text, 
              city: cityCtrl.text, 
              bloodGroup: blood,
            );
            if (mounted && ctx.mounted) Navigator.pop(ctx);
          }),
        ]),
      ),
    );
  }

  Future<void> _saveProfile({
    String? phone, 
    String? email, 
    String? aadhar,
    String? occupation,
    String? address, 
    String? city, 
    String? bloodGroup,
  }) async {
    if (_patientId == 'N/A') { _toast('Patient ID not found', ok: false); return; }
    try {
      final body = <String, dynamic>{};
      if (phone != null) body['phone'] = phone.trim();
      if (email != null) body['email'] = email.trim();
      if (aadhar != null) body['aadhar'] = aadhar.trim();
      if (occupation != null) body['occupation'] = occupation.trim();
      if (address != null) body['address'] = address.trim();
      if (city != null) body['city'] = city.trim();
      if (bloodGroup != null) body['blood_group'] = bloodGroup;

      final url = ApiConfig.patientUpdate(_patientId);
      final r = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Hospital-Branch': widget.location,
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (r.statusCode == 200) { 
        _toast('Profile updated!'); 
        await _load(); 
      } else { 
        String errMsg = 'Update failed (${r.statusCode})';
        try {
          final resJson = jsonDecode(r.body);
          if (resJson['error'] != null) {
            errMsg = resJson['error'];
          } else if (resJson['message'] != null) {
            errMsg = resJson['message'];
          }
        } catch (_) {}
        _toast(errMsg, ok: false); 
      }
    } catch (e) { 
      _toast('Network error: $e', ok: false); 
    }
  }

  void _showChangePwd() {
    final curCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final cfmCtrl = TextEditingController();
    bool obs = true, saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => _sheet(ctx, 'Change Password', Icons.lock_rounded, _kGreen, [
          _pwdField('Current Password', curCtrl, obs, () => ss(() => obs = !obs)),
          _pwdField('New Password', newCtrl, obs, () => ss(() => obs = !obs)),
          _pwdField('Confirm Password', cfmCtrl, obs, () => ss(() => obs = !obs)),
          const SizedBox(height: 8),
          _sheetButton(saving, 'Update Password', Icons.lock_reset_rounded, _kGreen, () async {
            if (newCtrl.text != cfmCtrl.text) { _toast('Passwords do not match', ok: false); return; }
            if (newCtrl.text.length < 6) { _toast('Minimum 6 characters', ok: false); return; }
            ss(() => saving = true);
            try {
              final r = await http.post(Uri.parse('${ApiConfig.baseUrl}/auth/change-password'),
                headers: {'Content-Type': 'application/json', if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie},
                body: jsonEncode({'current_password': curCtrl.text, 'new_password': newCtrl.text}),
              ).timeout(const Duration(seconds: 10));
              if (!mounted) return;
              if (r.statusCode == 200) { Navigator.pop(ctx); _toast('Password changed!'); }
              else { final d = jsonDecode(r.body); _toast(d['message'] ?? 'Failed', ok: false); }
            } catch (_) { _toast('Network error', ok: false); }
            ss(() => saving = false);
          }),
        ]),
      ),
    );
  }

  void _showEmergency() {
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl   = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => _sheet(ctx, 'Emergency Contact', Icons.emergency_rounded, _kGreen, [
        _sheetField('Contact Name', nameCtrl, Icons.person_rounded, TextInputType.name),
        _sheetField('Phone Number', phoneCtrl, Icons.phone_rounded, TextInputType.phone),
        _sheetField('Relationship', relCtrl, Icons.family_restroom_rounded, TextInputType.text),
        const SizedBox(height: 8),
        _sheetButton(false, 'Save Contact', Icons.save_rounded, _kGreen, () {
          Navigator.pop(ctx);
          _toast('Emergency contact saved!');
        }),
      ]),
    );
  }

  void _showHelp() => showDialog(context: context, builder: (ctx) => _infoDialog(
    'Help & Support', Icons.support_agent_rounded, _kGreen,
    [
      _helpRow(Icons.phone_rounded, 'Helpline', '+91-80-1234-5678', _kGreen),
      _helpRow(Icons.email_rounded, 'Email Us', 'support@gmcare.in', _kGreen),
      _helpRow(Icons.location_on_rounded, 'Visit Us', 'GM Hospital, Bangalore', _kGreen),
      _helpRow(Icons.access_time_rounded, 'Timings', 'Mon–Sat: 8 AM – 8 PM', _kGreen),
    ],
    ctx,
  ));

  void _showPolicy(String title, String text) => showDialog(context: context, builder: (ctx) => _textDialog(title, text, ctx));

  void _showRate() {
    int stars = 5;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30)]),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kGreen, _kGreenLight]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.star_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Rate GM Care', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _kDark)),
            const SizedBox(height: 4),
            Text('Your feedback matters!', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => ss(() => stars = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedScale(
                    scale: i < stars ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 38, color: const Color(0xFFF59E0B)),
                  ),
                ),
              )),
            ),
            const SizedBox(height: 10),
            Text('$stars / 5', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () { Navigator.pop(ctx); _toast('Thanks for rating GM Care! ⭐'); },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w800)),
              )),
            ]),
          ],
        ),
      ),
    )));
  }

  void _showShare() => showDialog(context: context, builder: (ctx) => Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30)]),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_kGreen, _kGreenLight]), borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.share_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          const Text('Share GM Care', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _kDark)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(14), border: Border.all(color: _kGreenAccent.withValues(alpha: 0.4))),
            child: const Text('GM Care – Your trusted healthcare partner!\nDownload: play.google.com/store/gmcare', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _kGreenDark, height: 1.5)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: 'GM Care – https://play.google.com/store/gmcare'));
              Navigator.pop(ctx);
              _toast('Link copied to clipboard!');
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy & Share', style: TextStyle(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(backgroundColor: _kGreen, foregroundColor: Colors.white, elevation: 0, minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ],
      ),
    ),
  ));

  // ── Sheet Helpers ─────────────────────────────────────────────────────────

  Widget _sheet(BuildContext ctx, String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 28, top: 0),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _kDark)),
            ]),
            const SizedBox(height: 22),
            ...children,
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sheetField(String label, TextEditingController ctrl, IconData icon, TextInputType kb, {int? maxLength, String? hintText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[600])),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl, keyboardType: kb, maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hintText,
            counterText: '',
            prefixIcon: Icon(icon, size: 20, color: _kGreen),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kGreen, width: 2)),
            filled: true, fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ]),
    );
  }

  Widget _dropdownField(String label, String? value, List<String> items, IconData icon, ValueChanged<String?> onChange) {
    final String? safeValue = (value != null && items.contains(value)) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[600])),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: safeValue, 
          onChanged: onChange,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFFDC2626)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
            filled: true, fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          hint: const Text('Select Blood Group'),
          items: items.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
        ),
      ]),
    );
  }

  Widget _pwdField(String label, TextEditingController ctrl, bool obs, VoidCallback toggle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[600])),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl, obscureText: obs,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_rounded, size: 20, color: _kGreen),
            suffixIcon: IconButton(icon: Icon(obs ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: Colors.grey), onPressed: toggle),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFDED8CB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFDED8CB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kGreen, width: 2)),
            filled: true, fillColor: const Color(0xFFFAF8F5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ]),
    );
  }

  Widget _sheetButton(bool loading, String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white,
          elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _infoDialog(String title, IconData icon, Color color, List<Widget> rows, BuildContext ctx) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30)]),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.white, 0.2)!]), borderRadius: BorderRadius.circular(18)),
              child: Icon(icon, color: Colors.white, size: 26)),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _kDark)),
            const SizedBox(height: 18),
            ...rows,
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0, minimumSize: const Size(double.infinity, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark)),
        ])),
      ]),
    );
  }

  Widget _textDialog(String title, String text, BuildContext ctx) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kDark)),
            const SizedBox(height: 12),
            SizedBox(height: 240, child: SingleChildScrollView(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.6)))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: _kGreen, foregroundColor: Colors.white, elevation: 0, minimumSize: const Size(double.infinity, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kGreenDark, _kGreen, _kGreenLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.32), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: 36, height: 36,
              child: CircularProgressIndicator(
                color: _kGreen, backgroundColor: _kGreen.withValues(alpha: 0.1), strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            const Text('Loading your profile…',
              style: TextStyle(color: _kGreen, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _itemsFade,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeroHeader(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          _errorBanner(),
                        ],
                        const SizedBox(height: 20),
                        _buildProfileCompletionBar(),
                        const SizedBox(height: 22),
                        _buildStatsRow(),
                        const SizedBox(height: 28),
                        _sectionHeader('Personal Details', Icons.person_rounded, onEdit: _showEditProfile),
                        const SizedBox(height: 12),
                        _buildPersonalCard(),
                        const SizedBox(height: 28),
                        _sectionHeader('Notifications', Icons.notifications_active_rounded),
                        const SizedBox(height: 12),
                        _buildNotificationsCard(),
                        const SizedBox(height: 28),
                        _sectionHeader('Account Security', Icons.shield_rounded),
                        const SizedBox(height: 12),
                        _buildSecurityCard(),
                        const SizedBox(height: 28),
                        _sectionHeader('Support & Legal', Icons.support_agent_rounded),
                        const SizedBox(height: 12),
                        _buildSupportCard(),
                        const SizedBox(height: 32),
                        _buildLogoutBtn(),
                        const SizedBox(height: 20),
                        _buildFooter(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Premium floating bottom nav
          AppBottomNavBar(
            currentIndex: 3,
            onTap: (idx) {
              if (idx == 0) {
                Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => PatientDashboard(
                    userName: widget.userName,
                    location: widget.location,
                    cookie: widget.cookie,
                    age: widget.age,
                    sex: widget.sex,
                    patientId: (_patientId != 'N/A' && _patientId.isNotEmpty) ? _patientId : widget.patientId,
                  )));
              } else if (idx == 1) {
                Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => AppointmentsScreen(
                    userName: widget.userName,
                    location: widget.location,
                    cookie: widget.cookie,
                    age: widget.age,
                    sex: widget.sex,
                    patientId: (_patientId != 'N/A' && _patientId.isNotEmpty) ? _patientId : widget.patientId,
                  )));
              } else if (idx == 2) {
                _showHelp();
              }
            },
          ),
        ],
      ),
    );
  }

  // ─── HERO HEADER ──────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return SliverToBoxAdapter(
      child: ScaleTransition(
        scale: _heroScale,
        child: Container(
          decoration: const BoxDecoration(
            color: _kGreen,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(44)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
              child: Column(
                children: [
                  // ── Top bar ──────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _glassButton(Icons.arrow_back_ios_rounded, () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PatientDashboard(
                                userName: widget.userName,
                                location: widget.location,
                                cookie: widget.cookie,
                                age: widget.age,
                                sex: widget.sex,
                                patientId: (_patientId != 'N/A' && _patientId.isNotEmpty) ? _patientId : widget.patientId,
                              ),
                            ),
                          );
                        }
                      }),
                      const Text('My Account',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      _glassButton(Icons.refresh_rounded, _load),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // ── Avatar with ring ──────────────────────────────
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Avatar image
                      Container(
                        width: 112, height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, 
                          color: const Color(0xFF0E5236),
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
                          ],
                        ),
                        child: ClipOval(
                          child: Builder(
                            builder: (context) {
                              final imageStr = _patient['image']?.toString();
                              if (imageStr != null && imageStr.isNotEmpty) {
                                if (imageStr.startsWith('data:image')) {
                                  final base64String = imageStr.split(',').last;
                                  return Image.memory(base64Decode(base64String), fit: BoxFit.cover, width: 112, height: 112);
                                } else if (imageStr.startsWith('http')) {
                                  return Image.network(imageStr, fit: BoxFit.cover, width: 112, height: 112,
                                    errorBuilder: (ctx, err, stack) => _buildFallbackAvatar());
                                } else if (imageStr.length > 100 && !imageStr.startsWith('/')) {
                                  return Image.memory(base64Decode(imageStr), fit: BoxFit.cover, width: 112, height: 112,
                                    errorBuilder: (ctx, err, stack) => _buildFallbackAvatar());
                                } else {
                                  // Server URL: e.g. https://erp.gmhospitals.co.in/patient_image_mobile/{name}.jpg
                                  return Image.network('${ApiConfig.imageBaseUrl}$imageStr', fit: BoxFit.cover, width: 112, height: 112,
                                    errorBuilder: (ctx, err, stack) {
                                      // Fallback to PHP API endpoint /patients/{id}/image
                                      final targetId = _patientId != 'N/A' ? _patientId : widget.userName;
                                      final fallbackUrl = '${ApiConfig.baseUrl}/patients/$targetId/image';
                                      return Image.network(fallbackUrl, fit: BoxFit.cover, width: 112, height: 112,
                                        errorBuilder: (ctx2, err2, stack2) => _buildFallbackAvatar());
                                    });
                                }
                              }

                              return _buildFallbackAvatar();
                            },
                          ),
                        ),
                      ),
                      // Camera FAB
                      Positioned(
                        bottom: 0, right: 0,
                        child: GestureDetector(
                          onTap: _showAvatarOptions,
                          child: Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 18, color: _kGreen),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Name & location ──────────────────────────────
                  Text(_fullName,
                    style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white,
                      letterSpacing: -0.5, height: 1.1),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.location_on_rounded, size: 13, color: Colors.white.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(widget.location,
                      style: TextStyle(
                        fontSize: 13, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 24),
                  
                  // ── Badges ───────────────────────────────────────
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8, runSpacing: 8,
                    children: [
                      _badge(_patientId, Icons.badge_rounded),
                      if (_bloodGroup != 'N/A')
                        _badge(_bloodGroup, Icons.water_drop_rounded,
                          bgColor: Colors.white,
                          textColor: const Color(0xFFDC2626)),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Glass Button ─────────────────────────────────────────────────────────
  Widget _glassButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _badge(String text, IconData? icon, {Color? bgColor, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: textColor ?? Colors.white70),
          const SizedBox(width: 5),
        ],
        Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor ?? Colors.white70)),
      ]),
    );
  }

  // ─── PROFILE COMPLETION BAR ───────────────────────────────────────────────
  Widget _buildProfileCompletionBar() {
    final fields = [_phone, _email, _bloodGroup, _occupation, _address, _birthDate, _aadhar];
    final filled = fields.where((f) => f != 'N/A' && f.isNotEmpty).length;
    final pct    = filled / fields.length;
    final pctInt = (pct * 100).round();
    final barColor = pct < 0.4
        ? const Color(0xFFDC2626)
        : pct < 0.7
            ? const Color(0xFFF59E0B)
            : _kGreen;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kGreenDark, _kGreen]),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.28), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: const Icon(Icons.bar_chart_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 13),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Profile Completion',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kDark)),
            SizedBox(height: 2),
            Text('Complete your profile for personalised care',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: barColor.withValues(alpha: 0.2), width: 1.5),
            ),
            child: Text('$pctInt%',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: barColor)),
          ),
        ]),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: barColor.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 9,
          ),
        ),
        if (pct < 1.0) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 13, color: Colors.grey[400]),
            const SizedBox(width: 6),
            Text(
              '${fields.length - filled} field${fields.length - filled != 1 ? 's' : ''} incomplete — tap Edit Profile to finish',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
          ]),
        ],
      ]),
    );
  }

  // ─── STATS ROW ────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final stats = [
      {'label': 'Blood',  'value': _bloodGroup,
       'icon': Icons.water_drop_rounded,      'c': _kGreen, 'bg': _kGreen.withValues(alpha: 0.08)},
      {'label': 'Age',    'value': _age != 'N/A' ? '${_age}y' : '--',
       'icon': Icons.cake_rounded,             'c': _kGreen, 'bg': _kGreen.withValues(alpha: 0.08)},
      {'label': 'Gender', 'value': _gender.isNotEmpty
          ? _gender[0].toUpperCase() + (_gender.length > 1 ? _gender.substring(1) : '') : '--',
       'icon': Icons.wc_rounded,              'c': _kGreen, 'bg': _kGreen.withValues(alpha: 0.08)},
      {'label': 'Branch', 'value': widget.location.split(' ').first,
       'icon': Icons.local_hospital_rounded,  'c': _kGreen, 'bg': _kGreen.withValues(alpha: 0.08)},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        children: List.generate(stats.length, (i) {
          final s  = stats[i];
          final c  = s['c'] as Color;
          final bg = s['bg'] as Color;
          return Container(
            margin: EdgeInsets.only(right: i < stats.length - 1 ? 12 : 0),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: c.withOpacity(0.06),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(s['icon'] as IconData, size: 16, color: c),
              const SizedBox(width: 8),
              Text('${s['label']}:', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text(s['value'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c)),
            ]),
          );
        }),
      ),
    );
  }

  // ─── SECTION HEADER ───────────────────────────────────────────────────────
  Widget _sectionHeader(String label, IconData icon, {VoidCallback? onEdit}) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kGreenDark, _kGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(13),
          boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.28), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Icon(icon, size: 15, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kDark))),
      if (onEdit != null)
        GestureDetector(
          onTap: onEdit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.edit_rounded, size: 14, color: _kGreen),
              SizedBox(width: 4),
              Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGreen)),
            ]),
          ),
        ),
    ]);
  }

  // ─── PREMIUM CARD SHELL ───────────────────────────────────────────────────
  Widget _premiumCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(children: rows),
      ),
    );
  }

  // ─── INFO ROW ─────────────────────────────────────────────────────────────
  Widget _infoRow(IconData icon, String label, String value, Color color,
      {bool isLast = false, bool copyable = false}) {
    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, isLast ? 14 : 0),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kDark),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
          if (copyable)
            GestureDetector(
              onTap: () { Clipboard.setData(ClipboardData(text: value)); _toast('$label copied!'); },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kGreenDark, _kGreen]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: const Icon(Icons.copy_rounded, size: 14, color: Colors.white),
              ),
            ),
        ]),
      ),
      if (!isLast) Divider(height: 1, indent: 58, endIndent: 16, color: Colors.grey[100]),
    ]);
  }

  // ─── PERSONAL CARD ────────────────────────────────────────────────────────
  Widget _buildPersonalCard() {
    return _premiumCard([
      _infoRow(Icons.person_rounded,       'Full Name',     _fullName,   _kGreen),
      _infoRow(Icons.badge_rounded,        'Patient ID',    _patientId,  _kGreen, copyable: true),
      _infoRow(Icons.phone_rounded,        'Phone',         _phone,      _kGreen),
      _infoRow(Icons.email_rounded,        'Email',         _email,      _kGreen),
      _infoRow(Icons.cake_rounded,         'Date of Birth', _birthDate,  _kGreen),
      _infoRow(Icons.credit_card_rounded,  'Aadhaar',       _aadhar,     _kGreen),
      _infoRow(Icons.work_outline_rounded, 'Occupation',    _occupation, _kGreen),
      _infoRow(Icons.location_on_rounded,  'Address',       _address,    _kGreen, isLast: true),
    ]);
  }

  // ─── NOTIFICATIONS ────────────────────────────────────────────────────────
  Widget _buildNotificationsCard() {
    return
      _premiumCard([
      // _compulsoryRow(Icons.notifications_active_rounded, 'Push Notifications', 'Mandatory for real-time health alerts', _kGreen),
      _toggleRow(Icons.alarm_rounded,                'Appointment Reminders', 'Remind before appointments',    _kGreen, _apptReminders, (v) async {
        setState(() => _apptReminders = v);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('notifications_appointment', v);
        _toast(v ? 'Reminders enabled'      : 'Reminders disabled');
        if (v) {
          NotificationService().showNotification(id: 1, title: 'Appointment Reminders', body: 'We will now notify you 15 minutes before your appointments.');
        }
      }
      ),
      _toggleRow(Icons.receipt_long_rounded,         'Billing Alerts',        'New bills & payment updates',   _kGreen, _billingAlerts, (v) async { 
        setState(() => _billingAlerts = v); 
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('notifications_billing', v);
        _toast(v ? 'Billing alerts enabled' : 'Billing alerts disabled'); 
        if (v) {
          NotificationService().showBillingAlert(title: 'Billing Alerts On', body: 'You will be notified of new invoices and payment updates.');
        }
      }),
      _toggleRow(Icons.health_and_safety_rounded,    'Health Tips',           'Daily wellness & fitness tips', _kGreen, _healthTips,    (v) { setState(() => _healthTips    = v); _toast(v ? 'Health tips enabled'    : 'Health tips disabled'); }, isLast: true),
    ]);
  }

  Widget _compulsoryRow(IconData icon, String title, String sub, Color color, {bool isLast = false}) {
    return Column(children: [
      InkWell(
        onTap: () => _toast('Push notifications are compulsory for clinical and emergency alerts.'),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, isLast ? 12 : 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark)),
              const SizedBox(height: 1),
              Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(
                    'COMPULSORY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
      if (!isLast) Divider(height: 1, indent: 58, endIndent: 16, color: Colors.grey[100]),
    ]);
  }

  Widget _toggleRow(IconData icon, String title, String sub, Color color, bool val,
      ValueChanged<bool> onChange, {bool isLast = false}) {
    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 10, isLast ? 12 : 0),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
            ),
            child: Icon(icon, size: 17, color: color)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark)),
            const SizedBox(height: 1),
            Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ])),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(value: val, onChanged: onChange, activeTrackColor: color),
          ),
        ]),
      ),
      if (!isLast) Divider(height: 1, indent: 58, endIndent: 16, color: Colors.grey[100]),
    ]);
  }

  Widget _buildSecurityCard() {
    return _premiumCard([
      _tapRow(Icons.lock_rounded,           'Change Password',  'Update your login credentials', _kGreen,                 _showChangePwd),
      _toggleRow(Icons.fingerprint_rounded, 'Biometric Login',  'Fingerprint or Face ID',        _kGreen,                 _bioEnabled, (v) => _toggleBiometric()),
      _tapRow(Icons.emergency_rounded,      'Emergency Contact','Designate an emergency contact',_kGreen,                 _showEmergency),
      _tapRow(Icons.devices_rounded,        'Active Sessions',  'Manage logged-in devices',      _kGreen,                 () => _toast('Session management — coming soon!'), isLast: true),
    ]);
  }

  // ─── SUPPORT & LEGAL ──────────────────────────────────────────────────────
  Widget _buildSupportCard() {
    return _premiumCard([
      _tapRow(Icons.support_agent_rounded, 'Help & Support',    'Chat, call or email us',       _kGreen,                 _showHelp),
      _tapRow(Icons.privacy_tip_outlined,  'Privacy Policy',    'How we use your data',          _kGreen,
        () => _showPolicy('Privacy Policy',
          'GM Care collects personal and health information to provide you with quality healthcare services. Your data is never sold to third parties. We comply with HIPAA and applicable Indian healthcare data regulations.\n\nAll medical records are encrypted and stored securely. You have the right to access, correct, or delete your information at any time by contacting support@gmcare.in.\n\nWe may use anonymized data for research to improve our services. Location data is only used to connect you with nearby hospitals and doctors.')),
      _tapRow(Icons.description_outlined,  'Terms of Service',  'Our terms & conditions',       _kGreen,
        () => _showPolicy('Terms of Service',
          'By using GM Care, you agree to our terms and conditions. This app is designed to facilitate appointment booking and health record access — it does not provide direct medical advice.\n\nAll appointments booked through the app are subject to doctor availability. GM Care is not responsible for cancellations due to medical emergencies or doctor unavailability.\n\nPatients must provide accurate information. False or misleading information may result in account suspension.')),
      _tapRow(Icons.star_rate_rounded,     'Rate GM Care',      'Share your experience',        _kGreen,                 _showRate),
      _tapRow(Icons.share_rounded,         'Share with Friends','Invite friends to GM Care',    _kGreen,                 _showShare, isLast: true),
    ]);
  }

  Widget _tapRow(IconData icon, String title, String sub, Color color, VoidCallback onTap,
      {bool isLast = false}) {
    return Column(children: [
      InkWell(
        onTap: onTap,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(24))
            : BorderRadius.zero,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 14, isLast ? 14 : 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
              ),
              child: Icon(icon, size: 17, color: color)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark)),
              const SizedBox(height: 1),
              Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ])),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
              ),
              child: Icon(Icons.arrow_forward_ios_rounded, size: 11, color: color),
            ),
          ]),
        ),
      ),
      if (!isLast) Divider(height: 1, indent: 58, endIndent: 16, color: Colors.grey[100]),
    ]);
  }

  // ─── LOGOUT ───────────────────────────────────────────────────────────────
  Widget _buildLogoutBtn() {
    return GestureDetector(
      onTap: _showLogout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3), width: 1.2),
          boxShadow: [
            BoxShadow(color: const Color(0xFFDC2626).withOpacity(0.06),
              blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.logout_rounded, size: 20, color: Color(0xFFDC2626)),
          SizedBox(width: 10),
          Text('Sign Out',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFDC2626), letterSpacing: 0.3)),
        ]),
      ),
    );
  }

  // ─── FOOTER ───────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 36, height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.transparent, Colors.grey.withValues(alpha: 0.3)]))),
      const SizedBox(width: 12),
      const Icon(Icons.local_hospital_rounded, size: 12, color: _kGreen),
      const SizedBox(width: 5),
      Text('GM Care  v1.0.0  •  GM Hospital',
        style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500)),
      const SizedBox(width: 12),
      Container(width: 36, height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.grey.withValues(alpha: 0.3), Colors.transparent]))),
    ]);
  }

  // ─── ERROR BANNER ─────────────────────────────────────────────────────────
  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDBA74), width: 1.5),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFEA580C).withValues(alpha: 0.1),
            shape: BoxShape.circle),
          child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 16)),
        const SizedBox(width: 12),
        Expanded(child: Text(_error!,
          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600))),
        TextButton(
          onPressed: _load,
          child: const Text('Retry',
            style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.w800, fontSize: 12))),
      ]),
    );
  }
}
