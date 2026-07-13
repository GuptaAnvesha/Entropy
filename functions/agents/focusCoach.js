const { GoogleGenerativeAI } = require('@google/generative-ai');

async function getFocusCoachDecision(session, event, elapsedMinutes, appName, driftPattern, apiKey) {
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ 
    model: "gemini-1.5-flash",
    generationConfig: { responseMimeType: "application/json" }
  });

  const prompt = `
You are a real-time focus coach. The user is in an active focus session.
Event: ${event}
Elapsed: ${elapsedMinutes} minutes
App detected: ${appName || "none"}
Historical pattern: ${JSON.stringify(driftPattern)}
Current session data: ${JSON.stringify(session)}

Return ONLY JSON:
{
  "action": "warn" | "end_session" | "nudge",
  "message": "Short, direct message under 60 characters for push notification"
}

Rules:
- "warn" if this is first drift in session and elapsed > 15 min
- "end_session" if user has drifted 3+ times this session
- "nudge" for milestone events (20min, 45min, 60min)
- Message must be specific to their situation, not generic
`;

  const result = await model.generateContent(prompt);
  const text = result.response.text();
  try {
    return JSON.parse(text);
  } catch (e) {
    console.error("Failed to parse Gemini output: ", text, e);
    let action = "warn";
    let message = "Keep focusing! Avoid distractions.";
    if (session.driftEvents && session.driftEvents.length >= 3) {
      action = "end_session";
      message = "Session terminated due to multiple drifts.";
    }
    return { action, message };
  }
}

module.exports = { getFocusCoachDecision };
