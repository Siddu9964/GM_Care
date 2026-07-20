# Implement "My Reports" Section

This plan outlines the steps to build the "My Reports" feature, placing it prominently above the Billing History on the Patient Dashboard, and allowing users to view full patient consultation details.

## Proposed Changes

### 1. API Configuration
- Add the `/api/consultations` endpoint to `ApiConfig.dart`.

### 2. My Reports Dashboard Section
- **Create `my_reports_section.dart`**: Similar to the Billing History grid, this will be a sleek, horizontally scrolling list of cards directly on the dashboard.
- **Data Fetching**: It will fetch the user's `PID` using the patient search endpoint, and then query the `GET /api/consultations?patient_id={PID}` endpoint.
- **Filtering**: We will filter the results to only show completed consultations where `status == 0` or `status == '0'`.

### 3. Patient Dashboard Integration
- **Modify `patient_dashboard.dart`**: Add `MyReportsSection` right above the new `BillingHistorySection` and remove the "My Reports" button from the Quick Action Grid (since it will now have its own dedicated section).

### 4. Full Report Details Screen
- **Create `report_detail_screen.dart`**: A beautiful, detailed view when a user clicks on a report card.
- **Data Binding**:
  - Display Patient ID, Doctor ID, and Consultation Date/Time.
  - Parse and render the `vital_signs` JSON data cleanly.
  - Display the `soap_objective` (Physical examination findings) and `soap_plan` (Treatment plan/prescriptions).
  - Check the `prescription_image` column. If a valid path is returned, render the image over the network using `Image.network` and the server's base URL.

## User Review Required
> [!IMPORTANT]
> The prescription image path stored in the database usually needs to be prefixed with the server's base URL (e.g., `http://172.21.3.60/GM_HMS/uploads/xxx`). I will assume the standard uploads path, but if the image fails to load, we may need to adjust the prefix string. Is this acceptable?

## Verification Plan
1. Launch the Flutter app and verify the "My Reports" section appears above Billing History.
2. Ensure only completed consultations (status 0) are shown.
3. Click a report card and verify that the full details screen successfully parses the vitals, SOAP notes, and attempts to load the prescription image.
