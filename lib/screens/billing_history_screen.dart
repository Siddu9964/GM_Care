import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/notification_service.dart';
import 'bill_receipt_screen.dart';

class BillingHistoryScreen extends StatefulWidget {
  final String userName;
  final String location;
  final String cookie;

  const BillingHistoryScreen({
    super.key,
    required this.userName,
    required this.location,
    required this.cookie,
  });

  @override
  State<BillingHistoryScreen> createState() => _BillingHistoryScreenState();
}

class _BillingHistoryScreenState extends State<BillingHistoryScreen> {
  bool _isLoading = true;
  String _errorMsg = '';
  List<dynamic> _bills = [];
  String _patientId = '';

  @override
  void initState() {
    super.initState();
    _fetchBillingHistory();
  }

  Future<void> _fetchBillingHistory() async {
    try {
      final searchRes = await http.get(
        Uri.parse(ApiConfig.patientSearch(widget.userName)),
        headers: {
          'X-Hospital-Branch': widget.location,
          'Accept': 'application/json',
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
      );

      if (searchRes.statusCode != 200) throw Exception("Failed to find patient details.");
      final searchJson = jsonDecode(searchRes.body);
      final patientsList = searchJson['data']?['data'] ?? [];
      
      if (patientsList.isEmpty) {
        if (mounted) setState(() { _isLoading = false; _errorMsg = "No bills available."; });
        return;
      }
      
      _patientId = patientsList[0]['patient_id'] ?? '';
      if (_patientId.isEmpty) throw Exception("Invalid Patient ID.");

      final billsRes = await http.get(
        Uri.parse('${ApiConfig.opdBilling}?patient_id=$_patientId'),
        headers: {
          'X-Hospital-Branch': widget.location,
          'Accept': 'application/json',
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
      );

      if (billsRes.statusCode == 200) {
        final billsJson = jsonDecode(billsRes.body);
        final fetchedBills = billsJson['data'] ?? [];
        
        // Trigger a real billing alert notification if there are pending bills
        final pendingCount = fetchedBills.where((b) => b['payment_status']?.toString().toUpperCase() == 'PENDING').length;
        if (pendingCount > 0) {
           NotificationService().showBillingAlert(
             title: 'Pending Invoices',
             body: 'You have $pendingCount unpaid bill(s) pending for your recent visits.',
           );
        }

        if (mounted) {
          setState(() {
            _bills = fetchedBills;
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to load bills.");
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMsg = e.toString(); });
    }
  }

  void _openReceipt(String billId) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillReceiptScreen(
          billId: billId,
          location: widget.location,
          cookie: widget.cookie,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFE6), // Canvas background
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Premium Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: const Icon(Icons.arrow_back, color: Color(0xFF1F6B4A), size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Billing & Invoices",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A), letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "YOUR PAYMENT HISTORY",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF1F6B4A).withOpacity(0.5), letterSpacing: 1.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            // 2. Billing List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1F6B4A)))
                  : _errorMsg.isNotEmpty
                      ? Center(child: Text(_errorMsg, style: const TextStyle(color: Colors.red)))
                      : _bills.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                              physics: const BouncingScrollPhysics(),
                              itemCount: _bills.length,
                              itemBuilder: (context, index) {
                                return _AnimatedBillCard(
                                  index: index,
                                  bill: _bills[index],
                                  onTap: () => _openReceipt(_bills[index]['bill_id']),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFF1F6B4A).withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Icon(Icons.receipt_long_rounded, size: 64, color: const Color(0xFF1F6B4A).withOpacity(0.3)),
          ),
          const SizedBox(height: 24),
          const Text(
            "No billing history found",
            style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            "Your invoices will appear here once generated.",
            style: TextStyle(fontWeight: FontWeight.w600, color: const Color(0xFF1F6B4A).withOpacity(0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBillCard extends StatefulWidget {
  final int index;
  final dynamic bill;
  final VoidCallback onTap;

  const _AnimatedBillCard({
    required this.index,
    required this.bill,
    required this.onTap,
  });

  @override
  State<_AnimatedBillCard> createState() => _AnimatedBillCardState();
}

class _AnimatedBillCardState extends State<_AnimatedBillCard> with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnimation = Tween<double>(begin: 60, end: 0).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
    
    Future.delayed(Duration(milliseconds: 100 + (widget.index * 100)), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.bill['payment_status']?.toUpperCase() ?? 'PENDING';
    final isPaid = status == 'PAID';
    final dateStr = widget.bill['bill_date'] ?? 'N/A';
    final amount = widget.bill['grand_total'] ?? '0.00';
    final doctorName = widget.bill['doctor_name'] ?? 'Hospital Services';

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1F6B4A).withOpacity(0.04), 
                blurRadius: 24, 
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Status and Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPaid ? const Color(0xFFE6F4F1) : const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEA580C),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: isPaid ? const Color(0xFF065F46) : const Color(0xFF9A3412),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1F6B4A).withOpacity(0.4)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Middle Row: Title
              Text(
                doctorName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A), letterSpacing: -0.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                "Outpatient Consultation",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1F6B4A).withOpacity(0.5)),
              ),
              const SizedBox(height: 24),
              
              // Bottom Row: Price and Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Amount",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF1F6B4A).withOpacity(0.5), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "₹$amount",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: Color(0xFF1F6B4A), letterSpacing: -1.0),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EFE6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text("View Receipt", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1F6B4A))),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1F6B4A)),
                      ],
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
}
