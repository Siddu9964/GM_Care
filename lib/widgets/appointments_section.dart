import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
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

class _AppointmentsSectionState extends State<AppointmentsSection> {
  bool _isLoading = true;
  List<dynamic> _appointments = [];
  
  late PageController _pageController;
  int _currentPage = 0; // Changed to 0 so it starts at the first card

  @override
  void initState() {
    super.initState();
    // Reduced viewportFraction to 0.75 to reduce width as requested
    _pageController = PageController(viewportFraction: 0.75, initialPage: _currentPage);
    _fetchAppointments();
  }

  @override
  void dispose() {
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
          
          // Sort by date (descending, so most recent is first)
          validAppointments.sort((a, b) {
            final dateA = DateTime.tryParse('${a['appointment_date']} ${a['appointment_time']}') ?? DateTime(2000);
            final dateB = DateTime.tryParse('${b['appointment_date']} ${b['appointment_time']}') ?? DateTime(2000);
            return dateB.compareTo(dateA); // Descending
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
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF1F6B4A))),
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "My Appointments",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A), letterSpacing: -0.5),
              ),
              GestureDetector(
                onTap: () {
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text("See All", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F6B4A))),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF1F6B4A)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: isTablet ? 260 : 220,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _appointments.length, // Removed infinite loop
            onPageChanged: (idx) {
               setState(() => _currentPage = idx);
            },
            itemBuilder: (context, index) {
              final apt = _appointments[index];
              return _buildTicketCard(apt, isTablet, index == _currentPage);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        children: [
          const Icon(Icons.event_busy_rounded, size: 60, color: Color(0xFF1F6B4A)),
          const SizedBox(height: 16),
          const Text("No Appointments", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F6B4A))),
          const SizedBox(height: 8),
          const Text("You're all caught up! Book a new visit when needed.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              elevation: 0,
            ),
            child: const Text("Book Appointment", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildTicketCard(dynamic apt, bool isTablet, bool isActive) {
    final status = apt['appointment_status']?.toString() ?? 'Upcoming';
    final dateStr = apt['appointment_date'] ?? 'Unknown Date';
    final timeStr = _formatTime(apt['appointment_time']?.toString());
    final docName = apt['doctor_name'] ?? 'Unknown Doctor';
    final spec = apt['specialization'] ?? 'General';
    final type = apt['appointment_type'] ?? 'Hospital Visit';
    
    DateTime? dt;
    try { dt = DateTime.parse(dateStr); } catch (_) {}
    
    String day = dt != null ? dt.day.toString().padLeft(2, '0') : '--';
    String month = dt != null ? _getMonth(dt.month) : '---';
    String weekDay = dt != null ? _getWeekDay(dt.weekday) : '---';
    
    // Check if expired
    bool isExpired = false;
    if (dt != null) {
       final fullDate = DateTime.tryParse('${apt['appointment_date']} ${apt['appointment_time']}') ?? dt;
       if (fullDate.isBefore(DateTime.now())) {
           isExpired = true;
       }
    }

    Widget cardContent = AnimatedScale(
      scale: isActive ? 1.0 : 0.9,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
      child: AnimatedOpacity(
        opacity: isActive ? 1.0 : 0.6,
        duration: const Duration(milliseconds: 500),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 8))],
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  // Left Date Strip
                  Container(
                    width: 60,
                    decoration: BoxDecoration(
                      color: isExpired ? Colors.grey[600] : const Color(0xFF1F6B4A),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(month.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(day, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26, height: 1.0)),
                        const SizedBox(height: 2),
                        Text(weekDay.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Perforation line
                  CustomPaint(
                    size: Size(1, isTablet ? 260 : 220),
                    painter: DashedLinePainter(),
                  ),
                  // Center Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isExpired ? Colors.grey[200] : const Color(0xFFF3EFE6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isExpired ? 'EXPIRED' : status.toUpperCase(),
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: isExpired ? Colors.grey[600] : const Color(0xFF1F6B4A)),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isExpired ? Colors.grey[200] : const Color(0xFFF3EFE6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.calendar_month_rounded, size: 14, color: isExpired ? Colors.grey[600] : const Color(0xFF1F6B4A)),
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: const NetworkImage('https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?w=100'),
                                backgroundColor: isExpired ? Colors.grey[300] : const Color(0xFFF3EFE6),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      docName.startsWith("Dr") ? docName : "Dr. $docName", 
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isExpired ? Colors.grey[700] : const Color(0xFF1F6B4A)), 
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis
                                    ),
                                    Text("$spec • $type", style: TextStyle(fontSize: 11, color: isExpired ? Colors.grey[500] : Colors.grey, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Divider(color: Colors.grey.withOpacity(0.2)),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(timeStr, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isExpired ? Colors.grey[700] : const Color(0xFF1F6B4A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const Text("Time", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              if (!isExpired)
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
                                        ),
                                      ),
                                    ).then((_) => _fetchAppointments());
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1F6B4A),
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shadowColor: const Color(0xFF1F6B4A).withValues(alpha: 0.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text("Check-In", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      SizedBox(width: 4),
                                      Icon(Icons.arrow_forward_rounded, size: 14),
                                    ],
                                  ),
                                )
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (isExpired)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                      child: Container(
                        color: Colors.white.withOpacity(0.3),
                        alignment: Alignment.center,
                        child: Transform.rotate(
                          angle: -0.2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red.withOpacity(0.7), width: 3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "COMPLETED",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.red.withOpacity(0.7),
                                letterSpacing: 2,
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
        ),
      ),
    );

    return cardContent;
  }

  String _getMonth(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }

  String _getWeekDay(int d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d - 1];
  }
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashHeight = 5, dashSpace = 5, startY = 0;
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 2;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}