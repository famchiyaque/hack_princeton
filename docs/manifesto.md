Building fitness-instruction app. We're looking to analyze a person's workout (via real-time video) and compare it to the correct standard form (think of a pushup -- chest should be nearly touching the ground). Later, we could show a visual comparison of what the correct form for that certain workout would be (we would have to identify the form). We would also like to connect this to the user's headphones and based on their movements, we can return a live audio saying “go deeper” when the squat isn’t going down all the way. Tell me an optimal structure for this 36hr hackathon. We plan to use our iPhones for this. Be thorough and write this into an SD.MD file
## 1. Architecture Overview


**Pattern: Heavy-Client / Thin-Server**


All real-time pose estimation and audio feedback runs on-device (iPhone). The server handles persistence and optional AI-generated summaries. This is non-negotiable for latency — sending video frames to a server at 30fps would introduce 100-500ms delay, making live audio coaching unusable.


```
┌──────────────────────────────────────────────────────────┐
│                    iPhone (Swift/SwiftUI)                 │
│                                                          │
│  ┌──────────────┐   ┌───────────────┐   ┌────────────┐  │
│  │ Camera Feed  │──>│ Apple Vision  │──>│ Pose        │  │
│  │ (AVFoundation│   │ Framework     │   │ Comparator  │  │
│  │  live preview│   │ (VNDetectHuman│   │ Engine      │  │
│  │             )│   │ BodyPoseReq.) │   │             │  │
│  └──────────────┘   └───────────────┘   └──────┬──────┘  │
│                                                │         │
│                           ┌────────────────────┤         │
│                           v                    v         │
│                    ┌────────────┐     ┌──────────────┐   │
│                    │ Audio      │     │ Overlay      │   │
│                    │ Feedback   │     │ Renderer     │   │
│                    │ (AVSpeech) │     │ (correct vs  │   │
│                    └────────────┘     │  actual pose)│   │
│                                      └──────────────┘   │
│                           │                              │
│                           v                              │
│                    ┌────────────┐                        │
│                    │ Session    │──── HTTP ────┐         │
│                    │ Manager    │              │         │
│                    └────────────┘              │         │
└───────────────────────────────────────────────┼─────────┘
                                               v
                         ┌──────────────────────────────┐
                         │   Backend (FastAPI on laptop) │
                         │                              │
                         │  /api/sessions   (CRUD)      │
                         │  /api/exercises  (ref data)  │
                         │  /api/analysis   (post-hoc)  │
                         │                              │
                         │  SQLite / in-memory for MVP  │
                         └──────────────────────────────┘
```


### What Runs Where


| Component | Runs on | Rationale |
|-----------|---------|-----------|
| Camera capture | iPhone | Hardware access |
| Pose estimation (Vision) | iPhone | On-device ML, sub-30ms latency |
| Exercise identification | iPhone | Classification on extracted joint angles |
| Form comparison & scoring | iPhone | Must be real-time for audio cues |
| Audio feedback | iPhone | AVSpeechSynthesizer, zero network latency |
| Visual overlay rendering | iPhone | Real-time AR-style overlay on camera feed |
| Session logging / history | Server | Persistence, cross-device |
| Reference pose data | Server (fetched once) | Canonical joint angles per exercise, cached on device |
| Post-session summary | Server (optional) | LLM-generated workout summary (stretch goal) |


---


## 2. Tech Stack


### iOS Client (where 80% of the work lives)


| Layer | Technology | Why |
|-------|-----------|-----|
| Language | **Swift** | Native Apple Vision access, no bridge overhead |
| UI | **SwiftUI** | Faster to build than UIKit for hackathon |
| Camera | **AVFoundation** (`AVCaptureSession`) | Direct camera frame access for Vision |
| Pose Estimation | **Apple Vision** (`VNDetectHumanBodyPoseRequest`) | On-device, no dependency, 19 joint points, 30fps on iPhone 12+ |
| Audio | **AVSpeechSynthesizer** | Built-in TTS, zero setup, works with AirPods automatically |
| Networking | **URLSession** | Minimal dependency |


### Backend


| Layer | Technology | Why |
|-------|-----------|-----|
| Framework | **FastAPI** (from template starter) | Already in template, Python ecosystem |
| Database | **In-memory dict** (upgrade to SQLite if time) | Zero setup, matches template pattern |


### Why Apple Vision over MediaPipe


- **Apple Vision**: Zero dependencies. Ships with iOS. No pod install, no build issues. 19 body joints with confidence scores. Runs on the Neural Engine.
- **MediaPipe**: 33 landmarks (more detailed) but requires CocoaPods/SPM, has broken with Swift version updates, adds 15-30 min of build config risk.
- **Server-side**: Ruled out. 100-500ms latency per frame makes audio cues unusable.


**Verdict**: Apple Vision. 19 joints are sufficient for pushups, squats, lunges, and planks.


---


## 3. Real-Time Data Flow


```
Every frame (~33ms at 30fps):


1. AVCaptureSession delivers CMSampleBuffer
         │
         v
2. VNDetectHumanBodyPoseRequest processes frame
  Output: VNHumanBodyPoseObservation (19 joint positions)
  Latency: ~10-15ms on Neural Engine
         │
         v
3. Joint Angle Calculator
  - Extract key angles (elbow, knee, hip, spine)
  - Normalize to body-relative coordinates
  - Apply temporal smoothing (EMA, alpha=0.3)
         │
         v
4. Exercise Classifier (runs every ~15 frames / 0.5s)
  - State machine based on joint angle patterns
  - Detects: pushup, squat, plank, lunge
  - Tracks rep phase: "going down" / "at bottom" / "coming up"
         │
         v
5. Form Comparator
  - Compare current angles to reference per exercise + phase
  - Produce per-joint deviation scores
  - Overall form score = weighted sum of deviations
         │
         v
6. Feedback Router (throttled: max 1 audio cue per 2 seconds)
  ├──> Audio: AVSpeechSynthesizer speaks highest-priority correction
  └──> Visual: Update overlay (correct skeleton vs actual skeleton)
         │
         v
7. Session Accumulator (in-memory)
  - Aggregate rep count, average form score per rep
  - On session end, POST summary to backend
```


### Latency Budget Per Frame


| Step | Budget |
|------|--------|
| Frame capture | ~2ms |
| Vision pose detection | ~10-15ms |
| Angle calculation + smoothing | ~1ms |
| Exercise classification | ~1ms (amortized) |
| Form comparison | ~1ms |
| Audio decision | ~0.1ms |
| Overlay render | ~5ms |
| **Total** | **~20-25ms** (within 33ms budget) |


---


## 4. Key Modules


### iOS App


#### 4.1 `CameraManager`
- Wraps `AVCaptureSession` with `AVCaptureVideoDataOutput`
- Delivers `CMSampleBuffer` frames to the pose detector
- Handles camera permissions, front/back toggle
- Delegate: `AVCaptureVideoDataOutputSampleBufferDelegate`


#### 4.2 `PoseDetector`
- Receives `CMSampleBuffer`, runs `VNDetectHumanBodyPoseRequest`
- Extracts 19 recognized points from `VNHumanBodyPoseObservation`
- Publishes `BodyPose` struct (JointName -> CGPoint + confidence)
- Applies temporal smoothing to reduce jitter


#### 4.3 `AngleCalculator`
- Pure math module: given 3 joint positions, calculates angle at the middle joint
- Key angles:
 - **Elbow**: shoulder-elbow-wrist (pushup depth)
 - **Knee**: hip-knee-ankle (squat depth)
 - **Hip**: shoulder-hip-knee (hip hinge)
 - **Spine**: neck-shoulder-hip (back straightness)


#### 4.4 `ExerciseClassifier`
- State machine (not ML — no training data needed)
- Uses body orientation + angle patterns:
 - Body horizontal + arms bending → pushup
 - Body upright + knees bending → squat
 - Body horizontal + static hold → plank
 - Body upright + one knee forward → lunge
- Tracks rep phase via angle thresholds


#### 4.5 `FormComparator`
- Holds reference angle ranges per exercise per phase
- Computes deviation: how far each angle is from acceptable range
- Produces `FormFeedback` objects ranked by severity


#### 4.6 `AudioCoach`
- `AVSpeechSynthesizer` for TTS
- Priority queue of feedback messages
- Throttle: max once every 2 seconds
- Pre-defined corrections:
 - "Go deeper"
 - "Straighten your back"
 - "Push your knees over your toes"
 - "Hold your position"
 - "Fully extend your arms"
 - "Good form, keep it up"


#### 4.7 `OverlayRenderer`
- SwiftUI overlay on camera preview
- Draws two skeletons:
 - **Green**: user's actual pose
 - **Blue/ghost**: reference correct pose
- Shows real-time form score (0-100) as colored arc
- Shows rep counter


#### 4.8 `SessionManager`
- Tracks workout start time, exercise transitions, rep counts, per-rep scores
- On session end: POST summary to backend
- Handles session lifecycle UI (start/pause/end)


### Backend (FastAPI)


#### 4.9 `exercises` router
- Serves reference pose data (canonical angles per exercise)
- Hardcoded for MVP


#### 4.10 `sessions` router
- Receives session summaries from the app
- Stores workout history


#### 4.11 `analysis` router (stretch)
- Receives raw angle data, returns AI-generated workout summary via Claude API


---


## 5. API Design


```json
{
 "baseURL": "http://localhost:8000/api",
 "endpoints": {
   "healthCheck": {
     "method": "GET",
     "path": "/health"
   },
   "getExercises": {
     "method": "GET",
     "path": "/exercises",
     "response": {
       "exercises": [
         {
           "id": "pushup",
           "name": "Push-Up",
           "phases": [
             {
               "name": "bottom",
               "referenceAngles": {
                 "elbowAngle": { "min": 70, "max": 100 },
                 "hipAngle": { "min": 160, "max": 180 },
                 "spineAngle": { "min": 160, "max": 180 }
               }
             },
             {
               "name": "top",
               "referenceAngles": {
                 "elbowAngle": { "min": 155, "max": 180 },
                 "hipAngle": { "min": 160, "max": 180 },
                 "spineAngle": { "min": 160, "max": 180 }
               }
             }
           ],
           "corrections": {
             "elbowAngle_high": "Go deeper",
             "hipAngle_low": "Keep your hips up",
             "spineAngle_low": "Straighten your back"
           }
         }
       ]
     }
   },
   "getExercise": {
     "method": "GET",
     "path": "/exercises/:id"
   },
   "createSession": {
     "method": "POST",
     "path": "/sessions",
     "body": {
       "userId": "anonymous",
       "exercises": [
         {
           "exerciseId": "pushup",
           "reps": 10,
           "avgScore": 78.5,
           "duration": 45,
           "corrections": [
             { "type": "elbowAngle_high", "count": 3 }
           ]
         }
       ],
       "totalDuration": 120,
       "startedAt": "ISO8601"
     }
   },
   "getSessions": {
     "method": "GET",
     "path": "/sessions",
     "query": ["userId", "limit", "offset"]
   },
   "getSession": {
     "method": "GET",
     "path": "/sessions/:id"
   }
 }
}
```


---


## 6. 36-Hour Timeline


### Phase 1: Foundation (Hours 0-6)


| Hour | Task | Deliverable |
|------|------|-------------|
| 0-1 | Xcode project setup, copy FastAPI starter, git branching | Running Xcode project + backend health check |
| 1-3 | `CameraManager`: AVCaptureSession with live preview in SwiftUI | Camera feed visible on screen |
| 1-3 | `PoseDetector`: Wire Vision framework to camera frames | Console logging joint positions per frame |
| 1-3 | Backend: Replace items CRUD with exercises + sessions endpoints | `GET /api/exercises` returns reference data |
| 3-6 | `AngleCalculator` + draw skeleton overlay on camera feed | Green skeleton on live camera |
| 3-6 | `ExerciseClassifier` v1: detect pushup vs squat | Console logs exercise type |


**Checkpoint**: Camera shows live skeleton overlay. Exercise type detected. Backend serves reference data.


### Phase 2: Core Intelligence (Hours 6-16)


| Hour | Task | Deliverable |
|------|------|-------------|
| 6-9 | `FormComparator`: live angles vs reference, deviation scores | Form score (0-100) on screen |
| 6-9 | Rep counting: detect up/down transitions | Rep counter works for pushups + squats |
| 6-9 | Backend: sessions endpoint fully working | POST/GET session summaries |
| 9-12 | `AudioCoach`: TTS feedback based on deviations, throttled | Phone says "go deeper" when form is off |
| 9-12 | `OverlayRenderer` v2: ghost/reference skeleton alongside actual | Two skeletons visible |
| 12-14 | Integration: wire all modules end-to-end | Complete working loop |
| 14-16 | Bug fixing, angle tuning, real exercise testing | Reliable detection for pushups + squats |


**Checkpoint**: Full working loop. Audio coaching works. Visual overlay. Reps counted.


### Phase 3: Polish + Stretch (Hours 16-30)


| Hour | Task | Deliverable |
|------|------|-------------|
| 16-20 | UI polish: session flow, exercise selection, score display | Polished SwiftUI screens |
| 16-20 | Add plank + lunges | 4 total exercises |
| 16-20 | Session history screen | History view |
| 20-24 | Stretch: AI summary via Claude API | Post-session text feedback |
| 20-24 | Stretch: animated reference form demo | Pre-exercise animation |
| 24-28 | End-to-end testing, edge case fixes | Graceful error handling |
| 28-30 | Demo prep: script demo, record backup video | Rehearsed 3-min demo |


### Phase 4: Demo Prep (Hours 30-36)


| Hour | Task |
|------|------|
| 30-32 | Final bug fixes only (no new features) |
| 32-34 | Demo rehearsal (3 runs minimum) |
| 34-36 | Presentation slides, README, buffer |


---


## 7. MVP vs Stretch Goals


### MVP (must ship)


1. Live camera feed with skeleton overlay
2. Pushup form analysis (depth via elbow angle)
3. Squat form analysis (depth via knee angle)
4. Real-time form score (0-100) on screen
5. Audio coaching via TTS (at least 3 distinct cues)
6. Rep counting
7. Exercise detection (pushup vs squat, minimum)


### Stretch Goals (priority order)


1. Visual comparison overlay (ghost skeleton showing correct form)
2. Plank + lunge support (4 total exercises)
3. Session history (save and review past workouts)
4. Post-session AI summary (Claude-generated feedback)
5. Pre-exercise demo animation
6. Progress tracking with charts
7. Custom exercise profiles
8. Social sharing (form score as image)


---


## 8. Database Schema


Start with in-memory storage. Upgrade to SQLite if time permits.


```sql
CREATE TABLE exercises (
   id TEXT PRIMARY KEY,           -- "pushup", "squat"
   name TEXT NOT NULL,
   reference_data JSON NOT NULL   -- phases + angles + corrections
);


CREATE TABLE sessions (
   id TEXT PRIMARY KEY,
   user_id TEXT DEFAULT 'anonymous',
   total_duration INTEGER,        -- seconds
   started_at TEXT,               -- ISO 8601
   created_at TEXT DEFAULT (datetime('now'))
);


CREATE TABLE session_exercises (
   id TEXT PRIMARY KEY,
   session_id TEXT REFERENCES sessions(id),
   exercise_id TEXT REFERENCES exercises(id),
   reps INTEGER,
   avg_score REAL,                -- 0-100
   duration INTEGER,              -- seconds
   corrections JSON               -- [{"type": "elbowAngle_high", "count": 3}]
);
```


---


## 9. Key Algorithms


### 9.1 Joint Angle Calculation


```swift
func angleBetween(_ a: CGPoint, vertex b: CGPoint, _ c: CGPoint) -> Double {
   let vectorBA = CGPoint(x: a.x - b.x, y: a.y - b.y)
   let vectorBC = CGPoint(x: c.x - b.x, y: c.y - b.y)


   let dotProduct = vectorBA.x * vectorBC.x + vectorBA.y * vectorBC.y
   let magnitudeBA = sqrt(vectorBA.x * vectorBA.x + vectorBA.y * vectorBA.y)
   let magnitudeBC = sqrt(vectorBC.x * vectorBC.x + vectorBC.y * vectorBC.y)


   guard magnitudeBA > 0 && magnitudeBC > 0 else { return 0 }


   let cosAngle = max(-1, min(1, dotProduct / (magnitudeBA * magnitudeBC)))
   return acos(cosAngle) * 180.0 / .pi  // 0-180 degrees
}
```


### 9.2 Temporal Smoothing (Exponential Moving Average)


```swift
class JointSmoother {
   private var smoothed: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
   private let alpha: CGFloat = 0.3


   func smooth(_ raw: [VNHumanBodyPoseObservation.JointName: CGPoint])
       -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
       for (joint, point) in raw {
           if let prev = smoothed[joint] {
               smoothed[joint] = CGPoint(
                   x: alpha * point.x + (1 - alpha) * prev.x,
                   y: alpha * point.y + (1 - alpha) * prev.y
               )
           } else {
               smoothed[joint] = point
           }
       }
       return smoothed
   }
}
```


### 9.3 Form Scoring


```swift
func scoreForm(
   currentAngles: [String: Double],
   reference: [String: ClosedRange<Double>],
   weights: [String: Double]
) -> (score: Double, corrections: [FormCorrection]) {


   var totalWeightedScore = 0.0
   var totalWeight = 0.0
   var corrections: [FormCorrection] = []


   for (angleName, idealRange) in reference {
       guard let current = currentAngles[angleName],
             let weight = weights[angleName] else { continue }


       totalWeight += weight


       if idealRange.contains(current) {
           totalWeightedScore += weight * 100.0
       } else {
           let deviation: Double
           if current < idealRange.lowerBound {
               deviation = idealRange.lowerBound - current
           } else {
               deviation = current - idealRange.upperBound
           }
           // 30 degrees off = 0 score for this joint
           let jointScore = max(0, 100.0 - (deviation / 30.0 * 100.0))
           totalWeightedScore += weight * jointScore


           if deviation > 10 {
               corrections.append(correctionFor(angleName, deviation: deviation))
           }
       }
   }


   let finalScore = totalWeight > 0 ? totalWeightedScore / totalWeight : 0
   return (finalScore, corrections)
}
```


**Weight distributions:**


| Joint Angle | Pushup | Squat |
|-------------|--------|-------|
| Elbow | 0.40 | — |
| Knee | — | 0.40 |
| Hip | 0.30 | 0.25 |
| Spine | 0.20 | 0.25 |
| Other | 0.10 | 0.10 |


### 9.4 Exercise Classification (State Machine)


```swift
func classifyExercise(angles: BodyAngles, orientation: BodyOrientation) -> ExerciseType {
   switch orientation {
   case .horizontal:
       if angles.elbowAngle < 150 || isArmsBending(history: recentAngles) {
           return .pushup
       }
       if angles.hipAngle > 160 && angles.elbowAngle > 160 {
           return .plank
       }
   case .upright:
       if angles.kneeAngle < 150 || isKneesBending(history: recentAngles) {
           if abs(angles.leftKneeAngle - angles.rightKneeAngle) > 30 {
               return .lunge
           }
           return .squat
       }
   case .other:
       break
   }
   return .unknown
}


func bodyOrientation(nose: CGPoint, hip: CGPoint) -> BodyOrientation {
   let verticalDiff = abs(nose.y - hip.y)
   let horizontalDiff = abs(nose.x - hip.x)
   if verticalDiff > horizontalDiff * 1.5 { return .upright }
   if horizontalDiff > verticalDiff * 1.5 { return .horizontal }
   return .other
}
```


### 9.5 Rep Counting (Phase Transition Detection)


```swift
class RepCounter {
   enum Phase { case up, goingDown, down, comingUp }


   private var phase: Phase = .up
   private(set) var repCount = 0
   private let downThreshold: Double  // e.g., 100 for pushup elbow
   private let upThreshold: Double    // e.g., 155 for pushup elbow


   func update(primaryAngle: Double) -> Int {
       switch phase {
       case .up:
           if primaryAngle < downThreshold + 20 { phase = .goingDown }
       case .goingDown:
           if primaryAngle < downThreshold { phase = .down }
           if primaryAngle > upThreshold { phase = .up }  // Aborted rep
       case .down:
           if primaryAngle > downThreshold + 20 { phase = .comingUp }
       case .comingUp:
           if primaryAngle > upThreshold {
               phase = .up
               repCount += 1
           }
           if primaryAngle < downThreshold { phase = .down }
       }
       return repCount
   }
}
```


---


## 10. Risk Mitigation


| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Vision pose accuracy poor in bad lighting | Medium | High | Test in hour 2. Require good lighting + side-angle placement. Skip frames below 0.5 confidence. |
| AVSpeechSynthesizer sounds robotic | Medium | Medium | Use enhanced voice: `AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-US.Ava")`. Pre-record clips in polish phase if needed. |
| Exercise classification misidentifies | High | Medium | Let user manually select exercise for MVP. Auto-detection is nice-to-have. |
| Frame processing drops below 30fps | Low | High | Process every other frame (15fps is fine). Use dedicated serial dispatch queue for Vision. |
| Skeleton overlay misaligned | High | Medium | Use `VNImagePointForNormalizedPoint` with video preview layer bounds. Test in hour 3-4. |
| Team unfamiliar with Swift | Medium | High | One strong iOS dev drives architecture. Others work on backend, angle math (testable in Playground), reference data. |
| Demo fails live | Medium | Critical | Record backup video in hour 28-30. Support pre-recorded video input as fallback (`AVAssetReader`). |
| Network issues during demo | Low | Low | Entire real-time loop is on-device. Backend only for persistence. App works fully offline. |


---


## 11. Apple Vision Joint Map (19 joints)


```
Head:  nose, leftEye, rightEye, leftEar, rightEar
Torso: neck, leftShoulder, rightShoulder, root (center hip)
Arms:  leftElbow, rightElbow, leftWrist, rightWrist
Legs:  leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle
```


### Key Angle Calculations


| Angle | Joints (A, vertex, C) | Exercise Use |
|-------|----------------------|--------------|
| Elbow | shoulder, elbow, wrist | Pushup depth |
| Knee | hip, knee, ankle | Squat/lunge depth |
| Hip | shoulder, hip, knee | Hip hinge, plank sag |
| Spine | neck, shoulder, hip | Back straightness |
| Shoulder | elbow, shoulder, hip | Overhead movements |

