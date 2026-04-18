# Kinetic API — Endpoint Reference

Base URL: `http://localhost:8000/api`

---

## Health

### `GET /health`
Returns server status. Used by the iOS app on launch to verify the backend is reachable before attempting any data sync. If this fails, the app operates in offline-only mode and queues session uploads for later.

---

## Exercises

### `GET /exercises`
Returns all exercises with their reference angle data, phases, and correction strings. Called once when the app launches (or when the local cache is empty). The iOS client caches this response and uses it for all real-time form comparison on-device — no per-frame server calls.

### `GET /exercises/{exercise_id}`
Returns reference data for a single exercise. Used when the user taps into an exercise detail screen before starting a session, or if a new exercise is added server-side and the client needs to fetch just that one without re-downloading the full list.

---

## Users

### `POST /users`
Creates a new user or updates an existing one (upsert). Called at the end of the onboarding flow — the app collects name, fitness goal, fitness level, health notes, and body goals across several screens, then sends it all in one request. The returned user ID is stored locally and sent with every subsequent session.

### `GET /users/{user_id}`
Retrieves the user's profile. Used when the app launches to hydrate the settings/profile screen, and to check whether onboarding has been completed (if the user ID exists locally but the server returns 404, onboarding needs to run again).

---

## Sessions

### `POST /sessions`
Saves a completed workout session summary. Called when the user taps "End Workout" — the iOS app bundles up all accumulated data (exercises performed, rep counts, average form scores, duration, and correction counts) and POSTs it as a single payload. This is the only write the app makes during a normal workout flow.

### `GET /sessions?userId=&limit=&offset=`
Returns a paginated list of the user's past sessions, newest first. Powers the session history screen where users scroll through previous workouts. The `limit` and `offset` params support infinite scroll — the app fetches 20 at a time and loads more as the user scrolls down.

### `GET /sessions/{session_id}`
Returns full detail for a single session, including per-exercise breakdowns. Used when the user taps a session in their history list to see the detailed report — which exercises they did, how many reps, what their form score was, and which corrections came up most.

### `DELETE /sessions/{session_id}`
Deletes a session from history. Used when the user swipe-deletes a session from the history list — for example, removing a test session from the demo or a session where they accidentally left the camera running. Returns 204 on success.

---

## Insights

### `GET /insights/{user_id}`
Returns aggregated workout statistics for a user. Powers the Insights tab — total sessions, total reps, total minutes, overall average form score, current streak, per-exercise breakdowns, top corrections to work on, and a 7-day activity chart. Called each time the user navigates to the Insights tab; the data is computed server-side from all stored sessions.

---

## Records

### `GET /records/{user_id}`
Returns the user's personal bests across all exercises. Shows things like highest single-rep form score per exercise, most reps in a single session, longest session duration, and best average score per exercise. Used on the Insights tab or a dedicated "Records" section to give users milestone moments — e.g., "Your best squat score is 95, set on April 15."

---

## Analysis

### `POST /analysis/session-summary`
Generates an AI-powered post-session summary using the Claude API. Called after `POST /sessions` completes — the app sends the session ID (or the full session data inline), and the server returns a natural-language summary like "Great push-up session! Your depth improved over the last 5 reps, but watch your hip sag — it triggered 4 corrections." Displayed on the post-session results screen as a coaching debrief.
