import 'dart:ui';
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

class RadialQuickServicesHub extends StatefulWidget {
  final String userName;
  final String location;
  final String cookie;
  final String age;
  final String sex;

  const RadialQuickServicesHub({
    Key? key,
    required this.userName,
    required this.location,
    required this.cookie,
    required this.age,
    required this.sex,
  }) : super(key: key);

  @override
  State<RadialQuickServicesHub> createState() => _RadialQuickServicesHubState();
}

class _RadialQuickServicesHubState extends State<RadialQuickServicesHub> {
  final List<_ServiceData> _services = [
    _ServiceData("Book", Icons.calendar_today_rounded, 0),
    _ServiceData("Pharmacy", Icons.local_pharmacy_rounded, 1),
    _ServiceData("Reports", Icons.description_rounded, 2),
    _ServiceData("Billing", Icons.receipt_long_rounded, 3),
    _ServiceData("Doctors", Icons.people_alt_rounded, 4),
    _ServiceData("Records", Icons.assignment_ind_rounded, 5),
    _ServiceData("Emergency", Icons.emergency_rounded, 6),
    _ServiceData("Insights", Icons.auto_awesome_rounded, 7),
  ];

  Future<void> _handleServiceTap(_ServiceData service) async {
    Widget? destination;
    
    // Mapping the new UI titles to the exact existing backend/routing logic
    if (service.title == "Doctors") {
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error connecting to server.")));
        }
        return;
      }

    } else if (service.title == "Reports") {
      destination = HealthReportsScreen(userName: widget.userName, location: widget.location, cookie: widget.cookie);
    } else if (service.title == "Billing") {
      destination = BillingHistoryScreen(userName: widget.userName, location: widget.location, cookie: widget.cookie);
    } else if (service.title == "Pharmacy") {
      destination = PharmacyScreen(userName: widget.userName, location: widget.location, cookie: widget.cookie);
    } else if (service.title == "Book") {
      destination = AppointmentsScreen(userName: widget.userName, location: widget.location, cookie: widget.cookie, age: widget.age, sex: widget.sex);
    } else {
      // For Records, Emergency, Insights
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${service.title} service is coming soon!")));
      return;
    }

    if (destination != null) {
      // Custom Fade + Slide Page Transition
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => destination!,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0.0, 0.05), // Slight slide up
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
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4.0, bottom: 20.0),
            child: Text(
              "Quick Access",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F6B4A),
                letterSpacing: -0.5,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              // Ensure 4 items per row on mobile, more on wider screens
              final crossAxisCount = availableWidth > 600 ? 6 : 4;
              final spacing = 16.0;
              final itemWidth = (availableWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

              return Wrap(
                spacing: spacing, // horizontal gap
                runSpacing: 24, // vertical gap
                alignment: WrapAlignment.start,
                children: _services.map((service) {
                  return SizedBox(
                    width: itemWidth,
                    child: _QuickAccessItem(
                      service: service,
                      onTap: () => _handleServiceTap(service),
                    ),
                  );
                }).toList(),
              );
            }
          ),
        ],
      ),
    );
  }
}

class _ServiceData {
  final String title;
  final IconData icon;
  final int index;
  _ServiceData(this.title, this.icon, this.index);
}

class _QuickAccessItem extends StatefulWidget {
  final _ServiceData service;
  final VoidCallback onTap;

  const _QuickAccessItem({required this.service, required this.onTap});

  @override
  State<_QuickAccessItem> createState() => _QuickAccessItemState();
}

class _QuickAccessItemState extends State<_QuickAccessItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22), // Smooth rounded corners
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1F6B4A).withOpacity(0.06), // Very soft green-tinted shadow
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    widget.service.icon,
                    color: const Color(0xFF1F6B4A),
                    size: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.service.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F6B4A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}