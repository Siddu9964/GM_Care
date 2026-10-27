import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class BillReceiptScreen extends StatefulWidget {
  final String billId;
  final String location;
  final String cookie;

  const BillReceiptScreen({
    super.key,
    required this.billId,
    required this.location,
    required this.cookie,
  });

  @override
  State<BillReceiptScreen> createState() => _BillReceiptScreenState();
}

class _BillReceiptScreenState extends State<BillReceiptScreen> {
  bool _isLoading = true;
  String _errorMsg = '';
  Map<String, dynamic>? _billDetails;

  @override
  void initState() {
    super.initState();
    _fetchBillDetails();
  }

  Future<void> _fetchBillDetails() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.opdBilling}/${widget.billId}'),
        headers: {
          'X-Hospital-Branch': widget.location,
          'Accept': 'application/json',
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _billDetails = json['data'];
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to load bill details");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // --- Helper Methods to Format Data ---
  String _formatAmount(dynamic amount) {
    if (amount == null) return "0.00";
    double val = double.tryParse(amount.toString()) ?? 0.0;
    return val.toStringAsFixed(2);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "N/A";
    try {
      DateTime dt = DateTime.parse(dateStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}";
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateTimeNow() {
    DateTime now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String ampm = now.hour >= 12 ? 'PM' : 'AM';
    int h = now.hour > 12 ? now.hour - 12 : now.hour;
    if (h == 0) h = 12;
    return "${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}, ${h.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $ampm";
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "";
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return "${parts[0]}:${parts[1]}";
      }
    } catch (_) {}
    return timeStr;
  }

  String _numberToWords(double number) {
    // Simplified number to words for UI mockup. In production, use a package like 'number_to_words'.
    if (number == 0) return "Zero Rupees Only";
    return "Rupees ${_formatAmount(number)} Only"; // Fallback text to mimic the box
  }

  // --- UI Builders ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EAE3), // Light cream background from image
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text("Receipt", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Preparing receipt for printing..."),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Sharing receipt link..."),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg.isNotEmpty
              ? Center(child: Text(_errorMsg, style: const TextStyle(color: Colors.red)))
              : _buildReceiptSheet(),
    );
  }

  Widget _buildReceiptSheet() {
    final b = _billDetails!;
    final isPaid = b['payment_status'] == 'Paid';
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "GM Hospital",
                        style: TextStyle(color: Color(0xFF166534), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.location == 'Nagarabhavi' 
                          ? "611 & 612, Nagarabhavi Main Rd, Vinayaka Layout,\nPapreddy Palya, 2nd Stage, Naagarabhaavi,\nBengaluru, Karnataka 560072\nOPD Billing Department"
                          : "#335, 8th Main, 3rd Stage, 4th Block,\nBasaveshwaranagar, Bengaluru, Karnataka 560079\nOPD Billing Department",
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "PAYMENT RECEIPT",
                      style: TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b['bill_id'] ?? '',
                      style: const TextStyle(color: Color(0xFF0F766E), fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_formatDate(b['bill_date'])} - ${_formatTime(b['bill_time'])}",
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            Stack(
              children: [
                const Divider(color: Color(0xFF166534), thickness: 1.5),
                if (isPaid) 
                  Positioned(
                    right: 20,
                    top: -10,
                    child: Transform.rotate(
                      angle: -0.2,
                      child: Text(
                        "PAID",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF166534).withOpacity(0.15),
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  )
              ],
            ),
            const SizedBox(height: 16),

            // Patient Meta Grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  bool isWide = constraints.maxWidth > 400;
                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildMetaRow("PATIENT", b['patient_name']?.toString().toUpperCase() ?? ''),
                              const SizedBox(height: 8),
                              _buildMetaRow("PHONE", b['patient_phone'] ?? ''),
                              const SizedBox(height: 8),
                              _buildMetaRow("APPOINTMENT", b['appointment_id'] ?? 'Walk-In'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              _buildMetaRow("PATIENT ID", b['patient_id'] ?? ''),
                              const SizedBox(height: 8),
                              _buildMetaRow("DOCTOR", b['doctor_name'] ?? 'Hospital Services'),
                              const SizedBox(height: 8),
                              _buildMetaRow("CREATED BY", b['created_by'] ?? 'System'),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildMetaRow("PATIENT", b['patient_name']?.toString().toUpperCase() ?? ''),
                        const SizedBox(height: 8),
                        _buildMetaRow("PATIENT ID", b['patient_id'] ?? ''),
                        const SizedBox(height: 8),
                        _buildMetaRow("PHONE", b['patient_phone'] ?? ''),
                        const SizedBox(height: 8),
                        _buildMetaRow("DOCTOR", b['doctor_name'] ?? 'Hospital Services'),
                        const SizedBox(height: 8),
                        _buildMetaRow("APPOINTMENT", b['appointment_id'] ?? 'Walk-In'),
                        const SizedBox(height: 8),
                        _buildMetaRow("CREATED BY", b['created_by'] ?? 'System'),
                      ],
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 24),

            // Billing Items Table
            const Text("BILLING ITEMS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1)),
            const SizedBox(height: 8),
            _buildBillingItemsTable(b['items'] ?? []),
            
            const SizedBox(height: 16),
            
            // Subtotal Section
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 200,
                  child: Column(
                    children: [
                      _buildSummaryRow("Subtotal", "₹${_formatAmount(b['subtotal'])}", false),
                      const SizedBox(height: 6),
                      _buildSummaryRow("Discount", "₹${_formatAmount(b['discount_amount'])}", false),
                      const SizedBox(height: 8),
                      const Divider(color: Color(0xFF166534), thickness: 1.5, height: 1),
                      const SizedBox(height: 8),
                      _buildSummaryRow("Receipt Amount", "₹${_formatAmount(b['grand_total'])}", true),
                      const SizedBox(height: 6),
                      _buildSummaryRow("Payment Mode", b['payment_mode'] ?? 'Cash', false, true),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),

            // Amount in Words
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4), // Light green tint
                border: Border.all(color: const Color(0xFF86EFAC)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Text("AMOUNT IN WORDS: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                  Expanded(
                    child: Text(
                      _numberToWords(double.tryParse(b['grand_total'].toString()) ?? 0.0),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Receipt Details Table
            const Text("RECEIPT DETAILS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1)),
            const SizedBox(height: 8),
            _buildReceiptTable(b['payments'] ?? []),
            
            const SizedBox(height: 40),
            
            // Footer
            const Divider(color: Color(0xFFCBD5E1)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Printed on: ${_formatDateTimeNow()}", style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      Text("Printed by: ${b['created_by'] ?? 'System'}", style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 16),
                      const Text("Thank you for choosing GM Hospital.", style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                      const Text("This is a computer-generated bill and does not require a signature.", style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 100,
                  padding: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFF64748B))),
                  ),
                  child: const Center(child: Text("Authorized Signatory", style: TextStyle(fontSize: 9, color: Color(0xFF64748B)), textAlign: TextAlign.center)),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        ),
      ],
    );
  }

  Widget _buildBillingItemsTable(List<dynamic> items) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF166534), // Dark Green
            child: Row(
              children: const [
                SizedBox(width: 20, child: Text("#", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("DESCRIPTION", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text("QTY", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("RATE (₹)", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("DISCOUNT (₹)", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("AMOUNT (₹)", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          // Table Rows
          ...items.asMap().entries.map((entry) {
            int idx = entry.key + 1;
            var item = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 20, child: Text(idx.toString(), style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                  Expanded(
                    flex: 3, 
                    child: Text("${item['item_name']} ${item['item_code'] != null ? '(${item['item_code']})' : ''}", style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B)))
                  ),
                  Expanded(flex: 1, child: Text(_formatAmount(item['quantity']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text("₹${_formatAmount(item['unit_price'])}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text("₹${_formatAmount(item['discount_amount'])}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text("₹${_formatAmount(item['total_price'])}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isBold, [bool isGreen = false]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isBold ? 12 : 11, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: isGreen ? const Color(0xFF166534) : const Color(0xFF64748B))),
        Text(value, style: TextStyle(fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: isGreen ? const Color(0xFF166534) : const Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildReceiptTable(List<dynamic> payments) {
    if (payments.isEmpty) {
      return const Text("No payment records found.", style: TextStyle(fontSize: 11, color: Color(0xFF64748B)));
    }
    
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF166534), // Dark Green
            child: Row(
              children: const [
                SizedBox(width: 20, child: Text("#", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("RECEIPT NO.", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("DATE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("MODE OF PAYMENT", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("AMOUNT (₹)", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          // Table Rows
          ...payments.asMap().entries.map((entry) {
            int idx = entry.key + 1;
            var p = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 20, child: Text(idx.toString(), style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text(p['receipt_no'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B)))),
                  Expanded(flex: 3, child: Text(_formatDate(p['payment_date']), style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text(p['payment_mode'] ?? 'Cash', style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text("₹${_formatAmount(p['amount'])}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
