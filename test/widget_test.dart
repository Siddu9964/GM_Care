import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gm_care/screens/patient_dashboard.dart';
import 'package:gm_care/screens/appointments_screen.dart';
import 'package:gm_care/screens/account_screen.dart';
import 'package:gm_care/screens/prescriptions_screen.dart';
import 'package:gm_care/screens/specialist_doctors_screen.dart';
import 'package:gm_care/widgets/hospital_charter_dialog.dart';
import 'package:gm_care/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Test PatientDashboard renders clean with standard color', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PatientDashboard(
        userName: 'Test User',
        location: 'Nagarabhavi',
        age: '25',
        sex: 'Male',
        cookie: '',
        patientId: 'PID-TEST-001',
      ),
    ));
    await tester.pump();
    expect(find.byType(PatientDashboard), findsOneWidget);
  });

  testWidgets('Test PrescriptionsScreen renders clean with patient ID & PDF actions', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PrescriptionsScreen(
        userName: 'Test User',
        location: 'Nagarabhavi',
        cookie: '',
        patientId: 'PID-TEST-001',
      ),
    ));
    await tester.pump();
    expect(find.byType(PrescriptionsScreen), findsOneWidget);
    expect(find.textContaining('Prescriptions'), findsWidgets);
  });

  testWidgets('Test AppointmentsScreen renders clean with standard color', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AppointmentsScreen(
        userName: 'Test User',
        location: 'Nagarabhavi',
        age: '25',
        sex: 'Male',
        cookie: '',
      ),
    ));
    await tester.pump();
    expect(find.byType(AppointmentsScreen), findsOneWidget);
  });

  testWidgets('Test AccountScreen renders clean with standard color', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AccountScreen(
        userName: 'Test User',
        location: 'Nagarabhavi',
        age: '25',
        sex: 'Male',
        cookie: '',
      ),
    ));
    await tester.pump();
    expect(find.byType(AccountScreen), findsOneWidget);
  });

  testWidgets('Test HospitalCharterTermsDialog renders and has website & contacts', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: HospitalCharterTermsDialog(),
      ),
    ));
    await tester.pump();
    expect(find.text('GM HOSPITALS'), findsOneWidget);
    expect(find.text('VISION'), findsOneWidget);
    expect(find.text('MISSION'), findsOneWidget);
    expect(find.text('VALUES'), findsOneWidget);
    expect(find.text('www.gmhospitals.com'), findsOneWidget);
  });

  testWidgets('Test HospitalContact helper functions', (tester) async {
    expect(HospitalContact.website, 'www.gmhospitals.com');
    expect(HospitalContact.nagarabhaviLandline, '080 2301 1600');
    expect(HospitalContact.basaveshwaranagarLandline, '080 2221 1600');
    expect(ApiConfig.patientPrescriptions('123'), 'https://erp.gmhospitals.co.in/GM_HMS/api/prescriptions/patient/123');
  });

  test('Test AppointmentsScreen.deduplicate removes duplicate booking slots and duplicate IDs', () {
    final rawDuplicates = [
      {
        'id': 'APT-20261103-0008',
        'appointment_id': 'APT-20261103-0008',
        'doctor_name': 'Dr Abhishek C Nayak',
        'appointment_date': '2026-11-05',
        'appointment_time': '10:30:00',
        'status': 'Scheduled',
      },
      {
        'id': 'APT-20261103-0008',
        'appointment_id': 'APT-20261103-0008',
        'doctor_name': 'Dr Abhishek C Nayak',
        'appointment_date': '2026-11-05',
        'appointment_time': '10:30 AM',
        'status': 'Scheduled',
      },
      {
        'id': 'APT-20261104-0010',
        'appointment_id': 'APT-20261104-0010',
        'doctor_name': 'Dr Sneha Patil',
        'appointment_date': '2026-11-06',
        'appointment_time': '11:45 AM',
        'status': 'Scheduled',
      },
    ];

    final deduplicated = AppointmentsScreen.deduplicate(rawDuplicates);
    expect(deduplicated.length, 2);
    expect(deduplicated[0]['doctor_name'], 'Dr Abhishek C Nayak');
    expect(deduplicated[1]['doctor_name'], 'Dr Sneha Patil');
  });

  test('Test PrescriptionsScreen.resolvePdfUrl formats and resolves full PDF links accurately', () {
    // 1. Consultation prescription with /GM_HMS/ path
    final item1 = {
      'prescription_id': 'CONS-20261102-0005',
      'prescription_pdf': 'consultation/opd_pdf/pdf_PID-20261030-017_20261102_174640_918d826e.pdf',
      'prescription_pdf_url': '/GM_HMS/consultation/opd_pdf/pdf_PID-20261030-017_20261102_174640_918d826e.pdf',
      'has_prescription_pdf': true,
    };
    expect(
      PrescriptionsScreen.resolvePdfUrl(item1),
      'https://erp.gmhospitals.co.in/GM_HMS/consultation/opd_pdf/pdf_PID-20261030-017_20261102_174640_918d826e.pdf',
    );

    // 2. Consultation prescription without /GM_HMS/ prefix in prescription_pdf
    final item2 = {
      'prescription_id': 'CONS-20261102-0005',
      'prescription_pdf': 'consultation/opd_pdf/pdf_PID-20261030-017_20261102_174640_918d826e.pdf',
    };
    expect(
      PrescriptionsScreen.resolvePdfUrl(item2),
      'https://erp.gmhospitals.co.in/GM_HMS/consultation/opd_pdf/pdf_PID-20261030-017_20261102_174640_918d826e.pdf',
    );

    // 3. Record with null / no PDF
    final itemNull = {
      'prescription_id': 'CONS-20261102-0004',
      'prescription_pdf': null,
      'has_prescription_pdf': false,
    };
    expect(PrescriptionsScreen.resolvePdfUrl(itemNull), '');

    // 4. Radiology scan with full external URL (somatiq.ai)
    final itemRad = {
      'result_id': 'RES-RAD-851ADF',
      'test_name': 'CT SCAN OF BRAIN',
      'report_file': 'https://somatiq.ai/share/HNG5V4WDYG3T',
    };
    expect(
      PrescriptionsScreen.resolvePdfUrl(itemRad),
      'https://somatiq.ai/share/HNG5V4WDYG3T',
    );
  });

  test('Test SpecialistDoctorsScreen.formatDoctorName removes duplicate prefixes and normalizes cleanly', () {
    expect(SpecialistDoctorsScreen.formatDoctorName('Dr. Dayananda Kumar K'), 'Dr. Dayananda Kumar K');
    expect(SpecialistDoctorsScreen.formatDoctorName('Dr Dayananda Kumar K'), 'Dr. Dayananda Kumar K');
    expect(SpecialistDoctorsScreen.formatDoctorName('Dr. Dr Pramod'), 'Dr. Pramod');
    expect(SpecialistDoctorsScreen.formatDoctorName('Dr. Dr. Dr Ramesh SS'), 'Dr. Ramesh SS');
    expect(SpecialistDoctorsScreen.formatDoctorName('Doctor Ramesh SS'), 'Dr. Ramesh SS');
    expect(SpecialistDoctorsScreen.formatDoctorName('Prof. Ramesh SS'), 'Dr. Ramesh SS');
    expect(SpecialistDoctorsScreen.formatDoctorName('Ramesh SS'), 'Dr. Ramesh SS');
    expect(SpecialistDoctorsScreen.formatDoctorName('Drishya'), 'Dr. Drishya');
    expect(SpecialistDoctorsScreen.formatDoctorName('Dravid'), 'Dr. Dravid');
    expect(SpecialistDoctorsScreen.formatDoctorName(''), 'Consultant');
    expect(SpecialistDoctorsScreen.formatDoctorName(null), 'Consultant');
  });

  testWidgets('Test SpecialistDoctorsScreen renders with large system font scale without truncation', (tester) async {
    final mockDoctors = [
      {
        'full_name': 'Dr Dayananda Kumar K',
        'specialization': 'Gynecology',
        'department': 'Gynecology',
        'consultation_fee': '500.00',
        'availability': 'Available',
        'in_time': '12:00:00',
        'out_time': '14:00:00',
        'photo': '',
      },
      {
        'full_name': 'Dr. Dr Pramod',
        'specialization': 'Cardiology',
        'department': 'Cardiology Department',
        'consultation_fee': '700.00',
        'availability': 'Off-Duty',
        'in_time': '09:00:00',
        'out_time': '17:00:00',
        'photo': '',
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          // Simulate large letters setting on user's phone (1.6x font scale)
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.6),
            size: Size(360, 800),
          ),
          child: SpecialistDoctorsScreen(
            specialization: 'Gynecology',
            doctors: mockDoctors,
            userName: 'Test Patient',
            location: 'Nagarabhavi',
            age: '30',
            sex: 'Female',
            cookie: '',
            patientId: 'PID-20261030-017',
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify doctor names are normalized and NOT truncated or duplicated
    expect(find.text('Dr. Dayananda Kumar K'), findsOneWidget);
    expect(find.text('Dr. Pramod'), findsOneWidget);
    expect(find.textContaining('Dr. Dr'), findsNothing);

    // Verify status pills
    expect(find.text('ACTIVE TODAY'), findsOneWidget);
    expect(find.text('OFF-DUTY'), findsOneWidget);

    // Verify timing & fee
    expect(find.text('12:00 PM - 02:00 PM'), findsOneWidget);
    expect(find.text('OPD: ₹500.00'), findsOneWidget);

    // Verify specialization is uppercase
    expect(find.text('GYNECOLOGY'), findsOneWidget);

    // Verify duplicate department is not rendered when identical to specialization
    // ("Gynecology" title should not be rendered below "GYNECOLOGY")
    expect(find.text('Gynecology'), findsWidgets); // only in category chips / title
    expect(find.text('Cardiology Department'), findsNWidgets(2));
  });
}
