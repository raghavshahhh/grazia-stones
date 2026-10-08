// Returns the signed-in user's remaining AI Studio credits (does not spend any).

const { verifyRequestAuth } = require('./_supabaseAuth');
const credits = require('./_aiCredits');

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const auth = await verifyRequestAuth(req);
  if (auth.invalid) {
    res.status(401).json({ error: 'Invalid or expired session' });
    return;
  }
  if (!auth.authenticated) {
    res.status(401).json({ error: 'Login required', code: 'login_required' });
    return;
  }

  try {
    const s = await credits.status(auth.userId);
    res.status(200).json({ ...s, dailyLimit: credits.DAILY_LIMIT });
  } catch (err) {
    res.status(503).json({ error: 'Credits unavailable', code: 'credits_unavailable' });
  }
};
