import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

// ─── Design Tokens ───────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFF1F6B4A);
const _kPrimaryLt = Color(0xFF1F6B4A);
const _kAccent    = Color(0xFF34C77B);
const _kSurface   = Color(0xFFFFFFFF);
const _kBg        = Color(0xFFF3EFE6);
const _kBorder    = Color(0xFFE2EBE6);
const _kText1     = Color(0xFF1F6B4A);
const _kText2     = Color(0xFF4A6358);
const _kText3     = Color(0xFF8DA89C);
const _kSelected  = Color(0xFFDFF5EB);
const _kSelBd     = Color(0xFF34C77B);
const _kError     = Color(0xFFE53935);
const _kGold      = Color(0xFFF59E0B);

class AppointmentFormSheet extends StatefulWidget {
  final String userName;
  final String location;
  final String age;
  final String sex;
  final String cookie;
  final String? initialDepartment;
  final String? initialDoctorName;
  final String? appointmentId;
  final String? initialDate;
  final String? initialTime;

  const AppointmentFormSheet({
    super.key,
    required this.userName,
    required this.location,
    required this.age,
    required this.sex,
    required this.cookie,
    this.initialDepartment,
    this.initialDoctorName,
    this.appointmentId,
    this.initialDate,
    this.initialTime,
  });

  @override
  State<AppointmentFormSheet> createState() => _AppointmentFormSheetState();
}

class _AppointmentFormSheetState extends State<AppointmentFormSheet>
    with TickerProviderStateMixin {
  // ── State variables ───────────────────────────────────────────────────────
  String   _selectedPatient      = 'Myself';
  String   _selectedDepartment   = '';
  int      _selectedDoctorIndex  = -1;
  DateTime _selectedDate         = DateTime.now();
  String   _selectedTime         = '';
  String   _selectedReason       = 'General Checkup';
  bool     _showOtherField       = false;

  // Form controllers
  final TextEditingController _nameController  = TextEditingController();
  final TextEditingController _ageController   = TextEditingController();
  final TextEditingController _otherController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _selectedGender = 'Male';
  String _realPatientId  = '';
  final List<String> _genders = ['Male', 'Female', 'Other', 'Unknown'];

  // Data sources
  bool          _isLoadingPatient     = true;
  bool          _isLoadingDepartments = true;
  bool          _isLoadingDoctors     = true;
  bool          _isSubmitting         = false;
  List<dynamic> _doctors              = [];
  List<String>  _departments          = [];
  List<String>  _bookedTimes          = [];

  final List<String> _times = [
    '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM',
    '11:00 AM', '11:30 AM', '12:00 PM', '02:00 PM',
    '02:30 PM', '03:00 PM', '04:00 PM', '04:30 PM',
  ];
  final List<Map<String, dynamic>> _reasons = [
    {'label': 'General Checkup',  'icon': Icons.health_and_safety_outlined, 'color': Color(0xFF0284C7)},
    {'label': 'Follow-up',        'icon': Icons.replay_outlined,             'color': Color(0xFF7C3AED)},
    {'label': 'Report Review',    'icon': Icons.folder_open_outlined,        'color': Color(0xFF0D9488)},
    {'label': 'Emergency',        'icon': Icons.emergency_outlined,          'color': Color(0xFFDC2626)},
    {'label': 'Vaccination',      'icon': Icons.vaccines_outlined,           'color': Color(0xFF16A34A)},
    {'label': 'Lab Test',         'icon': Icons.science_outlined,            'color': Color(0xFFEA580C)},
    {'label': 'Surgery Consult',  'icon': Icons.local_hospital_outlined,     'color': Color(0xFF9333EA)},
    {'label': 'Other',            'icon': Icons.edit_note_outlined,          'color': Color(0xFF64748B)},
  ];

  // Animations
  late AnimationController _shimmerCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _nameController.text = widget.userName;
    _ageController.text  = widget.age == '--' ? '' : widget.age;
    if (_genders.contains(widget.sex)) _selectedGender = widget.sex;

    // ── BACKEND CALLS (untouched) ─────────────────────────────────────────
    if (widget.initialDepartment != null) {
      _selectedDepartment = widget.initialDepartment!;
    }
    if (widget.initialTime != null) {
      _selectedTime = widget.initialTime!;
    }
    if (widget.initialDate != null) {
      try {
        _selectedDate = DateTime.parse(widget.initialDate!);
      } catch (_) {}
    }
    _fetchPatientDetails();
    _fetchDepartments();
    _fetchDoctors(_selectedDepartment);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _fadeCtrl.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _otherController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BACKEND FUNCTIONS — DO NOT MODIFY
  // ══════════════════════════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════════════════════════
  //  GET DEPARTMENTS API (POSTMAN TESTING GUIDE)
  // ══════════════════════════════════════════════════════════════════════════
  // URL     : http://172.21.3.60:80/GM_HMS/api/departments
  // METHOD  : GET
  // HEADERS : 
  //   Accept            : application/json
  //   X-Hospital-Branch : Nagarabhavi
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _fetchDepartments() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.departments),
        headers: {
          'X-Hospital-Branch': widget.location,
          'Accept': 'application/json',
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'success' && json['data'] != null) {
          final List depts = json['data'];
          if (mounted) {
            setState(() {
              _departments = depts
                  .map<String>((d) => d['department_name'].toString())
                  .toList();
              if (_selectedDepartment.isNotEmpty && !_departments.contains(_selectedDepartment)) {
                _selectedDepartment = '';
              }
              _isLoadingDepartments = false;
            });
          }
        }
      } else {
        if (mounted) setState(() => _isLoadingDepartments = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDepartments = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GET DOCTORS API (POSTMAN TESTING GUIDE)
  // ══════════════════════════════════════════════════════════════════════════
  // URL     : http://172.21.3.60:80/GM_HMS/api/doctors
  //     (or with filter) http://172.21.3.60:80/GM_HMS/api/doctors?department=Cardiology
  // METHOD  : GET
  // HEADERS : 
  //   Accept            : application/json
  //   X-Hospital-Branch : Nagarabhavi
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _fetchDoctors([String department = '']) async {
    setState(() => _isLoadingDoctors = true);
    try {
      final url = department.isEmpty
          ? ApiConfig.doctors
          : ApiConfig.doctorsByDepartment(department);

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Hospital-Branch': widget.location,
          'Accept': 'application/json',
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'success' && json['data'] != null) {
          if (mounted) {
            setState(() {
              _doctors             = json['data'];
              _selectedDoctorIndex = -1;
              
              if (widget.initialDoctorName != null && widget.initialDoctorName!.isNotEmpty) {
                for (int i = 0; i < _doctors.length; i++) {
                  String name = _doctors[i]['full_name']?.toString() ?? '';
                  String initName = widget.initialDoctorName!;
                  if (name == initName || name == initName.replaceAll('Dr. ', '') || 'Dr. $name' == initName) {
                    _selectedDoctorIndex = i;
                    _fetchBookedTimes();
                    break;
                  }
                }
              }
              
              _isLoadingDoctors    = false;
            });
          }
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          setState(() => _isLoadingDoctors = false);
          _showMessage('Session expired. Please log out and log back in.', isError: true);
        }
      } else {
        if (mounted) setState(() => _isLoadingDoctors = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDoctors = false);
      debugPrint('Error fetching doctors: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SEARCH PATIENT DETAILS API
  // ══════════════════════════════════════════════════════════════════════════
  // URL     : http://172.21.3.60:80/GM_HMS/api/patients?search=YOUR_USERNAME
  // METHOD  : GET
  // HEADERS : 
  //   Accept            : application/json
  //   X-Hospital-Branch : Nagarabhavi
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _fetchPatientDetails() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.patientSearch(widget.userName)),
        headers: {
          'X-Hospital-Branch': widget.location,
          'Accept': 'application/json',
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['data'] != null && json['data']['data'] != null) {
          final List patients = json['data']['data'];
          if (patients.isNotEmpty) {
            final p = patients.first;
            
            final name = (p['first_name'] != null && p['last_name'] != null) 
                ? '${p['first_name']} ${p['last_name']}'
                : (p['first_name'] ?? widget.userName);
                
            final age  = p['age']?.toString() ?? widget.age;
            final sex  = p['sex'] ?? widget.sex;
            final email = p['email'] ?? '';
            final phone = p['phone'] ?? '';
            final realId = p['patient_id'] ?? widget.userName;
            
            setState(() {
              _realPatientId = realId;
              _nameController.text = name.trim();
              _phoneController.text = phone;
              _emailController.text = email;
              if (age != '--') _ageController.text = age;
              if (_genders.contains(sex)) _selectedGender = sex;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching patient details: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPatient = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FETCH BOOKED TIMES API
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _fetchBookedTimes() async {
    if (_selectedDoctorIndex < 0 || _doctors.isEmpty) return;
    
    final docId = _doctors[_selectedDoctorIndex]['doctor_id'];
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/appointments/check-availability?doctor_id=$docId&date=$dateStr'),
        headers: {
          'X-Hospital-Branch': widget.location,
          'Accept': 'application/json',
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['data'] != null && json['data']['booked_times'] != null) {
          final List booked = json['data']['booked_times'];
          setState(() {
            _bookedTimes = booked
                .map((a) => _formatTimeFromDb(a?.toString() ?? ''))
                .where((t) => t.isNotEmpty)
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching booked times: $e');
    }
  }

  String _formatTimeFromDb(String dbTime) {
    try {
      final parts = dbTime.split(':');
      if (parts.length >= 2) {
        int h = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        String ampm = h >= 12 ? 'PM' : 'AM';
        if (h > 12) h -= 12;
        if (h == 0) h = 12;
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
      }
    } catch (_) {}
    return dbTime;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  
  void _showMessage(String message, {bool isError = false}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    color: isError ? _kError : _kAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _kText1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    
    // Auto-dismiss after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  List<DateTime> get _next14Days =>
      List.generate(14, (i) => DateTime.now().add(Duration(days: i)));

  String _weekDay(int d) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];

  String _monthAbbr(int m) =>
      ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            _buildHeader(),
            const Divider(color: _kBorder, height: 1),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('👤  Patient Details'),
                    const SizedBox(height: 10),
                    _buildPatientSection(),
                    const SizedBox(height: 18),

                    _sectionLabel('🏥  Select Department'),
                    const SizedBox(height: 10),
                    _buildDepartmentRow(),
                    const SizedBox(height: 18),

                    _sectionLabel('👨‍⚕️  Choose Doctor'),
                    const SizedBox(height: 10),
                    _buildDoctorSection(),
                    const SizedBox(height: 18),

                    _sectionLabel('📅  Preferred Schedule'),
                    const SizedBox(height: 10),
                    _buildCompactSchedule(),
                    const SizedBox(height: 18),

                    _sectionLabel('📝  Reason for Visit'),
                    const SizedBox(height: 10),
                    _buildReasonGrid(),
                    if (_showOtherField) ...[
                      const SizedBox(height: 12),
                      _buildOtherField(),
                    ],
                    const SizedBox(height: 18),

                    _buildSummaryCard(),
                  ],
                ),
              ),
            ),
            _buildConfirmBar(),
          ],
        ),
      ),
    );
  }

  // ── Handle & Header ────────────────────────────────────────────────────────

  Widget _buildHandle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFCDD8D4),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kPrimary, _kPrimaryLt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.3),
                  blurRadius: 10, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.event_available_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Book Appointment',
                    style: GoogleFonts.inter(
                      fontSize: 17, fontWeight: FontWeight.w800,
                      color: _kText1, letterSpacing: -0.3,
                    )),
                Text('GM Hospital · ${widget.location}',
                    style: GoogleFonts.inter(
                      fontSize: 11, color: _kText3, fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder, width: 1.2),
              ),
              child: const Icon(Icons.close_rounded, size: 16, color: _kText2),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: _kText1, letterSpacing: 0.1,
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  //  SECTION 1 — PATIENT DETAILS  (compact card)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPatientSection() {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(14),
      child: _isLoadingPatient
          ? _shimmer(height: 80)
          : Column(
              children: [
                // Booking-for pill toggle
                _pillToggle(
                  options: ['Myself', 'Someone Else'],
                  selected: _selectedPatient,
                  onSelect: (v) => setState(() => _selectedPatient = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _miniField(_nameController, 'Name', Icons.person_outline_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _miniField(_ageController,  'Age',  Icons.cake_outlined, isNumber: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _miniGenderDrop()),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _miniField(_phoneController, 'Phone', Icons.phone_outlined, isNumber: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _miniField(_emailController, 'Email', Icons.email_outlined)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _pillToggle({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _kBg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Row(
        children: options.map((opt) {
          final isSel = selected == opt;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSel ? _kPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: isSel
                      ? [BoxShadow(color: _kPrimary.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Center(
                  child: Text(opt,
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: isSel ? Colors.white : _kText3,
                      )),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _miniField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isNumber = false,
  }) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: _kBg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder, width: 1.1),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _kText1),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 12, color: _kText3),
          prefixIcon: Icon(icon, size: 15, color: _kText3),
          prefixIconConstraints: const BoxConstraints(minWidth: 32),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          isDense: true,
        ),
      ),
    );
  }

  Widget _miniGenderDrop() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _kBg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder, width: 1.1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGender,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _kText3),
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _kText1),
          items: _genders
              .map((g) => DropdownMenuItem(value: g, child: Text(g, style: GoogleFonts.inter(fontSize: 12))))
              .toList(),
          onChanged: (v) { if (v != null) setState(() => _selectedGender = v); },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SECTION 2 — DEPARTMENT (single horizontal scrollable row)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDepartmentRow() {
    if (_isLoadingDepartments) {
      return SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, __) => _shimmer(height: 38, width: 90, radius: 20),
        ),
      );
    }

    if (_departments.isEmpty) {
      return _emptyState(Icons.domain_disabled_outlined, 'No departments available');
    }

    // "All" chip prepended
    final allDepts = ['All', ..._departments];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: allDepts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final dept  = allDepts[i];
          final isSel = (i == 0 && _selectedDepartment.isEmpty) ||
                        (_selectedDepartment == dept);
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDepartment   = (i == 0) ? '' : dept;
                _selectedDoctorIndex  = -1;
              });
              _fetchDoctors(_selectedDepartment);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? _kPrimary : _kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSel ? _kPrimary : _kBorder,
                  width: 1.2,
                ),
                boxShadow: isSel
                    ? [BoxShadow(color: _kPrimary.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
              ),
              child: Text(
                dept,
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: isSel ? Colors.white : _kText2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SECTION 3 — DOCTOR CARDS  (full_name, specialization, available_days, fee)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDoctorSection() {
    if (_isLoadingDoctors) {
      return SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, __) => _shimmer(height: 120, width: 200, radius: 16),
        ),
      );
    }

    if (_doctors.isEmpty) {
      return _emptyState(Icons.person_off_outlined,
          _selectedDepartment.isEmpty ? 'No doctors found' : 'No doctors in $_selectedDepartment');
    }

    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _doctors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _buildDoctorCard(i),
      ),
    );
  }

  Widget _buildDoctorCard(int index) {
    final doc    = _doctors[index];
    final isSel  = _selectedDoctorIndex == index;

    // Fields from doctors table
    String name   = doc['full_name'] ?? 'Unknown';
    if (!name.toLowerCase().startsWith('dr')) name = 'Dr. $name';
    final spec    = doc['specialization'] ?? 'Specialist';
    final days    = doc['available_days'] ?? '';
    final fee     = doc['consultation_fee'];
    final gender  = doc['gender'] ?? '';
    final avail   = (doc['availability'] ?? 'Available') != 'Off-Duty';
    final imgUrl  = gender == 'Female'
        ? 'https://i.pravatar.cc/150?img=47'
        : 'https://i.pravatar.cc/150?img=11';

    return GestureDetector(
      onTap: () { 
        if (avail) {
          setState(() => _selectedDoctorIndex = index);
          _fetchBookedTimes();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 210,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSel ? _kSelBd : _kBorder,
            width: isSel ? 1.8 : 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSel
                  ? _kAccent.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSel ? 12 : 6, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Opacity(
          opacity: avail ? 1.0 : 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: avatar + name + checkmark
              Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: _kBg,
                        backgroundImage: NetworkImage(imgUrl),
                      ),
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: avail
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w700, color: _kText1,
                            )),
                        Text(spec,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 10, color: _kText2)),
                      ],
                    ),
                  ),
                  if (isSel)
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: _kAccent, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: _kAccent.withValues(alpha: 0.4), blurRadius: 4)],
                      ),
                      child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: _kBorder),
              const SizedBox(height: 8),
              // Available days
              if (days.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 11, color: _kText3),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(days,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 10, color: _kText2, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              // Consultation fee
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Availability badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: avail ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      avail ? 'Available' : 'Off-Duty',
                      style: GoogleFonts.inter(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: avail ? const Color(0xFF15803D) : _kText3,
                      ),
                    ),
                  ),
                  // Fee
                  if (fee != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.currency_rupee, size: 11, color: _kGold),
                        Text(
                          fee.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700, color: _kGold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SECTION 4 — COMPACT SCHEDULE (date strip + time grid together)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCompactSchedule() {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date strip ──────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.today_outlined, size: 14, color: _kPrimary),
              const SizedBox(width: 6),
              Text('Date',
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _kText1,
                  )),
              const Spacer(),
              // Selected date badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kSelected,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kSelBd, width: 1),
                ),
                child: Text(
                  '${_weekDay(_selectedDate.weekday)}, ${_selectedDate.day} ${_monthAbbr(_selectedDate.month)}',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _kPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _next14Days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final date  = _next14Days[i];
                final isSel = date.day == _selectedDate.day &&
                    date.month == _selectedDate.month;
                final isToday = i == 0;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDate = date);
                    _fetchBookedTimes();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 48,
                    decoration: BoxDecoration(
                      gradient: isSel
                          ? const LinearGradient(
                              colors: [_kPrimary, _kPrimaryLt],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )
                          : null,
                      color: isSel ? null : _kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? Colors.transparent : _kBorder,
                        width: 1,
                      ),
                      boxShadow: isSel
                          ? [BoxShadow(color: _kPrimary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isToday ? 'Today' : _weekDay(date.weekday),
                          style: GoogleFonts.inter(
                            fontSize: isToday ? 8 : 10,
                            fontWeight: FontWeight.w600,
                            color: isSel ? Colors.white70 : _kText3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${date.day}',
                          style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: isSel ? Colors.white : _kText1,
                          ),
                        ),
                        Text(
                          _monthAbbr(date.month),
                          style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w500,
                            color: isSel ? Colors.white60 : _kText3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 12),

          // ── Time grid ───────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: _kPrimary),
              const SizedBox(width: 6),
              Text('Time Slot',
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _kText1,
                  )),
              const Spacer(),
              if (_selectedTime.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kSelected,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kSelBd, width: 1),
                  ),
                  child: Text(
                    _selectedTime,
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _kPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _times.where((t) {
              bool isToday = _selectedDate.year == DateTime.now().year && 
                             _selectedDate.month == DateTime.now().month && 
                             _selectedDate.day == DateTime.now().day;
              if (isToday) {
                 int h = int.parse(t.substring(0, 2));
                 int m = int.parse(t.substring(3, 5));
                 bool isPM = t.endsWith('PM');
                 if (isPM && h != 12) h += 12;
                 if (!isPM && h == 12) h = 0;
                 
                 DateTime now = DateTime.now();
                 if (now.hour > h || (now.hour == h && now.minute > m)) {
                    return false;
                 }
              }
              return true;
            }).toList().map((t) {
              final isSel = _selectedTime == t;
              // Morning / Afternoon / Evening grouping colour
              final isAM  = t.endsWith('AM');
              final accent = isAM ? _kPrimary : const Color(0xFF7C3AED);
              final isBooked = _bookedTimes.contains(t);
              
              return GestureDetector(
                onTap: () {
                  if (!isBooked) setState(() => _selectedTime = t);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isBooked ? const Color(0xFFF1F5F9) : (isSel ? accent : _kSurface),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isBooked ? const Color(0xFFE2E8F0) : (isSel ? accent : _kBorder), width: 1.1,
                    ),
                    boxShadow: isSel
                        ? [BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: Text(
                    t,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isBooked ? const Color(0xFF94A3B8) : (isSel ? Colors.white : _kText2),
                      decoration: isBooked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SECTION 5 — REASON FOR VISIT  (2-col grid card, Other reveals text input)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildReasonGrid() {
    // Build rows of 2 items each
    final rows = <Widget>[];
    for (int i = 0; i < _reasons.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: _reasonItem(i)),
            const SizedBox(width: 4),
            Expanded(child: i + 1 < _reasons.length ? _reasonItem(i + 1) : const SizedBox()),
          ],
        ),
      );
      if (i + 2 < _reasons.length) {
        rows.add(const Divider(height: 1, color: _kBorder));
      }
    }
    return Column(children: rows);
  }

  Widget _reasonItem(int i) {
    final r     = _reasons[i];
    final label = r['label'] as String;
    final icon  = r['icon'] as IconData;
    final color = r['color'] as Color;
    final isSel = _selectedReason == label;

    return InkWell(
      onTap: () => setState(() {
        _selectedReason = label;
        _showOtherField = label == 'Other';
        if (!_showOtherField) _otherController.clear();
      }),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSel ? color : _kText3),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  color: isSel ? color : _kText2,
                ),
              ),
            ),
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: isSel,
                onChanged: (_) => setState(() {
                  _selectedReason = label;
                  _showOtherField = label == 'Other';
                  if (!_showOtherField) _otherController.clear();
                }),
                activeColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                side: BorderSide(color: isSel ? color : _kText3, width: 1.4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF64748B).withValues(alpha: 0.4), width: 1.2),
      ),
      child: TextField(
        controller: _otherController,
        maxLines: 3,
        style: GoogleFonts.inter(fontSize: 13, color: _kText1),
        decoration: InputDecoration(
          hintText: 'Describe your reason for visit…',
          hintStyle: GoogleFonts.inter(fontSize: 12, color: _kText3),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 12, right: 8, top: 12),
            child: Icon(Icons.edit_note_outlined, size: 18, color: _kText3),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  APPOINTMENT SUMMARY CARD
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSummaryCard() {
    final docName = (_selectedDoctorIndex >= 0 && _selectedDoctorIndex < _doctors.length)
        ? () {
            String n = _doctors[_selectedDoctorIndex]['full_name'] ?? 'Unknown';
            if (!n.toLowerCase().startsWith('dr')) n = 'Dr. $n';
            return n;
          }()
        : 'Not selected';

    final dateStr =
        '${_weekDay(_selectedDate.weekday)}, ${_selectedDate.day} ${_monthAbbr(_selectedDate.month)}';

    final reasonDisplay = _selectedReason == 'Other' && _otherController.text.isNotEmpty
        ? _otherController.text
        : _selectedReason;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A4F33), _kPrimary],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: _kPrimary.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text('Appointment Summary',
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
                    )),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kAccent.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Text('Pending',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _kAccent)),
                ),
              ],
            ),
          ),
          // Body rows
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                _sumRow(Icons.person_outline_rounded,   'Patient',    _nameController.text.isEmpty ? '—' : _nameController.text),
                _sumRow(Icons.local_hospital_outlined,  'Department', _selectedDepartment.isEmpty ? 'All' : _selectedDepartment),
                _sumRow(Icons.medical_services_outlined,'Doctor',     docName),
                _sumRow(Icons.calendar_today_outlined,  'Date',       dateStr),
                _sumRow(Icons.schedule_rounded,         'Time',       _selectedTime),
                _sumRow(Icons.notes_rounded,            'Reason',     reasonDisplay),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sumRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.white38),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(label,
                style: GoogleFonts.inter(
                  fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w500,
                )),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SUBMIT APPOINTMENT API (POSTMAN TESTING GUIDE)
  // ══════════════════════════════════════════════════════════════════════════
  // URL     : http://172.21.3.60/GM_HMS/api/appointments
  // METHOD  : POST
  // HEADERS : 
  //   Content-Type      : application/json
  //   Accept            : application/json
  //   X-Hospital-Branch : Nagarabhavi (or Basaveshwaranagar)
  // 
  // BODY (raw JSON) :
  // {
  //    "patient_id": "PID-12345",
  //    "patient_name": "John Doe",
  //    "doctor_id": "1",
  //    "appointment_date": "2026-06-27",
  //    "appointment_time": "10:30:00",
  //    "reason": "General Checkup",
  //    "notes": "Booked via mobile app",
  //    "status": "Scheduled",
  //    "consultation_fee": "500",
  //    "discount": "0",
  //    "total_amount": "500",
  //    "payment_status": "Pending",
  //    "payment_mode": "Cash",
  //    "phone": "9876543210",
  //    "email": "patient@example.com"
  // }
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _submitAppointment() async {
    if (_selectedDoctorIndex < 0 || _selectedDoctorIndex >= _doctors.length) {
      _showMessage('Please select a doctor to continue.', isError: true);
      return;
    }

    if (_selectedTime.isEmpty) {
      _showMessage('Please select a time slot.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final doc = _doctors[_selectedDoctorIndex];
    
    // Format Date: YYYY-MM-DD
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    
    // Format Time: "10:15 AM" -> "10:15:00"
    String timeStr = _selectedTime;
    try {
      final isPM = timeStr.contains('PM');
      final parts = timeStr.replaceAll(' AM', '').replaceAll(' PM', '').split(':');
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]);
      if (isPM && h < 12) h += 12;
      if (!isPM && h == 12) h = 0;
      timeStr = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
    } catch (_) {}

    final reasonDisplay = _selectedReason == 'Other' && _otherController.text.isNotEmpty
        ? _otherController.text
        : _selectedReason;

    final body = {
      'patient_id': _realPatientId.isNotEmpty ? _realPatientId : widget.userName,
      'patient_name': _nameController.text,
      'doctor_id': doc['doctor_id'],
      'appointment_date': dateStr,
      'appointment_time': timeStr,
      'reason': reasonDisplay,
      'notes': 'Booked via mobile app',
      'status': 'Scheduled',
      'appointment_status': '1', // Ensure it returns to scheduled status
      'consultation_fee': doc['consultation_fee']?.toString() ?? '0',
      'discount': '0',
      'total_amount': doc['consultation_fee']?.toString() ?? '0',
      'payment_status': 'Pending',
      'payment_mode': 'Cash',
      'phone': _phoneController.text.trim(), 
      'email': _emailController.text.trim(),
    };

    try {
      final isUpdate = widget.appointmentId != null && widget.appointmentId!.isNotEmpty;
      final uri = isUpdate 
          ? Uri.parse('${ApiConfig.appointments}/${widget.appointmentId}')
          : Uri.parse(ApiConfig.appointments);
          
      final response = await (isUpdate ? http.put : http.post)(
        uri,
        headers: {
          'X-Hospital-Branch': widget.location,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
        body: jsonEncode(body),
      );

      if (mounted) setState(() => _isSubmitting = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          if (mounted) {
            final isUpdate = widget.appointmentId != null && widget.appointmentId!.isNotEmpty;
            _showMessage(isUpdate ? 'Appointment rescheduled!' : 'Appointment confirmed!');
            Future.delayed(const Duration(milliseconds: 2500), () {
              if (mounted) Navigator.pop(context);
            });
          }
        } else {
          _showError(json['message'] ?? 'Failed to book appointment.');
        }
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError('Network error. Please try again.');
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    _showMessage(msg, isError: true);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CONFIRM BAR (sticky bottom)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildConfirmBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            border: const Border(top: BorderSide(color: _kBorder, width: 1)),
          ),
          child: Row(
            children: [
              // Date/time mini pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder, width: 1.1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedTime,
                        style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w800, color: _kPrimary,
                        )),
                    Text(
                      '${_weekDay(_selectedDate.weekday)}, ${_selectedDate.day} ${_monthAbbr(_selectedDate.month)}',
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w500, color: _kText3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Confirm button
              Expanded(
                child: GestureDetector(
                  onTap: _isSubmitting ? null : _submitAppointment,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isSubmitting 
                            ? [const Color(0xFF94A3B8), const Color(0xFF64748B)]
                            : [_kPrimary, _kPrimaryLt],
                        begin: Alignment.centerLeft, end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _isSubmitting ? [] : [
                        BoxShadow(
                          color: _kPrimary.withValues(alpha: 0.4),
                          blurRadius: 14, offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.event_available_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text('Confirm Appointment',
                                    style: GoogleFonts.inter(
                                      fontSize: 14, fontWeight: FontWeight.w700,
                                      color: Colors.white, letterSpacing: 0.1,
                                    )),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UTILITY
  // ══════════════════════════════════════════════════════════════════════════

  BoxDecoration _cardDeco() => BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10, offset: const Offset(0, 4),
          ),
        ],
      );

  Widget _shimmer({required double height, double? width, double radius = 12}) {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, __) {
        final v = _shimmerCtrl.value;
        return Container(
          height: height, width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + v * 3, 0),
              end: Alignment(v * 3, 0),
              colors: const [Color(0xFFE8F0EC), Color(0xFFD0E4D8), Color(0xFFE8F0EC)],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(IconData icon, String msg) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: _kBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _kText3),
            const SizedBox(width: 8),
            Text(msg, style: GoogleFonts.inter(fontSize: 12, color: _kText3)),
          ],
        ),
      ),
    );
  }
}
