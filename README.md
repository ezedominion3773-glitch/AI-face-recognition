# AI-Powered Face Recognition & Access Control System

A complete biometric access-control system matching the design described in the seminar report **"Design and Implementation of an Artificial Intelligence-Powered Mobile Application for Face Recognition and Access Control" (Ugwu, Ikenna, CS/2022/1253, Caritas University)**.

---

## 🚀 System Architecture

1. **Backend API (Python/FastAPI)**: Serves endpoints for user enrollment, real-time face matching, liveness checking (anti-spoofing), and audit logging.
2. **Database (PostgreSQL + pgvector)**: Stores users, 128-dimensional biometric embeddings, and audit logs. Leverages pgvector's HNSW index for high-speed similarity search.
3. **Mobile Client (Flutter)**: A gorgeous dark-themed application with role-based navigation. Features a sci-fi face scanning overlay for check-in scans, and a management console for administrators.

---

## 🛠️ Getting Started

### 1. Prerequisite Checklist

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (recommended, handles all PostgreSQL + pgvector + Python C++ compiler issues seamlessly)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (if running the mobile client locally)
- A webcam / camera connected to your test machine

---

### 2. Run the Backend API

Using Docker Compose is the easiest way to launch the database and the API:

```bash
cd backend
# Build the containers and launch them in the background
docker-compose up --build -d
```

This starts:
- **Database**: PostgreSQL with `pgvector` extension listening on port `5432`.
- **Backend API**: FastAPI application listening on port `8000`.

#### Seed Default Admin User
After starting the backend, run the database seed script to create the default administrator user:

```bash
docker-compose exec backend python seed_admin.py
```

*Default Credentials:*
- **Email**: `admin@system.com`
- **Password**: `admin123`

---

### 3. Run the Mobile Client

1. Navigate to the mobile directory:
   ```bash
   cd mobile
   ```
2. Retrieve packages:
   ```bash
   flutter pub get
   ```
3. Run on a connected emulator or physical device:
   ```bash
   flutter run
   ```

*Note: For Android Emulator, `mobile/lib/config/api_config.dart` is pre-configured to use `http://10.0.2.2:8000` to access localhost.*

---

## ⚙️ Configuration Variables & Trade-offs

Configuration variables are defined in `backend/.env`. The most critical variable is the face recognition match threshold:

- `MATCH_THRESHOLD` (Default: `0.6`):
  - Represents the maximum Euclidean distance between two face embeddings to be considered a match.
  - **FAR vs. FRR Trade-off**:
    - **Lowering the threshold** (e.g., `0.45`): Makes the system **stricter**. It dramatically reduces the **False Acceptance Rate (FAR)** (impostors getting in) but increases the **False Rejection Rate (FRR)** (valid users being denied due to poor lighting, glasses, etc.).
    - **Raising the threshold** (e.g., `0.65`): Makes the system **more lenient**. It reduces the **FRR** (fewer false rejections) but increases the risk of **FAR** (higher chance of a false match).
    - `0.6` is the standard dlib recommendation and works well in generic lighting environments.

---

## 📋 End-to-End Verification Checklist

Perform these steps to confirm the system is fully operational:

### 1. Administrator Enrollment Test
1. Open the mobile app and navigate to **Settings** (top right) to view the Admin Login.
2. Log in with `admin@system.com` and `admin123`.
3. Tap **Enroll User** on the dashboard.
4. Input a test name (e.g., `John Doe`), optional email/ID, and tap to capture their biometric photo.
5. Tap **Enroll Member**.
6. Verify the user appears in the **View Users** list and inside the PostgreSQL `users` table.

### 2. Verification Test (Success Case)
1. Navigate back to the scan portal screen (the primary camera viewfinder).
2. Position the face of the enrolled user (`John Doe`) inside the pulsing oval and tap the scan button.
3. Verify the screen transitions to a green gradient showing **ACCESS GRANTED** along with the name `John Doe`.
4. Verify that the check-in automatically dismisses and returns to the scanner after 5 seconds.

### 3. Verification Test (Failure/Unenrolled Case)
1. Position the face of an **unenrolled** person (or hold up a different face) and scan.
2. Verify the screen transitions to a red gradient showing **ACCESS DENIED** with the reason `No match found`.

### 4. Anti-Spoofing / Liveness Check Test
1. Hold up a static paper printout or a flat phone picture of the enrolled user (`John Doe`) to the camera and run a scan.
2. Verify the system detects the lack of texture depth/micro-movements and denies access with the reason `Liveness check failed` or similar anti-spoofing warning.

### 5. Audit Log Inspection
1. Log back into the Admin Dashboard.
2. Tap **Audit Logs**.
3. Confirm that all four attempts (the successful check-in, the failed unknown face, and the spoofing attempt) are recorded with correct timestamps, outcomes, confidence scores, and reasons.
