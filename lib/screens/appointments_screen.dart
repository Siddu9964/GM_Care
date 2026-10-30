import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../widgets/appointment_form_sheet.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'patient_dashboard.dart';
import 'account_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  final String userName;
  final String location;
  final String age;
  final String sex;
  final String cookie;
  final String patientId;
  final int initialTab;

  const AppointmentsScreen({
    super.key,
    required this.userName,
    required this.location,
    required this.age,
    required this.sex,
    required this.cookie,
    this.patientId = '',
    this.initialTab = 0,
  });

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // State for My Appointments
  bool _isLoading = true;
  String _errorMsg = '';
  List<dynamic> _appointments = [];
  String _activeFilter = 'All'; // 'All', 'Scheduled', 'Completed', 'Cancelled'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this, 
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _fetchAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });
    
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
        if (json['status'] == 'success' && json['data'] != null) {
          if (mounted) {
            setState(() {
              _appointments = json['data'];
              _isLoading = false;
            });
          }
        } else {
          throw Exception("Failed to load appointments format");
        }
      } else {
        throw Exception("Failed to load appointments. Server responded with ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = e.toString();
        });
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Unknown Date";
    try {
      DateTime dt = DateTime.parse(dateStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "Unknown Time";
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        int h = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        String ampm = h >= 12 ? 'PM' : 'AM';
        if (h > 12) h -= 12;
        if (h == 0) h = 12;
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
      }
    } catch (_) {}
    return timeStr;
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Scheduled', 'Completed', 'Cancelled'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _activeFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => setState(() => _activeFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1F6B4A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF1F6B4A) : const Color(0xFFDED8CB),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1F6B4A).withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF5A6E64),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMyAppointmentsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1F6B4A)));
    }
    
    if (_errorMsg.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 14),
            Text(_errorMsg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _fetchAppointments,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F6B4A)),
              child: const Text("Retry", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }

    final filteredAppointments = _appointments.where((apt) {
      if (_activeFilter == 'All') return true;
      final status = apt['status']?.toString() ?? 'Scheduled';
      return status.toLowerCase() == _activeFilter.toLowerCase();
    }).toList();

    if (filteredAppointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDED8CB)),
              ),
              child: const Icon(Icons.event_note_rounded, size: 44, color: Color(0xFF1F6B4A)),
            ),
            const SizedBox(height: 16),
            Text(
              "No ${_activeFilter == 'All' ? '' : _activeFilter.toLowerCase()} appointments found.",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF143B2A)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAppointments,
      color: const Color(0xFF1F6B4A),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        itemCount: filteredAppointments.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final apt = filteredAppointments[index];
          final docName = apt['doctor_name'] ?? 'Consultant';
          final status = apt['status'] ?? 'Scheduled';
          final date = _formatDate(apt['appointment_date']);
          final time = _formatTime(apt['appointment_time']);
          final aptId = apt['id']?.toString() ?? apt['appointment_id']?.toString() ?? '101';
          final tokenNo = (int.tryParse(aptId) ?? 101) % 40 + 1;
          
          Color statusColor;
          Color statusBgColor;
          if (status.toLowerCase() == 'completed') {
            statusColor = const Color(0xFF166534);
            statusBgColor = const Color(0xFFDCFCE7);
          } else if (status.toLowerCase() == 'cancelled') {
            statusColor = const Color(0xFF991B1B);
            statusBgColor = const Color(0xFFFEE2E2);
          } else {
            statusColor = const Color(0xFF1F6B4A);
            statusBgColor = const Color(0xFFE6F4F1);
          }
          
          bool isExpired = false;
          if (status.toLowerCase() != 'cancelled' && status.toLowerCase() != 'completed') {
            final dtStr = '${apt['appointment_date']} ${apt['appointment_time'] ?? '00:00:00'}';
            final dt = DateTime.tryParse(dtStr);
            if (dt != null && dt.isBefore(DateTime.now())) {
              isExpired = true;
            }
          }

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDED8CB)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1F6B4A).withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badge Bar: Token & Status
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
                            child: Text(
                              "TOKEN #$tokenNo",
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isExpired ? "COMPLETED" : status.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9, 
                                  fontWeight: FontWeight.w800, 
                                  color: isExpired ? Colors.grey.shade600 : statusColor,
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
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF5A6E64)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Doctor Info
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F6B4A).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.15)),
                      ),
                      child: const Center(
                        child: Icon(Icons.person_rounded, color: Color(0xFF1F6B4A), size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            docName.startsWith("Dr") ? docName : "Dr. $docName",
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF143B2A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "OPD CONSULTANT • SUPER SPECIALIST",
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF26875B), letterSpacing: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Date & Time Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF8F4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDED8CB).withOpacity(0.7)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF1F6B4A)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                date,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF143B2A)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF5A6E64)),
                          const SizedBox(width: 4),
                          Text(time, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1F6B4A))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSupportChatModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F6B4A).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF1F6B4A), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              "GM Care Support & Help Desk",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A)),
            ),
            const SizedBox(height: 8),
            const Text(
              "Our hospital reception and support team are available 24/7 to assist you.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF1F6B4A)),
              title: const Text("Reception Helpline", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("080-23180200 / 080-23180300"),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.emergency_rounded, color: Colors.red),
              title: const Text("24/7 Emergency Desk", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              subtitle: const Text("+91 99000 00000"),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () {},
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFE6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1F6B4A), size: 20),
          onPressed: () {
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
                    patientId: widget.patientId,
                  ),
                ),
              );
            }
          },
        ),
        title: const Text('Appointments',
            style: TextStyle(color: Color(0xFF1F6B4A), fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Color(0xFF1F6B4A)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1F6B4A),
          indicatorWeight: 3,
          labelColor: const Color(0xFF1F6B4A),
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'My Appointments'),
            Tab(text: 'Book Appointment'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 90),
            child: TabBarView(
              controller: _tabController,
              children: [
                Column(
                  children: [
                    _buildFilterChips(),
                    Expanded(child: _buildMyAppointmentsList()),
                  ],
                ),
                AppointmentFormSheet(
                  userName: widget.userName,
                  location: widget.location,
                  age: widget.age,
                  sex: widget.sex,
                  cookie: widget.cookie,
                  patientId: widget.patientId,
                  onClose: () => _tabController.animateTo(0),
                  onSuccess: () {
                    _tabController.animateTo(0);
                    _fetchAppointments();
                  },
                ),
              ],
            ),
          ),
          AppBottomNavBar(
            currentIndex: 1,
            onTap: (idx) {
              if (idx == 0) {
                Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => PatientDashboard(
                    userName: widget.userName,
                    location: widget.location,
                    cookie: widget.cookie,
                    age: widget.age,
                    sex: widget.sex,
                    patientId: widget.patientId,
                  )));
              } else if (idx == 2) {
                _showSupportChatModal(context);
              } else if (idx == 3) {
                Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => AccountScreen(
                    userName: widget.userName,
                    location: widget.location,
                    cookie: widget.cookie,
                    age: widget.age,
                    sex: widget.sex,
                  )));
              }
            },
          ),
        ],
      ),
    );
  }
}
