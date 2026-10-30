import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/notification_service.dart';
import '../screens/appointments_screen.dart';

class AppointmentsSection extends StatefulWidget {
  final String location;
  final String cookie;
  final String userName;
  final String age;
  final String sex;
  final String patientId;

  const AppointmentsSection({
    super.key,
    required this.location,
    required this.cookie,
    required this.userName,
    this.age = '--',
    this.sex = 'Unknown',
    this.patientId = '',
  });

  @override
  State<AppointmentsSection> createState() => _AppointmentsSectionState();
}

class _AppointmentsSectionState extends State<AppointmentsSection> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _appointments = [];
  
  late PageController _pageController;
  int _currentPage = 0;
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
    _pageController = PageController(viewportFraction: 0.88, initialPage: _currentPage);
    _fetchAppointments();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.appointments}?search=${Uri.encodeComponent(widget.userName)}'),
        headers: {
          'X-Hospital-Branch': widget.location,
          'Accept': 'application/json',
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['data'] != null) {
          final fetched = json['data'] as List;
          
          final validAppointments = fetched.where((apt) {
            final status = apt['appointment_status']?.toString() ?? '';
            return status != 'Cancelled' && status != 'Doctor On Leave' && status != 'Leave';
          }).toList();
          
          validAppointments.sort((a, b) {
            final dateA = DateTime.tryParse('${a['appointment_date']} ${a['appointment_time']}') ?? DateTime(2000);
            final dateB = DateTime.tryParse('${b['appointment_date']} ${b['appointment_time']}') ?? DateTime(2000);
            return dateB.compareTo(dateA);
          });
          
          if (mounted) {
            setState(() {
              _appointments = validAppointments;
              _isLoading = false;
            });
          }
          
          for (var apt in validAppointments) {
            final dt = DateTime.tryParse('${apt['appointment_date']} ${apt['appointment_time']}');
            if (dt != null && dt.isAfter(DateTime.now())) {
              final id = int.tryParse(apt['appointment_id'].toString()) ?? apt.hashCode;
              NotificationService().scheduleAppointmentReminders(
                appointmentId: id.abs() % 100000,
                doctorName: apt['doctor_name'] ?? 'Doctor',
                appointmentTime: dt,
              );
            }
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching appointments: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';
    try {
      final parts = timeStr.split(':');
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]);
      String ampm = h >= 12 ? 'PM' : 'AM';
      if (h > 12) h -= 12;
      if (h == 0) h = 12;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 140,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDED8CB)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1F6B4A), strokeWidth: 2.5),
        ),
      );
    }

    if (_appointments.isEmpty) {
      return _buildEmptyState();
    }

    final isTablet = MediaQuery.of(context).size.width > 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Active OPD Visits",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF143B2A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Live Hospital Consultation Queue",
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
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AppointmentsScreen(
                        userName: widget.userName,
                        location: widget.location,
                        cookie: widget.cookie,
                        age: widget.age,
                        sex: widget.sex,
                        patientId: widget.patientId,
                      ),
                    ),
                  ).then((_) => _fetchAppointments());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F6B4A).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        "Schedule",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1F6B4A)),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF1F6B4A)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: isTablet ? 220 : 190,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _appointments.length,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final apt = _appointments[index];
              final isActive = index == _currentPage;
              return _buildOpdPassCard(apt, isTablet, isActive);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDED8CB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F6B4A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF1F6B4A).withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.15)),
            ),
            child: const Icon(Icons.calendar_month_rounded, size: 26, color: Color(0xFF1F6B4A)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  "No Active OPD Bookings",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF143B2A)),
                ),
                SizedBox(height: 2),
                Text(
                  "Book an OPD consultation with super-specialists",
                  style: TextStyle(fontSize: 11, color: Color(0xFF5A6E64), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppointmentsScreen(
                    userName: widget.userName,
                    location: widget.location,
                    cookie: widget.cookie,
                    age: widget.age,
                    sex: widget.sex,
                    patientId: widget.patientId,
                    initialTab: 1,
                  ),
                ),
              ).then((_) => _fetchAppointments());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F6B4A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text("Book Now", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildOpdPassCard(dynamic apt, bool isTablet, bool isActive) {
    final status = apt['appointment_status']?.toString() ?? 'Scheduled';
    final dateStr = apt['appointment_date'] ?? 'Unknown Date';
    final timeStr = _formatTime(apt['appointment_time']?.toString());
    final docName = apt['doctor_name'] ?? 'Consultant';
    final spec = apt['specialization'] ?? 'Super Specialty';
    final aptId = apt['appointment_id']?.toString() ?? '101';
    final tokenNo = (int.tryParse(aptId) ?? 101) % 40 + 1;

    DateTime? dt;
    try { dt = DateTime.parse(dateStr); } catch (_) {}
    
    bool isExpired = false;
    if (dt != null) {
      final fullDate = DateTime.tryParse('${apt['appointment_date']} ${apt['appointment_time']}') ?? dt;
      if (fullDate.isBefore(DateTime.now())) {
        isExpired = true;
      }
    }

    final String dayFormatted = dt != null ? "${_getMonth(dt.month)} ${dt.day}, ${dt.year}" : dateStr;

    return AnimatedScale(
      scale: isActive ? 1.0 : 0.96,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isExpired ? const Color(0xFFDED8CB) : const Color(0xFF1F6B4A).withOpacity(0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F6B4A).withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Badge Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F6B4A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isExpired) ...[
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) => Container(
                                  width: 5.5,
                                  height: 5.5,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6EE7B7),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6EE7B7).withValues(alpha: 0.6 * _pulseAnimation.value),
                                        blurRadius: 4 * _pulseAnimation.value,
                                        spreadRadius: 1.5 * _pulseAnimation.value,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4.5),
                            ],
                            Text(
                              "TOKEN #$tokenNo",
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: isExpired ? Colors.grey.shade100 : const Color(0xFF26875B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isExpired ? Colors.grey.shade300 : const Color(0xFF26875B).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            isExpired ? "COMPLETED" : status.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isExpired ? Colors.grey.shade600 : const Color(0xFF1F6B4A),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.meeting_room_outlined, size: 13, color: Color(0xFF5A6E64)),
                    SizedBox(width: 3),
                    Text(
                      "Room 204",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5A6E64),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Doctor details
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F6B4A).withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.2)),
                  ),
                  child: const Center(
                    child: Icon(Icons.person_rounded, color: Color(0xFF1F6B4A), size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        docName.startsWith("Dr") ? docName : "Dr. $docName",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF143B2A),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        spec.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF26875B),
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF8F4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDED8CB).withValues(alpha: 0.7)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded, size: 13, color: Color(0xFF1F6B4A)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            dayFormatted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF143B2A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF5A6E64)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            timeStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F6B4A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppointmentsScreen(
                            userName: widget.userName,
                            location: widget.location,
                            cookie: widget.cookie,
                            age: widget.age,
                            sex: widget.sex,
                            patientId: widget.patientId,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F6B4A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            "Slip",
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right_rounded, size: 12, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonth(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }
}