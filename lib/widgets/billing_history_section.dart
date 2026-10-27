import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../screens/billing_history_screen.dart';
import '../screens/bill_receipt_screen.dart';

class BillingHistorySection extends StatefulWidget {
  final String userName;
  final String location;
  final String cookie;

  const BillingHistorySection({
    super.key,
    required this.userName,
    required this.location,
    required this.cookie,
  });

  @override
  State<BillingHistorySection> createState() => _BillingHistorySectionState();
}

class _BillingHistorySectionState extends State<BillingHistorySection> {
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
        if (mounted) {
          setState(() {
            _bills = billsJson['data'] ?? [];
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
    if (_bills.isEmpty && !_isLoading && _errorMsg.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Billing History",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A)),
            ),
            if (_bills.isNotEmpty)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BillingHistoryScreen(
                        userName: widget.userName,
                        location: widget.location,
                        cookie: widget.cookie,
                      ),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      "See All",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F6B4A)),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF1F6B4A)),
                  ],
                ),
              )
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140, 
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1F6B4A)))
              : _errorMsg.isNotEmpty
                  ? Center(child: Text(_errorMsg, style: const TextStyle(color: Color(0xFF1F6B4A))))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _bills.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final bill = _bills[index];
                        final status = bill['payment_status']?.toUpperCase() ?? 'PENDING';
                        final isPaid = status == 'PAID';
                        final dateStr = bill['bill_date'] ?? 'N/A';
                        final amount = bill['grand_total'] ?? '0.00';

                        return InkWell(
                          onTap: () => _openReceipt(bill['bill_id']),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 150,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFDED8CB)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1F6B4A).withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                Positioned(
                                  top: -20,
                                  right: -20,
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1F6B4A).withValues(alpha: 0.04),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isPaid ? const Color(0xFF1F6B4A).withValues(alpha: 0.1) : const Color(0xFFF3EFE6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1F6B4A),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      "₹$amount",
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF143B2A)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF5A6E64)),
                                    ),
                                    const SizedBox(height: 8),
                                    const Align(
                                      alignment: Alignment.bottomRight,
                                      child: Icon(Icons.receipt_long_outlined, color: Color(0xFF1F6B4A), size: 18),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
