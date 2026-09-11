// Supabase Edge Function: Delete Account
// Deploy with: supabase functions deploy delete-account
//
// The Flutter app previously called `auth.admin.deleteUser()` directly from
// the client (lib/core/services/supabase_service.dart). That's a GoTrue
// *admin* API — it requires the service_role key, which the client is
// correctly initialized without (only the anon/publishable key ships in the
// app). So every self-deletion attempt from the app has always failed with
// 401/403 Unauthorized; there was no working account-deletion path at all,
// despite Play Store requiring one for apps with account creation.
//
// This function verifies the caller's own JWT (same pattern as
// verify-razorpay-payment), then uses the service_role key *server-side
// only* to delete exactly that caller's own auth.users row — never an
// id passed in the request body, so a caller can only ever delete
// themselves, not another user.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Identify the caller with the anon key + their own JWT — this is the
    // same pattern as every other edge function in this project. It cannot
    // be used to act on any other user's behalf.
    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    // auth.getUser() with no argument reads from the client's internal
    // session store, which a fresh server-side client never has — it always
    // threw "Auth session missing!" regardless of token validity (found
    // while testing this function; the same bug existed in
    // create-razorpay-order and verify-razorpay-payment and is fixed there
    // too). Passing the token explicitly validates it directly against
    // GoTrue instead.
    const token = authHeader.replace(/^Bearer\s+/i, "");
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Only now, with the caller's own verified id in hand, use the
    // service_role key — kept in this server-side function's env, never
    // shipped to the client — to actually delete the account.
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(user.id);
    if (deleteError) {
      console.error("[delete-account] deleteUser failed", deleteError.message);
      return new Response(JSON.stringify({ error: "Failed to delete account" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[delete-account] unexpected error", err);
    return new Response(JSON.stringify({ error: "Internal error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
