const { GoogleGenerativeAI } = require('@google/generative-ai');

async function generateWeeklyPlan(sessions, appUsage, apiKey) {
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ 
    model: "gemini-1.5-flash",
    generationConfig: { responseMimeType: "application/json" }
  });

  const prompt = `
You are a weekly performance planner. Analyze this user's 4-week session history.
Return ONLY JSON:
{
  "summary": "2-3 sentence performance summary referencing actual numbers",
  "recommendations": [
    "Specific recommendation 1 with data reference",
    "Specific recommendation 2 with data reference",
    "Specific recommendation 3 with data reference"
  ]
}

Sessions (4 weeks): ${JSON.stringify(sessions)}
App usage (2 weeks): ${JSON.stringify(appUsage)}
`;

  const result = await model.generateContent(prompt);
  const text = result.response.text();
  try {
    return JSON.parse(text);
  } catch (e) {
    console.error("Failed to parse Gemini weekly plan output: ", text, e);
    const totalSessions = sessions.length;
    const totalMinutes = sessions.reduce((sum, s) => sum + (s.durationMinutes || 0), 0);
    return {
      summary: `You logged ${totalSessions} focus sessions totaling ${Math.round(totalMinutes / 60)} hours over the past 4 weeks. Continue building your momentum.`,
      recommendations: [
        "Schedule your deepest focus work during your historically strongest time blocks.",
        "Reduce screen time on evenings before high-intensity focus days.",
        "Try to log at least 3 sessions per day to build consistent focus habits."
      ]
    };
  }
}

module.exports = { generateWeeklyPlan };
