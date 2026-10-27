import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

import 'patient_dashboard.dart';

class TestDataScreen extends StatefulWidget {
  final String patientId;
  final String location;
  final String cookie;
  final String userName;

  const TestDataScreen({
    super.key,
    required this.patientId,
    required this.location,
    required this.cookie,
    this.userName = '',
  });

  @override
  State<TestDataScreen> createState() => _TestDataScreenState();
}

class _TestDataScreenState extends State<TestDataScreen> {
  bool _isLoading = true;
  String _errorMsg = '';
  List<dynamic> _testResults = [];

  @override
  void initState() {
    super.initState();
    _fetchTestResults();
  }

  Future<void> _fetchTestResults() async {
    try {
      String effectivePid = widget.patientId.trim();
      if (effectivePid.isEmpty && widget.userName.trim().isNotEmpty) {
        final searchRes = await http.get(
          Uri.parse(ApiConfig.patientSearch(widget.userName)),
          headers: {
            'X-Hospital-Branch': widget.location,
            'Accept': 'application/json',
            if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
          },
        );
        if (searchRes.statusCode == 200) {
          final sJson = jsonDecode(searchRes.body);
          final pList = sJson['data']?['data'] ?? [];
          if (pList is List && pList.isNotEmpty) {
            effectivePid = pList[0]['patient_id']?.toString() ?? '';
          }
        }
      }

      if (effectivePid.isEmpty) {
        throw Exception("Patient records could not be found for lab results.");
      }

      final response = await http.get(
        Uri.parse(ApiConfig.patientLabResults(effectivePid)),
        headers: {
          'X-Hospital-Branch': widget.location,
          'Accept': 'application/json',
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
      );

      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          if (mounted) {
            setState(() {
              _testResults = jsonResp['data'] ?? [];
              _isLoading = false;
            });
          }
        } else {
          throw Exception(jsonResp['message'] ?? "Failed to load test data.");
        }
      } else if (response.statusCode == 401) {
        throw Exception("Session expired or unauthorized. Please log out and log in again.");
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          String errorText = e.toString();
          if (errorText.startsWith('Exception: ')) {
            errorText = errorText.substring(11); // Remove the 'Exception: ' prefix
          }
          _errorMsg = errorText;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFE6),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
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
                              patientId: widget.patientId,
                            ),
                          ),
                        );
                      }
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
                          "Test Data",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A), letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "YOUR LAB RESULTS",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF1F6B4A).withOpacity(0.5), letterSpacing: 1.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1F6B4A)))
                  : _errorMsg.isNotEmpty
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(_errorMsg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        ))
                      : _testResults.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                              physics: const BouncingScrollPhysics(),
                              itemCount: _testResults.length,
                              itemBuilder: (context, index) {
                                final item = _testResults[index];
                                return _buildTestCard(item);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard(dynamic item) {
    String dateStr = item['created_at'] ?? 'Unknown Date';
    if (dateStr.length > 10) {
      dateStr = dateStr.substring(0, 10);
    }
    
    String testName = item['test_name'] ?? 'General Lab Report';

    String resultDataText = item['result_data']?.toString() ?? '';
    List<dynamic> parsedData = [];
    bool isJsonList = false;
    
    try {
      if (resultDataText.trim().startsWith('[')) {
        parsedData = jsonDecode(resultDataText);
        isJsonList = true;
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F6B4A).withOpacity(0.06), 
            blurRadius: 24, 
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF1F6B4A).withOpacity(0.04),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: const Color(0xFF1F6B4A).withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: const Icon(Icons.science_rounded, color: Color(0xFF1F6B4A), size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          testName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F6B4A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dateStr,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1F6B4A).withOpacity(0.6)),
                  ),
                ),
              ],
            ),
          ),
          
          // Card Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: isJsonList && parsedData.isNotEmpty
                ? _buildResultsTable(parsedData)
                : _buildRawTextResult(resultDataText),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsTable(List<dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8F1ED)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(3.5),
            1: FlexColumnWidth(2.0),
            2: FlexColumnWidth(2.0),
            3: FlexColumnWidth(2.5),
          },
          border: TableBorder(
            horizontalInside: BorderSide(color: const Color(0xFFE8F1ED), width: 1),
            verticalInside: BorderSide(color: const Color(0xFFE8F1ED), width: 1),
          ),
          children: [
            // Table Header
            TableRow(
              decoration: const BoxDecoration(
                color: Color(0xFFF2F8F5),
              ),
              children: [
                _buildTableCell("Test Name", isHeader: true, align: TextAlign.left),
                _buildTableCell("Result", isHeader: true, align: TextAlign.center),
                _buildTableCell("Unit", isHeader: true, align: TextAlign.center),
                _buildTableCell("Normal Range", isHeader: true, align: TextAlign.right),
              ],
            ),
            // Table Rows
            ...data.map((metric) {
              if (metric is! Map) return const TableRow(children: [SizedBox(), SizedBox(), SizedBox(), SizedBox()]);
              
              String name = metric['name']?.toString() ?? '-';
              String value = metric['value']?.toString() ?? '-';
              String unit = metric['unit']?.toString() ?? '-';
              String range = metric['range']?.toString() ?? '-';
              if (unit.trim().isEmpty) unit = '-';
              if (range.trim().isEmpty) range = '-';

              // Out of range logic
              Color valueColor = const Color(0xFF2C3E35);
              bool isOutOfRange = false;
              try {
                if (value != '-' && range != '-' && range.contains('-')) {
                  double val = double.parse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
                  var parts = range.split('-');
                  if (parts.length == 2) {
                    double min = double.parse(parts[0].replaceAll(RegExp(r'[^0-9.]'), ''));
                    double max = double.parse(parts[1].replaceAll(RegExp(r'[^0-9.]'), ''));
                    if (val < min || val > max) {
                      valueColor = Colors.red.shade700;
                      isOutOfRange = true;
                    }
                  }
                }
              } catch (_) {}

              return TableRow(
                children: [
                  _buildTableCell(name, align: TextAlign.left, isBold: true),
                  _buildTableCell(value, align: TextAlign.center, textColor: valueColor, isBold: isOutOfRange),
                  _buildTableCell(unit, align: TextAlign.center),
                  _buildTableCell(range, align: TextAlign.right),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, TextAlign align = TextAlign.left, Color? textColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isHeader ? 12 : 13,
          fontWeight: isHeader ? FontWeight.w800 : (isBold ? FontWeight.w700 : FontWeight.w500),
          color: textColor ?? (isHeader ? const Color(0xFF1F6B4A) : const Color(0xFF4B5563)),
        ),
      ),
    );
  }

  Widget _buildRawTextResult(String text) {
    if (text.isEmpty) text = "No data available";
    
    try {
      if (text.trim().startsWith('{') || text.trim().startsWith('[')) {
        final parsedJson = jsonDecode(text);
        text = const JsonEncoder.withIndent('  ').convert(parsedJson);
      }
    } catch (_) {}

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFF374151)),
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
            child: Icon(Icons.science_outlined, size: 64, color: const Color(0xFF1F6B4A).withOpacity(0.3)),
          ),
          const SizedBox(height: 24),
          const Text(
            "No test data found",
            style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            "Your lab results will appear here.",
            style: TextStyle(fontWeight: FontWeight.w600, color: const Color(0xFF1F6B4A).withOpacity(0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
