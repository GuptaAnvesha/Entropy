const { GoogleGenerativeAI } = require('@google/generative-ai');

const GEMINI_MODEL = 'gemini-2.5-flash';

function round1(v) {
  return Math.round(v * 10) / 10;
}

// ──────────────────────────────────────────────────────────────────────────────
// Deterministic baseline computation.
// sessions: historical session docs (current session excluded)
// usageDays: [{ date, totalMinutes, hourlyMinutes: {0..23: min} }] — history
//            only, the current day excluded.
// The result is stored at users/{uid}/baseline/current so the app can render
// it in charts (shape mirrors the Dart UserBaseline model).
// ──────────────────────────────────────────────────────────────────────────────
function computeBaseline(sessions, usageDays) {
  const hourly = new Array(24).fill(0);
  let dailyTotal = 0;
  for (const day of usageDays) {
    dailyTotal += day.totalMinutes;
    for (let h = 0; h < 24; h++) {
      hourly[h] += day.hourlyMinutes[h] || 0;
    }
  }
  const sampleDays = usageDays.length;
  const completed = sessions.filter(s => s.status === 'completed');
  const avg = (arr, f) => (arr.length ? arr.reduce((sum, x) => sum + f(x), 0) / arr.length : 0);

  return {
    dailyAvgUsageMinutes: round1(sampleDays ? dailyTotal / sampleDays : 0),
    hourlyAvgUsageMinutes: hourly.map(v => round1(sampleDays ? v / sampleDays : 0)),
    avgFocusLevel: round1(avg(completed, s => s.focusLevel || 0)),
    avgSessionMinutes: round1(avg(completed, s => s.durationMinutes || 0)),
    avgDriftEventsPerSession: round1(avg(completed, s => (s.driftEvents || []).length)),
    sampleDays,
    sampleSessions: completed.length,
  };
}

// ──────────────────────────────────────────────────────────────────────────────
// Deterministic drift detection: fixed thresholds vs. the computed baseline.
// Gemini plays no part in this decision — it only phrases the alert after.
// Returns a (possibly empty) list of drift flags.
// ──────────────────────────────────────────────────────────────────────────────
function detectDrift(currentSession, todayUsage, baseline) {
  const flags = [];

  // Usage-based rules need a few days of history to be meaningful
  if (baseline.sampleDays >= 3 && baseline.dailyAvgUsageMinutes > 30 && todayUsage) {
    if (todayUsage.totalMinutes > 1.5 * baseline.dailyAvgUsageMinutes) {
      flags.push({
        type: 'usage_spike',
        metric: 'daily screen time (min)',
        value: round1(todayUsage.totalMinutes),
        baselineValue: baseline.dailyAvgUsageMinutes,
      });
    }

    const lateNightHours = [0, 1, 2, 3, 4];
    const lateNight = lateNightHours.reduce((s, h) => s + (todayUsage.hourlyMinutes[h] || 0), 0);
    const lateNightBaseline = lateNightHours.reduce((s, h) => s + (baseline.hourlyAvgUsageMinutes[h] || 0), 0);
    if (lateNight > Math.max(30, 2 * lateNightBaseline)) {
      flags.push({
        type: 'late_night_usage',
        metric: 'screen time between 00:00-05:00 (min)',
        value: round1(lateNight),
        baselineValue: round1(lateNightBaseline),
      });
    }
  }

  // Session-based rules need a few sessions of history
  if (baseline.sampleSessions >= 5) {
    if ((currentSession.focusLevel || 0) <= baseline.avgFocusLevel - 2) {
      flags.push({
        type: 'focus_drop',
        metric: 'session focus level (1-10)',
        value: currentSession.focusLevel || 0,
        baselineValue: baseline.avgFocusLevel,
      });
    }

    const drifts = (currentSession.driftEvents || []).length;
    if (drifts >= 2 && drifts > 2 * baseline.avgDriftEventsPerSession) {
      flags.push({
        type: 'drift_events',
        metric: 'blocked-app openings this session',
        value: drifts,
        baselineValue: baseline.avgDriftEventsPerSession,
      });
    }
  }

  return flags;
}

// ──────────────────────────────────────────────────────────────────────────────
// Gemini phrases the alert for a drift that has ALREADY been detected.
// Falls back to a deterministic message if the model call fails.
// ──────────────────────────────────────────────────────────────────────────────
async function generateDriftAlert(driftFlags, currentSession, baseline, apiKey) {
  const f = driftFlags[0];
  const fallback = {
    icon: 'warning',
    text: `Drift detected: ${f.metric} hit ${f.value} against your baseline of ${f.baselineValue}.`,
  };

  try {
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
      model: GEMINI_MODEL,
      generationConfig: { responseMimeType: 'application/json' },
    });

    const prompt = `
You are a cognitive performance analyst for the Entropy app.
Behavioral drift has ALREADY been detected by deterministic threshold rules.
Do not question or re-evaluate the detection — your only job is to phrase a
short, specific alert for the user referencing the actual numbers below.
Return ONLY a JSON object with no markdown, no explanation:
{
  "icon": "warning",
  "text": "One or two sentences, under 200 characters, citing the numbers."
}

Drift flags (metric, today's value, baseline value): ${JSON.stringify(driftFlags)}
User baseline: ${JSON.stringify(baseline)}
Latest session: ${JSON.stringify(currentSession)}
`;

    const result = await model.generateContent(prompt);
    const parsed = JSON.parse(result.response.text());
    return { icon: 'warning', text: parsed.text || fallback.text };
  } catch (e) {
    console.error('Gemini drift alert generation failed, using fallback:', e.message);
    return fallback;
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Post-session insight when no drift was detected (pre-existing behavior).
// ──────────────────────────────────────────────────────────────────────────────
async function analyzeDriftSession(currentSession, historicalSessions, apiKey) {
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: GEMINI_MODEL,
    generationConfig: { responseMimeType: "application/json" }
  });

  const prompt = `
You are a cognitive performance analyst for the Entropy app.
Analyze this focus session and the user's historical pattern.
Return ONLY a JSON object with no markdown, no explanation:
{
  "icon": "warning" | "lightbulb" | "info",
  "text": "One specific, data-driven insight referencing actual numbers from their session. Not generic advice."
}

Current session: ${JSON.stringify(currentSession)}
Recent sessions: ${JSON.stringify(historicalSessions)}
`;

  const result = await model.generateContent(prompt);
  const text = result.response.text();
  try {
    return JSON.parse(text);
  } catch (e) {
    console.error("Failed to parse Gemini output: ", text, e);
    return {
      icon: "info",
      text: `Focus session completed: '${currentSession.taskName}' lasted ${currentSession.durationMinutes.toFixed(1)} minutes.`
    };
  }
}

module.exports = { computeBaseline, detectDrift, generateDriftAlert, analyzeDriftSession };
