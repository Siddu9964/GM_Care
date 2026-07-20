import 'dart:convert';
import 'dart:ui';
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

  const AppointmentsScreen({
    super.key,
    required this.userName,
    required this.location,
    required this.age,
    required this.sex,
    required this.cookie,
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
    _tabController = TabController(length: 2, vsync: this);
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _activeFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF1F6B4A),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              selected: isSelected,
              onSelected: (bool selected) {
                if (selected) {
                  setState(() {
                    _activeFilter = filter;
                  });
                }
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF1F6B4A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: const Color(0xFF1F6B4A),
                  width: 1.5,
                ),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_errorMsg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAppointments,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F6B4A)),
              child: const Text("Retry", style: TextStyle(color: Colors.white)),
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
            const Icon(Icons.calendar_today_outlined, size: 64, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            Text(
              "No ${_activeFilter == 'All' ? '' : _activeFilter.toLowerCase()} appointments found.",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F6B4A)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAppointments,
      color: const Color(0xFF1F6B4A),
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: filteredAppointments.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final apt = filteredAppointments[index];
          final docName = apt['doctor_name'] ?? 'Unknown Doctor';
          final status = apt['status'] ?? 'Scheduled';
          final date = _formatDate(apt['appointment_date']);
          final time = _formatTime(apt['appointment_time']);
          
          Color statusColor;
          Color statusBgColor;
          if (status.toLowerCase() == 'completed') {
            statusColor = const Color(0xFF166534);
            statusBgColor = const Color(0xFFDCFCE7);
          } else if (status.toLowerCase() == 'cancelled') {
            statusColor = const Color(0xFF991B1B);
            statusBgColor = const Color(0xFFFEE2E2);
          } else {
            statusColor = const Color(0xFF1F6B4A); // Scheduled
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

          Widget cardContent = Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1F6B4A), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9, 
                          fontWeight: FontWeight.w800, 
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Icon(Icons.person_outline_rounded, color: Color(0xFF1F6B4A), size: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            docName.startsWith("Dr") ? docName : "Dr. $docName",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F6B4A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                date,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (isExpired) {
            cardContent = Opacity(
              opacity: 0.5,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 0.8, sigmaY: 0.8),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0,      0,      0,      1, 0,
                  ]),
                  child: cardContent,
                ),
              ),
            );
          }

          return cardContent;
        },
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
                  )));
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
