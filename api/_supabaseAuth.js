// Shared Supabase JWT verification for the paid AI proxy endpoints
// (wall-detect, generate-visualization).
//
// GUEST MODE IS INTENTIONAL CURRENT PRODUCT BEHAVIOUR: the AI Room Studio
// route (/ai-viz) has no login gate in the Flutter app — logged-out users
// can already use it. Making these endpoints require a session would break
// that. So this module does NOT reject every unauthenticated request; it
// distinguishes three cases:
//   1. No Authorization header at all       -> guest, allowed, tighter rate limit
//   2. Authorization header with a token that Supabase confirms is valid
//                                            -> authenticated, allowed, normal rate limit
//   3. Authorization header with a token Supabase rejects (expired/garbage/
//      tampered)                            -> always rejected (401)
//
// Verification is delegated to Supabase's own GoTrue /auth/v1/user endpoint
// rather than reimplementing JWT signature checking here — this project's
// keys include a JWKS URL (i.e. may be signed asymmetrically / rotate), so
// asking Supabase to validate the token itself is the only approach that's
// correct regardless of signing algorithm or key rotation, and it requires
// no extra npm dependency in this dependency-free serverless function.

async function verifyRequestAuth(req) {
  const authHeader = req.headers['authorization'] || req.headers['Authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return { authenticated: false, userId: null, invalid: false }; // guest
  }

  const token = authHeader.slice('Bearer '.length).trim();
  if (!token) {
    return { authenticated: false, userId: null, invalid: false }; // guest
  }

  const supabaseUrl = (process.env.SUPABASE_URL || '').trim();
  const anonKey = (process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLISHABLE_KEY || '').trim();
  if (!supabaseUrl || !anonKey) {
    // Auth backend not configured server-side — fail closed on a *provided*
    // token (we can't tell if it's valid) rather than silently trusting it.
    console.error('[supabaseAuth] SUPABASE_URL/ANON_KEY not configured on server');
    return { authenticated: false, userId: null, invalid: true };
  }

  try {
    const resp = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: {
        Authorization: `Bearer ${token}`,
        apikey: anonKey,
      },
    });
    if (!resp.ok) {
      return { authenticated: false, userId: null, invalid: true };
    }
    const user = await resp.json();
    if (!user || !user.id) {
      return { authenticated: false, userId: null, invalid: true };
    }
    return { authenticated: true, userId: user.id, invalid: false };
  } catch (e) {
    console.error('[supabaseAuth] verification request failed', e.message);
    // Network failure verifying a *provided* token — fail closed.
    return { authenticated: false, userId: null, invalid: true };
  }
}

module.exports = { verifyRequestAuth };
