# Entropy — Manual Test Script (physical Android device)

UsageStatsManager does not report real data on most emulators, so run this on
a physical device with USB debugging enabled.

## 0. One-time setup

```bash
# Deploy Firestore rules + functions (needs your Firebase project login)
firebase functions:secrets:set GEMINI_API_KEY   # paste your Gemini key
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,functions

# Install the app WITH the debug seed tools enabled
flutter run --dart-define=SEED_TOOLS=true
```

## 1. Cold start → permissions

1. Launch the app, sign up (email or Google).
2. Onboarding: on the Usage Access page tap **Grant Access** → Android
   settings open → enable Entropy → return. The page should show
   "Permission Granted".
3. Select 1–2 blocked apps (e.g., Instagram), then allow notifications on
   the last page.
4. Expected: you land on the Dashboard; the trend chart shows
   "No sessions logged today yet." (not a fake curve).

## 2. Foreground service + live tracking (the 4-second poll)

1. On the Dashboard tap **+ Check In**.
2. Expected: a persistent "Entropy Focus Mode" notification appears.
3. Open any normal app (e.g., Chrome) for ~30 s.
   Expected: the notification text updates to "Focus session active — Chrome"
   within a few seconds (each 4 s poll can shift it).
4. Open a **blocked** app.
   Expected: within ~4–8 s the full-screen "COGNITIVE DRIFT DETECTED"
   overlay appears. Tap **Go Back**.
5. Background the Entropy app entirely (home screen, use other apps ~2 min).
   Expected: the notification stays; the service keeps running.
6. Return, tap **Check Out**, fill the log page, **Save Log**.

## 3. Sessions land in Firestore

In the Firebase console check `users/{uid}/`:
- `sessions/{id}` — completed, with `driftEvents` from step 2.4 and
  `appsOpenedDuringSession` populated.
- `usageSessions/*` — per-app docs with `dateKey`, `hour`, `durationMinutes`
  (written at checkout and every 60 s during long sessions).
- `insights/*` — a new post-session insight from the Cloud Function
  (also arrives as a push notification).
- `baseline/current` — created by the same function call.

## 4. Charts populate (1 / 7 / 30 days)

1. Insights tab → flask icon (only visible in SEED_TOOLS builds) →
   **Seed 1 day**. Check: Dashboard trend chart, Screen Time breakdown +
   heatmap (one row of cells), Insights chart all render.
2. Repeat with **Seed 7 days**: heatmap fills 7 rows; the correlation chart
   shows focus + screen-time series.
3. Repeat with **Seed 30 days**: Profile heatmap and Weekly report populate;
   charts stay within axes (no overflow).
4. Pull-to-refresh on Screen Time: real hourly buckets for the trailing week
   get merged from the OS (`appUsage/{date}.hourly`).

## 5. Synthetic drift end-to-end

1. Flask icon → **Seed 7 days** first (builds a baseline), then
   **Seed drift day + analyze**.
2. Expected snackbar: "Drift detected — alert written to insights."
3. Expected in-app: a warning-colored alert appears in Dashboard →
   Quick Insights, Insights → Recommendations, and below the Screen Time
   charts; a "Drift Detected" push notification arrives.
4. Expected in Firestore: `baseline/current` updated; newest doc in
   `insights` has `type: "drift"`.
5. The dashed gray line on the Screen Time correlation chart is the stored
   baseline — today's orange screen-time point should sit clearly above it.

## 6. Permission-revocation path

1. Android Settings → Special app access → Usage access → disable Entropy.
2. Reopen the app → Screen Time tab.
   Expected: the "Usage Access Permission" explainer with a **Grant Access**
   button (no crash, no stale data pretending to be fresh).
3. Re-grant; the page refreshes automatically on return.

## 7. Offline tolerance

1. Enable airplane mode, run a short focus session, check out, save the log.
   Expected: no crash; UI stays responsive.
2. Disable airplane mode. Expected: queued session/usage writes appear in
   Firestore within a minute.
