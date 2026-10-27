import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class NotificationsScreen extends StatefulWidget {
  final String patientId;

  const NotificationsScreen({super.key, required this.patientId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() { _isLoading = true; });
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.notifications}?doctor_id=${Uri.encodeComponent(widget.patientId)}'),
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          setState(() {
            _notifications = jsonResponse['data'] ?? [];
          });
          _markAsRead();
        }
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _markAsRead() async {
    final unreadIds = _notifications
        .where((n) => n['is_read'] == 0 || n['is_read'] == '0' || n['is_read'] == false)
        .map((n) => n['notification_id'].toString())
        .toList();

    if (unreadIds.isEmpty) return;

    try {
      await http.post(
        Uri.parse('${ApiConfig.notifications}/mark-read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'notification_ids': unreadIds}),
      );
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3EFE6),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Notifications',
          style: TextStyle(color: Color(0xFF1F6B4A), fontWeight: FontWeight.w800, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1F6B4A), size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1F6B4A)))
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xFF1F6B4A),
                  onRefresh: _fetchNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isRead = n['is_read'] == 1 || n['is_read'] == '1' || n['is_read'] == true;
                      
                      return _buildNotificationCard(
                        title: n['title'] ?? 'Notification',
                        message: n['message'] ?? '',
                        date: n['created_at'] ?? '',
                        isRead: isRead,
                        category: n['category'] ?? 'general',
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_rounded, size: 64, color: const Color(0xFF1F6B4A).withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No new notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1F6B4A))),
          const SizedBox(height: 8),
          Text('You are all caught up!', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String message,
    required String date,
    required bool isRead,
    required String category,
  }) {
    IconData icon;
    Color iconColor;
    
    switch (category.toLowerCase()) {
      case 'appointment':
        icon = Icons.calendar_month_rounded;
        iconColor = const Color(0xFF2563EB); // Blue
        break;
      case 'billing':
        icon = Icons.receipt_long_rounded;
        iconColor = const Color(0xFFDC2626); // Red
        break;
      default:
        icon = Icons.notifications_active_rounded;
        iconColor = const Color(0xFF1F6B4A); // Green
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRead ? Colors.white.withOpacity(0.6) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isRead ? null : Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.2), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15, 
                          fontWeight: isRead ? FontWeight.w700 : FontWeight.w900, 
                          color: const Color(0xFF1F6B4A)
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.4),
                ),
                const SizedBox(height: 10),
                Text(
                  date,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
