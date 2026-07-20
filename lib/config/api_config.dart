// =============================================================================
// GM CARE — API REFERENCE DOCUMENTATION
// =============================================================================
// Base URL : http://172.21.2.132/GM_HMS/api
// Protocol : HTTP  (switch _scheme → 'https' for production)
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
// URL     : http://172.21.2.132/GM_HMS/api/auth/login/
// AUTH    : None (public)
//
// HEADERS :
//   Content-Type      : application/json
//   X-Hospital-Branch : Nagarabhavi
//
// REQUEST BODY (JSON):
//   {
//     "username" : "john_doe",          ← email / phone / patient ID
//     "password" : "Password@123"
//   }
//
// SUCCESS RESPONSE  →  HTTP 200
//   {
//     "status" : "success",
//     "data"   : {
//       "first_name" : "John",
//       "username"   : "john_doe",
//       "city"       : "Bengaluru",
//       "age"        : 28,
//       "sex"        : "Male"
//     }
//   }
//   ↳ Also sets  Set-Cookie: sessionid=<token>; Path=/; HttpOnly
//
// FAILURE RESPONSE  →  HTTP 400 / 401
//   { "status": "error", "message": "Invalid credentials." }
//
// ─────────────────────────────────────────────────────────────────────────────
// [2] RESET PASSWORD
// ─────────────────────────────────────────────────────────────────────────────
// METHOD  : POST
// URL     : http://172.21.2.132/GM_HMS/api/auth/reset-password/
// AUTH    : None (public)
//
// HEADERS :
//   Content-Type      : application/json
//   X-Hospital-Branch : Nagarabhavi
//
// REQUEST BODY (JSON):
//   {
//     "identifier"   : "john@example.com",   ← email / phone / name
//     "new_password" : "NewPass@456"
//   }
//
// SUCCESS RESPONSE  →  HTTP 200
//   { "status": "success", "message": "Password reset successfully." }
//
// FAILURE RESPONSE  →  HTTP 404
//   { "status": "error", "message": "User not found." }
//
// ─────────────────────────────────────────────────────────────────────────────
// [3] REGISTER PATIENT  (Create Account)
// ─────────────────────────────────────────────────────────────────────────────
// METHOD  : POST
// URL     : http://172.21.2.132/GM_HMS/api/patients/
// AUTH    : None (public)
//
// HEADERS :
//   Content-Type      : application/json
//   X-Hospital-Branch : Nagarabhavi
//
// REQUEST BODY (JSON):
//   {
//     "title"      : "Mr",             ← Mr | Mrs | Ms | Dr | Baby Boy | Baby Girl | Other
//     "first_name" : "John",
//     "last_name"  : "Doe",
//     "sex"        : "Male",           ← Male | Female | Non-Binary | Other
//     "age"        : 28,
//     "aadhar"     : "123456789012",   ← 12-digit Aadhaar number (optional)
//     "phone"      : "9876543210",     ← 10-digit mobile number
//     "email"      : "john@example.com",
//     "password"   : "Password@123"
//   }
//
// SUCCESS RESPONSE  →  HTTP 200 or 201
//   { "success": true, "message": "Patient registered successfully." }
//
// FAILURE RESPONSE  →  HTTP 400
//   { "success": false, "message": "Phone number already exists." }
//
// ─────────────────────────────────────────────────────────────────────────────
// [4] GET PATIENT LIST / SEARCH PATIENT
// ─────────────────────────────────────────────────────────────────────────────
// METHOD  : GET
// URL     : http://172.21.2.132/GM_HMS/api/patients?search=John
// AUTH    : Required (session cookie from login)
//
// HEADERS :
//   Accept            : application/json
//   X-Hospital-Branch : Nagarabhavi
//   Cookie            : sessionid=<token>
//
// QUERY PARAMS:
//   search  →  patient name / phone / ID  (URL-encoded)
//
// URL EXAMPLES:
//   All patients   → http://172.21.2.132/GM_HMS/api/patients
//   Search by name → http://172.21.2.132/GM_HMS/api/patients?search=John
//   Search by phone→ http://172.21.2.132/GM_HMS/api/patients?search=9876543210
//
// SUCCESS RESPONSE  →  HTTP 200
//   {
//     "status" : "success",
//     "data"   : {
//       "data" : [
//         {
//           "first_name" : "John",
//           "last_name"  : "Doe",
//           "age"        : 28,
//           "sex"        : "Male",
//           "phone"      : "9876543210",
//           "email"      : "john@example.com"
//         }
//       ]
//     }
//   }
//
// FAILURE RESPONSE  →  HTTP 401
//   { "detail": "Authentication credentials were not provided." }
//
// ─────────────────────────────────────────────────────────────────────────────
// [5] GET DEPARTMENTS
// ─────────────────────────────────────────────────────────────────────────────
// METHOD  : GET
// URL     : http://172.21.2.132/GM_HMS/api/departments
// AUTH    : Required (session cookie from login)
//
// HEADERS :
//   Accept            : application/json
//   X-Hospital-Branch : Nagarabhavi
//   Cookie            : sessionid=<token>
//
// URL EXAMPLES:
//   http://172.21.2.132/GM_HMS/api/departments
//
// SUCCESS RESPONSE  →  HTTP 200
//   {
//     "status" : "success",
//     "data"   : [
//       { "department_name": "Cardiology"  },
//       { "department_name": "Neurology"   },
//       { "department_name": "Pediatrics"  },
//       { "department_name": "Orthopedics" },
//       { "department_name": "Oncology"    }
//     ]
//   }
//
// FAILURE RESPONSE  →  HTTP 401
//   { "detail": "Authentication credentials were not provided." }
//
// ─────────────────────────────────────────────────────────────────────────────
// [6] GET ALL DOCTORS
// ─────────────────────────────────────────────────────────────────────────────
// METHOD  : GET
// URL     : http://172.21.2.132/GM_HMS/api/doctors
// AUTH    : Required (session cookie from login)
//
// HEADERS :
//   Accept            : application/json
//   X-Hospital-Branch : Nagarabhavi
//   Cookie            : sessionid=<token>
//
// URL EXAMPLES:
//   All doctors → http://172.21.2.132/GM_HMS/api/doctors
//
// SUCCESS RESPONSE  →  HTTP 200
//   {
//     "status" : "success",
//     "data"   : [
//       {
//         "full_name"      : "Dr. Priya Sharma",
//         "specialization" : "Cardiologist",
//         "gender"         : "Female",
//         "availability"   : "Available"     ← "Available" | "Off-Duty"
//       },
//       {
//         "full_name"      : "Dr. Rajan Mehta",
//         "specialization" : "Neurologist",
//         "gender"         : "Male",
//         "availability"   : "Off-Duty"
//       }
//     ]
//   }
//
// FAILURE RESPONSE  →  HTTP 401
//   { "detail": "Authentication credentials were not provided." }
//
// ─────────────────────────────────────────────────────────────────────────────
// [7] GET DOCTORS BY DEPARTMENT  (Filtered)
// ─────────────────────────────────────────────────────────────────────────────
// METHOD  : GET
// URL     : http://172.21.2.132/GM_HMS/api/doctors?department=<DeptName>
// AUTH    : Required (session cookie from login)
//
// HEADERS :
//   Accept            : application/json
//   X-Hospital-Branch : Nagarabhavi
//   Cookie            : sessionid=<token>
//
// QUERY PARAMS:
//   department  →  exact department name (URL-encoded)
//
// URL EXAMPLES:
//   http://172.21.2.132/GM_HMS/api/doctors?department=Cardiology
//   http://172.21.2.132/GM_HMS/api/doctors?department=Neurology
//   http://172.21.2.132/GM_HMS/api/doctors?department=General%20Surgery
//
// SUCCESS RESPONSE  →  HTTP 200
//   {
//     "status" : "success",
//     "data"   : [
//       {
//         "full_name"      : "Dr. Priya Sharma",
//         "specialization" : "Cardiologist",
//         "gender"         : "Female",
//         "availability"   : "Available"
//       }
//     ]
//   }
//
// FAILURE RESPONSE  →  HTTP 401
//   { "detail": "Authentication credentials were not provided." }
//
// =============================================================================
// QUICK TEST SEQUENCE IN POSTMAN
// =============================================================================
//
//  STEP 1 → POST  /auth/login/          (get session cookie)
//  STEP 2 → GET   /departments          (copy cookie from step 1)
//  STEP 3 → GET   /doctors              (list all)
//  STEP 4 → GET   /doctors?department=Cardiology   (filter)
//  STEP 5 → GET   /patients?search=John            (search patient)
//  STEP 6 → POST  /patients/            (register new patient)
//  STEP 7 → POST  /auth/reset-password/ (reset password)
//
// ─────────────────────────────────────────────────────────────────────────────
// [8] UPDATE APPOINTMENT (PUT)
// ─────────────────────────────────────────────────────────────────────────────
// METHOD  : PUT
// URL     : http://172.21.2.132/GM_HMS/api/appointments/{appointment_id}
// AUTH    : Required (session cookie from login)
//
// HEADERS :
//   Content-Type      : application/json
//   Accept            : application/json
//   X-Hospital-Branch : Nagarabhavi
//   Cookie            : sessionid=<token>
//
// REQUEST BODY (JSON) EXAMPLE :
// {
//    "appointment_date": "2026-07-03",
//    "appointment_time": "14:30:00",
//    "doctor_id": "3",
//    "appointment_status": "1"
// }
//
// SUCCESS RESPONSE  →  HTTP 200
// { "status": "success", "message": "Appointment updated successfully", "data": {...} }
//
// =============================================================================

class ApiConfig {
  ApiConfig._(); // prevent instantiation

  // ── Server coordinates ────────────────────────────────────────────────────
  static const String scheme   = 'https';
  static const String serverIp = 'erp.gmhospitals.co.in'; // IP or domain
  
  static const String basePath = '/GM_HMS/api'; // Leading slash

  // ── Base URL ──────────────────────────────────────────────────────────────
  static const String baseUrl = '$scheme://$serverIp$basePath';

  // ── Auth endpoints ────────────────────────────────────────────────────────
  /// POST — /auth/login/
  static const String login         = '$baseUrl/auth/login/';

  /// POST — /auth/reset-password/
  static const String resetPassword = '$baseUrl/auth/reset-password/';

  // ── Patient endpoints ─────────────────────────────────────────────────────
  /// POST — /patients/  (register)
  /// GET  — /patients/  (list all)
  static const String patients      = '$baseUrl/patients/';

  /// GET — /patients?search=<query>
  static String patientSearch(String query) =>
      '$baseUrl/patients?search=${Uri.encodeComponent(query)}';

  /// POST — /patients/{id}/image
  static String patientImageUpload(String patientId) =>
      '$baseUrl/patients/$patientId/image';

  /// Base server URL for images (used to prefix the image path from the database)
  static const String imageBaseUrl = '$scheme://$serverIp';

  // ── Department endpoints ──────────────────────────────────────────────────
  /// GET — /departments
  static const String departments   = '$baseUrl/departments';

  // ── Billing endpoints ───────────────────────────────────────────────────────
  /// GET — /billing/opd  (fetch bills)
  /// GET — /billing/opd/{bill_id} (fetch bill details)
  static const String opdBilling    = '$baseUrl/billing/opd';

  // ── Consultations endpoints ───────────────────────────────────────────────
  static const String consultations = '$baseUrl/consultations';

  // ── Doctor endpoints ──────────────────────────────────────────────────────
  /// GET — /doctors  (all doctors)
  static const String doctors       = '$baseUrl/doctors';

  /// GET — /doctors?department=<dept>  (filtered by department)
  static String doctorsByDepartment(String department) =>
      '$baseUrl/doctors?department=${Uri.encodeComponent(department)}';

  // ── Appointment endpoints ─────────────────────────────────────────────────
  /// POST — /appointments (create new)
  /// GET  — /appointments (list all)
  /// PUT  — /appointments/{id} (update)
  /// DELETE — /appointments/{id} (delete)
  static const String appointments = '$baseUrl/appointments';

  // ── Notification endpoints ────────────────────────────────────────────────
  /// GET — /notifications?doctor_id=<id>
  /// (doctor_id actually acts as recipient_id in the DB for fetching)
  static const String notifications = '$baseUrl/notifications';
}
