const { onCall } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const { computeBaseline, detectDrift, generateDriftAlert, analyzeDriftSession } = require('./agents/driftAnalyzer');
const { getFocusCoachDecision } = require('./agents/focusCoach');
const { generateWeeklyPlan } = require('./agents/weeklyPlanner');

admin.initializeApp();
const db = admin.firestore();

// Matches the Flutter cloud_functions default instance region
const REGION = 'us-central1';
// GEMINI_API_KEY comes from Secret Manager on deploy (see functions/.env.example
// for local emulator use). Never hardcode it.
const FUNCTION_OPTS = { region: REGION, secrets: ['GEMINI_API_KEY'] };

// ──────────────────────────────────────────────────────────────────────────────
// Helper: Get Gemini API key from environment
// ──────────────────────────────────────────────────────────────────────────────
function getApiKey() {
  const key = process.env.GEMINI_API_KEY;
  if (!key) throw new Error('GEMINI_API_KEY environment variable is not set');
  return key;
}

// ──────────────────────────────────────────────────────────────────────────────
// Helper: Get ISO week identifier
// ──────────────────────────────────────────────────────────────────────────────
function getIsoWeekId(date) {
  const d = new Date(date);
  const day = d.getDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
}

// ──────────────────────────────────────────────────────────────────────────────
// Helper: Send FCM push notification
// ──────────────────────────────────────────────────────────────────────────────
async function sendFcmNotification(fcmToken, title, body) {
  if (!fcmToken) return;
  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      android: {
        priority: 'high',
        notification: { channelId: 'focus_session_channel' }
      }
    });
  } catch (e) {
    console.error('FCM send error:', e.message);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Helper: Parse an appUsage/{yyyy-MM-dd} doc into { date, totalMinutes,
// hourlyMinutes }. Falls back to summing the hourly map when the daily
// entries list is absent.
// ──────────────────────────────────────────────────────────────────────────────
function parseUsageDoc(doc) {
  const data = doc.data();
  const hourlyMinutes = {};
  let hourlySum = 0;
  for (const [k, v] of Object.entries(data.hourly || {})) {
    const minutes = Number(v) || 0;
    hourlyMinutes[parseInt(k, 10)] = minutes;
    hourlySum += minutes;
  }
  let totalMinutes = (data.entries || []).reduce((s, e) => s + (e.durationMinutes || 0), 0);
  if (totalMinutes === 0) totalMinutes = hourlySum;
  return { date: doc.id, totalMinutes, hourlyMinutes };
}

// ──────────────────────────────────────────────────────────────────────────────
// Agent 1: Drift Analyzer (called after LoggingPage save)
// Computes a deterministic behavioral baseline from session + usage history,
// stores it at users/{uid}/baseline/current (queryable for charts), then
// flags drift with fixed thresholds. Gemini only phrases the resulting
// insight — it never decides whether drift occurred.
// ──────────────────────────────────────────────────────────────────────────────
exports.analyzeDriftSession = onCall(FUNCTION_OPTS, async (request) => {
  const { uid, sessionId } = request.data;
  if (!uid || !sessionId) {
    throw new Error('Missing uid or sessionId');
  }

  // 1. Fetch current session
  const sessionRef = db.collection('users').doc(uid).collection('sessions').doc(sessionId);
  const sessionDoc = await sessionRef.get();
  if (!sessionDoc.exists) throw new Error('Session not found');
  const currentSession = sessionDoc.data();

  // 2. Fetch session history (trailing 14 days, excluding this session)
  const fourteenDaysAgo = new Date();
  fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);
  const historySnap = await db
    .collection('users').doc(uid).collection('sessions')
    .where('startTime', '>=', admin.firestore.Timestamp.fromDate(fourteenDaysAgo))
    .get();
  const historicalSessions = historySnap.docs
    .filter(d => d.id !== sessionId)
    .map(d => d.data());

  // 3. Fetch usage history: latest doc is "today", the rest feed the baseline
  const usageSnap = await db
    .collection('users').doc(uid).collection('appUsage')
    .orderBy(admin.firestore.FieldPath.documentId(), 'desc')
    .limit(15)
    .get();
  const usageDays = usageSnap.docs.map(parseUsageDoc);
  const todayUsage = usageDays.length > 0 ? usageDays[0] : null;
  const baselineUsageDays = usageDays.slice(1);

  // 4. Compute + store the baseline (queryable by the app for charts)
  const baseline = computeBaseline(historicalSessions, baselineUsageDays);
  await db.collection('users').doc(uid).collection('baseline').doc('current').set({
    ...baseline,
    computedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 5. Deterministic drift detection
  const driftFlags = detectDrift(currentSession, todayUsage, baseline);
  const driftDetected = driftFlags.length > 0;

  // 6. Gemini phrases the insight (drift alert or regular post-session note)
  const apiKey = getApiKey();
  const insight = driftDetected
    ? await generateDriftAlert(driftFlags, currentSession, baseline, apiKey)
    : await analyzeDriftSession(currentSession, historicalSessions, apiKey);

  // 7. Write insight to Firestore
  const insightRef = db.collection('users').doc(uid).collection('insights').doc();
  await insightRef.set({
    icon: driftDetected ? 'warning' : (insight.icon || 'info'),
    text: insight.text || '',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    type: driftDetected ? 'drift' : 'post_session'
  });

  // 8. Fetch FCM token and send notification
  const profileDoc = await db
    .collection('users').doc(uid).collection('profile').doc('info').get();
  const fcmToken = profileDoc.exists ? profileDoc.data().fcmToken : null;
  await sendFcmNotification(
    fcmToken,
    driftDetected ? 'Drift Detected' : 'New Focus Insight',
    insight.text?.substring(0, 80) || 'New insight from your last session'
  );

  return { success: true, insightId: insightRef.id, driftDetected, driftFlags };
});

// ──────────────────────────────────────────────────────────────────────────────
// Agent 2: Focus Coach (real-time drift event handler)
// ──────────────────────────────────────────────────────────────────────────────
exports.focusCoachEvent = onCall(FUNCTION_OPTS, async (request) => {
  const { uid, sessionId, event, appName, elapsedMinutes } = request.data;
  if (!uid || !sessionId) {
    throw new Error('Missing uid or sessionId');
  }

  // 1. Fetch current session doc
  const sessionRef = db.collection('users').doc(uid).collection('sessions').doc(sessionId);
  const sessionDoc = await sessionRef.get();
  if (!sessionDoc.exists) throw new Error('Session not found');
  const session = sessionDoc.data();

  // 2. Fetch historical drift patterns (last 10 sessions)
  const historySnap = await db
    .collection('users').doc(uid).collection('sessions')
    .orderBy('startTime', 'desc')
    .limit(10)
    .get();
  const driftPattern = historySnap.docs.map(d => ({
    driftCount: (d.data().driftEvents || []).length,
    durationMinutes: d.data().durationMinutes || 0
  }));

  // 3. Get coach decision from Gemini
  const apiKey = getApiKey();
  const decision = await getFocusCoachDecision(session, event, elapsedMinutes, appName, driftPattern, apiKey);

  // 4. Log agent decision to session's driftEvents
  await sessionRef.update({
    driftEvents: admin.firestore.FieldValue.arrayUnion({
      timestamp: admin.firestore.Timestamp.now(),
      appName: appName || 'unknown',
      action: decision.action === 'end_session' ? 'ended' : 'warned'
    })
  });

  // 5. Send FCM notification
  const profileDoc = await db
    .collection('users').doc(uid).collection('profile').doc('info').get();
  const fcmToken = profileDoc.exists ? profileDoc.data().fcmToken : null;
  await sendFcmNotification(fcmToken, 'Entropy Focus Coach', decision.message || 'Stay focused!');

  return { action: decision.action, message: decision.message };
});

// ──────────────────────────────────────────────────────────────────────────────
// Agent 3: Scheduled Weekly Planner (every Sunday at 8 PM UTC)
// ──────────────────────────────────────────────────────────────────────────────
exports.scheduledWeeklyPlanner = onSchedule({ schedule: '0 20 * * 0', ...FUNCTION_OPTS }, async (event) => {
  const apiKey = getApiKey();

  // Fetch all users with onboardingComplete: true
  const usersSnap = await db.collectionGroup('settings').where('onboardingComplete', '==', true).get();

  // Deduplicate UIDs from path: users/{uid}/settings/prefs
  const uids = [...new Set(usersSnap.docs.map(d => d.ref.path.split('/')[1]))];
  console.log(`Running weekly planner for ${uids.length} user(s)`);

  const fourWeeksAgo = new Date();
  fourWeeksAgo.setDate(fourWeeksAgo.getDate() - 28);

  const twoWeeksAgo = new Date();
  twoWeeksAgo.setDate(twoWeeksAgo.getDate() - 14);

  for (const uid of uids) {
    try {
      // 1. Fetch sessions from past 4 weeks
      const sessionsSnap = await db
        .collection('users').doc(uid).collection('sessions')
        .where('startTime', '>=', admin.firestore.Timestamp.fromDate(fourWeeksAgo))
        .get();
      const sessions = sessionsSnap.docs.map(d => d.data());

      // 2. Fetch app usage from past 2 weeks
      const usageDocs = [];
      const usageSnap = await db
        .collection('users').doc(uid).collection('appUsage')
        .orderBy(admin.firestore.FieldPath.documentId(), 'desc')
        .limit(14)
        .get();
      usageSnap.docs.forEach(d => usageDocs.push({ date: d.id, ...d.data() }));

      // 3. Generate weekly plan from Gemini
      const plan = await generateWeeklyPlan(sessions, usageDocs, apiKey);

      // 4. Write to weeklyPlans/{isoWeekId}
      const weekId = getIsoWeekId(new Date());
      await db
        .collection('users').doc(uid).collection('weeklyPlans').doc(weekId)
        .set({
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          summary: plan.summary || '',
          recommendations: plan.recommendations || []
        });

      // 5. Send FCM notification
      const profileDoc = await db
        .collection('users').doc(uid).collection('profile').doc('info').get();
      const fcmToken = profileDoc.exists ? profileDoc.data().fcmToken : null;
      await sendFcmNotification(fcmToken, 'Your Weekly Report is Ready', 'Tap to view your performance insights for this week.');

      console.log(`Weekly plan written for user: ${uid}`);
    } catch (err) {
      console.error(`Failed for user ${uid}:`, err.message);
    }
  }

  console.log('scheduledWeeklyPlanner completed.');
});
