import 'package:flutter/services.dart';
// =============================================================================
// GM CARE — API REFERENCE DOCUMENTATION
// =============================================================================
// Base URL : http://172.21.67.185/GM_HMS/api   (testing server)
//
// COMMON HEADERS (required on EVERY request)
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  Content-Type      : application/json                                   │
// │  Accept            : application/json                                   │
// │  X-Hospital-Branch : Nagarabhavi  │  Basaveshwaranagar                  │
// │  Cookie            : <session_cookie>  ← from login response (auth'd)  │
// └─────────────────────────────────────────────────────────────────────────┘
//
// BRANCH VALUES
//   "Nagarabhavi"         → 611 & 612, Nagarabhavi Main Road, Bengaluru-560072
//   "Basaveshwaranagar"   → #335, 8th Main, 3rd Stage, Bengaluru-560079
//
// =============================================================================
//
// ─────────────────────────────────────────────────────────────────────────────
// [1] LOGIN
// ─────────────────────────────────────────────────────────────────────────────
// METHOD  : POST
// URL     : /auth/login/
// AUTH    : None (public)
//
// REQUEST BODY (JSON):
//   { "username": "9876543210", "password": "Password@123" }
//
// SUCCESS RESPONSE  →  HTTP 200
//   { "status": "success", "data": { "first_name": "John", ... } }
//   ↳ Also sets  Set-Cookie: sessionid=<token>; Path=/; HttpOnly
//
// FAILURE RESPONSE  →  HTTP 400 / 401
//   { "status": "error", "message": "Invalid credentials." }
//
// ─────────────────────────────────────────────────────────────────────────────
// [2] RESET / SET PASSWORD
// ─────────────────────────────────────────────────────────────────────────────
// METHOD  : POST
// URL     : /auth/reset-password/
//
// REQUEST BODY (JSON):
//   { "identifier": "9876543210", "new_password": "NewPass@456" }
//
// SUCCESS RESPONSE  →  HTTP 200
//   { "status": "success", "message": "Password reset successfully." }
//
// ─────────────────────────────────────────────────────────────────────────────
// [3] REGISTER PATIENT
// ─────────────────────────────────────────────────────────────────────────────
// METHOD  : POST
// URL     : /patients/
//
// REQUEST BODY (JSON):
//   { "title": "Mr", "first_name": "John", "last_name": "Doe",
//     "sex": "Male", "age": 28, "phone": "9876543210",
//     "email": "john@example.com", "password": "Password@123" }
//
// SUCCESS RESPONSE  →  HTTP 200 or 201
//   { "success": true, "message": "Patient registered successfully." }
//
// FAILURE RESPONSE  →  HTTP 400
//   { "success": false, "message": "Phone number already exists." }
//
// ─────────────────────────────────────────────────────────────────────────────
// [4] SEARCH PATIENT
// ─────────────────────────────────────────────────────────────────────────────
// METHOD  : GET
// URL     : /patients?search=<phone>
//
// SUCCESS RESPONSE  →  HTTP 200
//   { "status": "success", "data": { "data": [ { "patient_id": ..., "phone": ...,
//     "first_name": ..., "has_password": true|false } ] } }
//
// ─────────────────────────────────────────────────────────────────────────────
// [5] GET DEPARTMENTS
// ─────────────────────────────────────────────────────────────────────────────
// METHOD  : GET  |  URL : /departments
//
// ─────────────────────────────────────────────────────────────────────────────
// [6] GET ALL DOCTORS
// ─────────────────────────────────────────────────────────────────────────────
// METHOD  : GET  |  URL : /doctors
//
// ─────────────────────────────────────────────────────────────────────────────
// [7] GET DOCTORS BY DEPARTMENT
// ─────────────────────────────────────────────────────────────────────────────
// METHOD  : GET  |  URL : /doctors?department=<DeptName>
//
// ─────────────────────────────────────────────────────────────────────────────
// [8] UPDATE APPOINTMENT
// ─────────────────────────────────────────────────────────────────────────────
// METHOD  : PUT
// URL     : /appointments/{appointment_id}
//
// REQUEST BODY (JSON):
//   { "appointment_date": "2026-07-03", "appointment_time": "14:30:00",
//     "doctor_id": "3", "appointment_status": "1" }
//
// =============================================================================

class ApiConfig {
  ApiConfig._(); // prevent instantiation

  // ── Testing Server (Actual Local IP: 172.21.2.130) ───────────────────────
  static const String scheme   = 'http';
  static const String serverIp = '172.21.2.146';

  static const String basePath = '/GM_HMS/api';

  // ── Base URLs ─────────────────────────────────────────────────────────────
  // static const String baseUrl      = 'http://172.21.2.146/GM_HMS/api';
  static const String baseUrl      = 'https://erp.gmhospitals.co.in/GM_HMS/api';
  static const String imageBaseUrl = 'https://erp.gmhospitals.co.in';

  // ── Auth endpoints ────────────────────────────────────────────────────────
  /// POST — /auth/login/
  static const String login         = '$baseUrl/auth/login/';

  /// POST — /auth/reset-password/
  static const String resetPassword = '$baseUrl/auth/reset-password/';

  // ── Patient endpoints ─────────────────────────────────────────────────────
  /// POST — /patients/  (register)
  /// GET  — /patients/  (list all)
  static const String patients      = '$baseUrl/patients/';

  /// PUT — /patients/{id} (update profile)
  static String patientUpdate(String pid) => '$baseUrl/patients/$pid';

  /// GET — /patients/{id}/lab-results
  static String patientLabResults(String pid) => '$baseUrl/patients/$pid/lab-results';

  /// GET — /patients?search=<query>
  static String patientSearch(String query) =>
      '$baseUrl/patients?search=${Uri.encodeComponent(query)}';

  /// POST — /patients/{id}/image
  static String patientImageUpload(String patientId) =>
      '$baseUrl/patients/$patientId/image';

  // ── Department endpoints ──────────────────────────────────────────────────
  /// GET — /departments
  static const String departments   = '$baseUrl/departments';

  // ── Billing endpoints ─────────────────────────────────────────────────────
  /// GET — /billing/opd
  /// GET — /billing/opd/{bill_id}
  static const String opdBilling    = '$baseUrl/billing/opd';

  // ── Prescriptions endpoints ───────────────────────────────────────────────
  /// GET — /prescriptions/patient/{patient_id}
  static String patientPrescriptions(String patientId) =>
      '$baseUrl/prescriptions/patient/$patientId';

  // ── Consultations endpoints ───────────────────────────────────────────────
  /// GET — /consultations?patient_id=<pid>
  static const String consultations = '$baseUrl/consultations';

  // ── Doctor endpoints ──────────────────────────────────────────────────────
  /// GET — /doctors
  static const String doctors       = '$baseUrl/doctors';

  /// GET — /doctors?department=<dept>
  static String doctorsByDepartment(String department) =>
      '$baseUrl/doctors?department=${Uri.encodeComponent(department)}';

  // ── Appointment endpoints ─────────────────────────────────────────────────
  /// POST / GET / PUT / DELETE — /appointments
  static const String appointments  = '$baseUrl/appointments';

  // ── Notification endpoints ────────────────────────────────────────────────
  /// GET  — /notifications?doctor_id=<id>
  /// POST — /notifications/mark-read
  static const String notifications = '$baseUrl/notifications';
}

/// Official Hospital Contacts & Branch Helplines
class HospitalContact {
  HospitalContact._();

  static const String website = 'www.gmhospitals.com';

  // Nagarabhavi Branch
  static const String nagarabhaviName = 'GM Hospitals, Nagarabhavi';
  static const String nagarabhaviAddress = '611 & 612, Nagarabhavi Main Road, Bengaluru - 560072';
  static const String nagarabhaviLandline = '080 2301 1600';
  static const String nagarabhaviMobile = '+91 99000 35235';
  static const String nagarabhaviDisplay = '080 2301 1600, +91 99000 35235';

  // Basaveshwaranagar Branch
  static const String basaveshwaranagarName = 'GM Hospitals, Basaveshwaranagar';
  static const String basaveshwaranagarAddress = '#335, 8th Main, 3rd Stage, 4th Block, Basaveshwaranagar, Bengaluru - 560079';
  static const String basaveshwaranagarLandline = '080 2221 1600';
  static const String basaveshwaranagarMobile = '+91 99000 03527';
  static const String basaveshwaranagarDisplay = '080 2221 1600, +91 99000 03527';

  // National Ambulance / Emergency
  static const String nationalAmbulance = '108 / 112 (Toll Free)';

  /// Opens official website in default browser via Android intent
  static Future<void> openWebsite([String url = 'https://gmhospitals.com/']) async {
    try {
      const channel = MethodChannel('com.gmcare.hospital/calendar');
      await channel.invokeMethod('openUrl', {'url': url});
    } catch (_) {
      try {
        await Clipboard.setData(ClipboardData(text: url));
      } catch (_) {}
    }
  }

  /// Opens dialer with phone number prefilled
  static Future<void> callPhone(String phone) async {
    try {
      const channel = MethodChannel('com.gmcare.hospital/calendar');
      await channel.invokeMethod('openDialer', {'phone': phone});
    } catch (_) {
      try {
        await Clipboard.setData(ClipboardData(text: phone));
      } catch (_) {}
    }
  }
}
