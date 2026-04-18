# Kinetic — Real-time AI Form Coaching

An iOS fitness app that analyzes workout form in real time using Apple Vision, gives live audio coaching, and generates deterministic post-session reports. A small FastAPI backend stores user profiles, session history, and aggregated insights.

---

## Architecture

```
┌──────────────────────────── iPhone (Swift / SwiftUI) ────────────────────────────┐
│  Camera → Apple Vision pose → AngleCalculator → FormComparator → AudioCoach      │
│                                                    │                             │
│                                                    └──> SessionManager           │
│                                                           │                      │
│                                                           └──> SessionAnalyzer   │
│                                                                 (local report)   │
└────────────────────────────────────────────────────┬─────────────────────────────┘
                                                     │ HTTP (summary only)
                                                     ▼
                          ┌────────────────── FastAPI backend ──────────────────┐
                          │  /api/users      /api/exercises                     │
                          │  /api/sessions   /api/insights/:userId              │
                          │  SQLite (formcoach.db) — no LLMs                    │
                          └─────────────────────────────────────────────────────┘
```

**All per-session analysis is on-device and deterministic** (no AI calls). The backend persists session summaries and computes aggregated long-term stats for the Insights tab.

### Supported exercises
Push-Up · Squat · Deadlift · Plank · Lunge · Jumping Jacks · Bicep Curl

---

## Running on a Mac (step-by-step)

Your teammate will need:
- macOS with **Xcode 15+** (free from Mac App Store)
- **Python 3.10+**
- An iPhone (iOS 17+) running the same iCloud account as the Mac, OR just the Xcode simulator (camera won't work but the UI flow does)

### 1. Clone the repo

```bash
git clone <your repo url>
cd hack_princeton
```

### 2. Start the backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Verify: `curl http://localhost:8000/api/health` → `{"status":"ok","service":"kinetic"}`

**Find your Mac's LAN IP** (you'll need this if running on a real iPhone):
```bash
ipconfig getifaddr en0     # usually WiFi
# e.g. 192.168.1.42
```

### 3. Generate the Xcode project

```bash
brew install xcodegen       # one-time
cd ../ios
xcodegen generate
open FormCoach.xcodeproj
```

### 4. Configure signing (one-time per Mac)

1. In Xcode, click the `FormCoach` project in the left sidebar
2. Select the `FormCoach` target → **Signing & Capabilities**
3. Tick **Automatically manage signing**
4. Pick your Apple ID team (free personal team works)

### 5. Run

**On a physical iPhone (recommended — camera works):**
1. Plug in the iPhone, unlock it, and trust the Mac
2. Select your iPhone as the run destination in the Xcode toolbar
3. Hit **Cmd+R**
4. On the phone, Settings → General → VPN & Device Management → trust your developer profile
5. **In the app's Profile tab**, tap "API URL" and replace `localhost` with your Mac's LAN IP:
   ```
   http://192.168.1.42:8000/api
   ```
   The iPhone and Mac must be on the same WiFi.

**On the simulator (no camera, but flows work):**
1. Pick any iPhone simulator from the run destination dropdown
2. Hit **Cmd+R**
3. Leave the API URL at its default `http://localhost:8000/api`

---

## Project Structure

```
hack_princeton/
├── backend/                        FastAPI server
│   ├── main.py                     App entry + CORS + startup seeding
│   ├── database.py                 SQLAlchemy engine + session
│   ├── models.py                   User · Session · SessionExercise · Exercise
│   ├── schemas.py                  Pydantic request/response types
│   ├── seed_data.py                Reference angles for all 7 exercises
│   ├── requirements.txt
│   └── routers/
│       ├── exercises.py            GET /api/exercises
│       ├── users.py                POST /api/users · GET /api/users/:id
│       ├── sessions.py             Session CRUD
│       └── insights.py             GET /api/insights/:userId (aggregated)
│
├── ios/                            Swift app (XcodeGen-managed)
│   ├── project.yml
│   └── FormCoach/
│       ├── App/FormCoachApp.swift
│       ├── Camera/CameraManager.swift
│       ├── Pose/                   BodyPose · JointSmoother · PoseDetector
│       ├── Analysis/               AngleCalculator · ExerciseClassifier
│       │                           FormComparator · SessionAnalyzer
│       ├── Feedback/               RepCounter · AudioCoach
│       ├── Networking/             APIClient · APIModels
│       ├── Session/                SessionManager · UserStore
│       └── UI/                     Theme · RootView · WelcomeView
│                                   OnboardingView · DashboardView
│                                   SessionView · ReportView
│                                   WorkoutsView · InsightsView
│                                   ProfileView · OverlayRenderer
│
├── shared/api-contract.json        Source of truth for all endpoints
└── docs/                           Design / iteration notes
```

---

## Key Design Decisions (from iterations_1.md)

- **No LLM calls for session analysis.** All in-session feedback and post-session reports are computed by deterministic Swift code (`FormComparator` + `SessionAnalyzer`). This is faster, works offline, has no API cost, and is the same kind of math a trainer would do.
- **Local rep-level tracking.** Each completed rep produces a `RepRecord` with score, tempo, peak angle, and top correction. The `SessionReport` aggregates these into strengths, risks, tempo analysis, and consistency.
- **Backend is a thin persistence layer.** Its only job is to store what the phone finishes computing, and to aggregate across sessions for long-term trends.
- **User state lives locally first**, syncs to backend on change. This way the phone can do onboarding, workouts, and reports with zero network dependency.

---

## Known Blindspots

1. **Skeleton overlay alignment** — Vision's coordinate space doesn't 100% match the preview layer on all device rotations. Test on a real iPhone early.
2. **Exercise auto-detection is best-effort.** The user picks the exercise manually on the Session screen; the classifier just logs what it thinks.
3. **Vision accuracy degrades in poor lighting** or with loose clothing. Reference position matters — the phone should be set up 6–10 feet away at hip-to-chest height, side-angle.
4. **Heart rate on the session screen is currently mocked** (not wired to HealthKit). Easy follow-up: add HealthKit integration.
5. **No auth.** User IDs are generated on the phone (`UserDefaults`). Fine for a hackathon; don't ship to strangers.
6. **Backend must be on the same WiFi** as the iPhone. The Profile tab lets you override the API URL at runtime.

---

## Quick API reference

| Method | Path                      | Purpose                         |
|--------|---------------------------|---------------------------------|
| GET    | `/api/health`             | Health check                    |
| GET    | `/api/exercises`          | Reference angle data            |
| POST   | `/api/users`              | Upsert user profile             |
| GET    | `/api/users/:id`          | Fetch profile                   |
| POST   | `/api/sessions`           | Save completed session          |
| GET    | `/api/sessions?userId=`   | List sessions                   |
| GET    | `/api/insights/:userId`   | Aggregated stats + streaks      |
