import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/health_reports_screen.dart';
import '../screens/billing_history_screen.dart';
import '../screens/specialist_doctors_screen.dart';
import '../screens/pharmacy_screen.dart';
import '../screens/appointments_screen.dart';
import '../screens/test_data_screen.dart';

class RadialQuickServicesHub extends StatefulWidget {
  final String userName;
  final String location;
  final String cookie;
  final String age;
  final String sex;
  final String patientId;

  const RadialQuickServicesHub({
    Key? key,
    required this.userName,
    required this.location,
    required this.cookie,
    required this.age,
    required this.sex,
    required this.patientId,
  }) : super(key: key);

  @override
  State<RadialQuickServicesHub> createState() => _RadialQuickServicesHubState();
}

class _RadialQuickServicesHubState extends State<RadialQuickServicesHub> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  final List<_ClinicalService> _services = [
    _ClinicalService(
      id: 'book',
      title: "Book OPD",
      subtitle: "Consult Specialist",
      badge: "LIVE",
      icon: Icons.calendar_month_rounded,
    ),
    _ClinicalService(
      id: 'doctors',
      title: "Specialists",
      subtitle: "Doctor Directory",
      badge: "FACULTY",
      icon: Icons.people_alt_rounded,
    ),
    _ClinicalService(
      id: 'pharmacy',
      title: "24x7 Pharmacy",
      subtitle: "Bedside & Home",
      badge: "FAST",
      icon: Icons.medication_rounded,
    ),
    _ClinicalService(
      id: 'reports',
      title: "Lab & PACS",
      subtitle: "E-Signed Reports",
      badge: "VERIFIED",
      icon: Icons.biotech_rounded,
    ),
    _ClinicalService(
      id: 'billing',
      title: "Hospital Bills",
      subtitle: "Insurance / TPA",
      badge: "CLAIMS",
      icon: Icons.receipt_long_rounded,
    ),
    _ClinicalService(
      id: 'emergency',
      title: "Code Red SOS",
      subtitle: "Ambulance Hotline",
      badge: "EMERGENCY",
      icon: Icons.emergency_rounded,
      isEmergency: true,
    ),
    _ClinicalService(
      id: 'test',
      title: "Diagnostics",
      subtitle: "Test Data Hub",
      badge: "NABL",
      icon: Icons.science_rounded,
    ),
    _ClinicalService(
      id: 'insights',
      title: "Clinical Feed",
      subtitle: "Health Insights",
      badge: "DAILY",
      icon: Icons.insights_rounded,
    ),
  ];

  Future<void> _handleServiceTap(_ClinicalService service) async {
    Widget? destination;
    
    if (service.id == "doctors") {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF1F6B4A)));
        },
      );
      
      try {
        final response = await http.get(
          Uri.parse(ApiConfig.doctors),
          headers: {
            'X-Hospital-Branch': widget.location,
            'Accept': 'application/json',
            if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
          },
        );
        
        if (mounted) {
          Navigator.pop(context); // close loading dialog
        }
        
        if (response.statusCode == 200) {
          final jsonResp = jsonDecode(response.body);
          if (jsonResp['status'] == 'success' && jsonResp['data'] != null) {
            destination = SpecialistDoctorsScreen(
              specialization: "All Doctors",
              doctors: jsonResp['data'],
              userName: widget.userName,
              location: widget.location,
              age: widget.age,
              sex: widget.sex,
              cookie: widget.cookie,
              patientId: widget.patientId,
            );
          } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to load doctors data.")));
            return;
          }
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Server error: ${response.statusCode}")));
          return;
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // close loading dialog on error
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error connecting to server.")));
        }
        return;
      }
    } else if (service.id == "reports") {
      destination = HealthReportsScreen(userName: widget.userName, location: widget.location, cookie: widget.cookie, patientId: widget.patientId);
    } else if (service.id == "billing") {
      destination = BillingHistoryScreen(userName: widget.userName, location: widget.location, cookie: widget.cookie, patientId: widget.patientId);
    } else if (service.id == "pharmacy") {
      destination = PharmacyScreen(userName: widget.userName, location: widget.location, cookie: widget.cookie, patientId: widget.patientId);
    } else if (service.id == "book") {
      destination = AppointmentsScreen(userName: widget.userName, location: widget.location, cookie: widget.cookie, age: widget.age, sex: widget.sex, patientId: widget.patientId);
    } else if (service.id == "test") {
      destination = TestDataScreen(patientId: widget.patientId, location: widget.location, cookie: widget.cookie, userName: widget.userName);
    } else if (service.id == "emergency") {
      _showEmergencyModal();
      return;
    } else {
      // Insights
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${service.title} is synced with hospital health feed.")));
      return;
    }

    if (!mounted) return;
    final Widget dest = destination;
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => dest,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.0, 0.05),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          
          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          );
          
          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(position: slideAnimation, child: child),
          );
        },
      ),
    );
  }

  void _showEmergencyModal() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.82,
          ),
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 18),
                // Glowing Pulse Emergency Icon
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.25 * _pulseAnimation.value),
                          blurRadius: 18 * _pulseAnimation.value,
                          spreadRadius: 4 * _pulseAnimation.value,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                  child: const Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 36),
                ),
                const SizedBox(height: 14),
                const Text(
                  "GM Emergency & Trauma Center",
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF143B2A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  "Immediate resuscitation, Level-1 Trauma response & Cardiac Cath Lab emergency response team on standby 24x7.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[700], height: 1.35),
                ),
                const SizedBox(height: 18),
                // Helpline 1
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF8F4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDED8CB)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F6B4A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF1F6B4A), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text("Hospital Emergency Hotline (24x7)", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF5A6E64))),
                            SizedBox(height: 2),
                            Text("+91 80 2345 6789", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF143B2A))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Helpline 2
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFCA5A5).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.airport_shuttle_rounded, color: Color(0xFFDC2626), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text("Rapid Ambulance Dispatch (National)", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF991B1B))),
                            SizedBox(height: 2),
                            Text("108 / 112 (Toll Free)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Dismiss", style: TextStyle(color: Color(0xFF5A6E64), fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Hospital Services",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF143B2A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "High-Tech Super Specialty Care Units",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5A6E64),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F6B4A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1F6B4A).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) => Container(
                        width: 6.5,
                        height: 6.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFF26875B),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF26875B).withValues(alpha: 0.5 * _pulseAnimation.value),
                              blurRadius: 6 * _pulseAnimation.value,
                              spreadRadius: 2 * _pulseAnimation.value,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "24/7 ACTIVE",
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F6B4A),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final crossAxisCount = availableWidth > 600 ? 4 : 4;
            final spacing = 12.0;
            final itemWidth = (availableWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

            return Wrap(
              spacing: spacing,
              runSpacing: 14,
              alignment: WrapAlignment.start,
              children: _services.map((service) {
                return SizedBox(
                  width: itemWidth,
                  child: _ClinicalServiceTile(
                    service: service,
                    pulseAnimation: _pulseAnimation,
                    onTap: () => _handleServiceTap(service),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ClinicalService {
  final String id;
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final bool isEmergency;

  _ClinicalService({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    this.isEmergency = false,
  });
}

class _ClinicalServiceTile extends StatefulWidget {
  final _ClinicalService service;
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;

  const _ClinicalServiceTile({
    required this.service,
    required this.pulseAnimation,
    required this.onTap,
  });

  @override
  State<_ClinicalServiceTile> createState() => _ClinicalServiceTileState();
}

class _ClinicalServiceTileState extends State<_ClinicalServiceTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEmerg = widget.service.isEmergency;
    final primaryColor = isEmerg ? const Color(0xFFDC2626) : const Color(0xFF1F6B4A);
    final accentBg = isEmerg ? const Color(0xFFFEF2F2) : const Color(0xFFF6F8F6);

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: widget.pulseAnimation,
          builder: (context, child) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isEmerg 
                    ? Color.lerp(
                        const Color(0xFFFCA5A5), 
                        const Color(0xFFDC2626), 
                        0.35 * widget.pulseAnimation.value,
                      )! 
                    : const Color(0xFFDED8CB).withValues(alpha: 0.8),
                width: isEmerg ? 1.3 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isEmerg 
                      ? const Color(0xFFDC2626).withValues(alpha: 0.08 + 0.08 * widget.pulseAnimation.value)
                      : const Color(0xFF1F6B4A).withValues(alpha: 0.04),
                  blurRadius: isEmerg ? (12 + 6 * widget.pulseAnimation.value) : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Clinical Icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.14),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      widget.service.icon,
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.service.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isEmerg ? const Color(0xFFDC2626) : const Color(0xFF143B2A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.service.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5A6E64),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}