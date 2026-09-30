// Supabase Edge Function: Verify Razorpay Payment
// Deploy with: supabase functions deploy verify-razorpay-payment

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
    // Verify user authentication
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    // See create-razorpay-order/index.ts: auth.getUser() with no argument
    // reads client-side session state that a fresh server-side client never
    // has, so this always failed regardless of token validity. Pass the
    // token explicitly to validate it directly against GoTrue.
    const token = authHeader.replace(/^Bearer\s+/i, "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const { orderId, paymentId, signature } = body;

    if (!orderId || !paymentId || !signature) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const razorpayKeySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
    if (!razorpayKeySecret) {
      return new Response(JSON.stringify({ error: "Payment gateway not configured" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // `orderId` is our DB order id. Razorpay signs `<razorpay_order_id>|<payment_id>`,
    // so load the razorpay_order_id that create-razorpay-order stored on this
    // (caller-owned) order instead of trusting anything the client sends.
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("id, razorpay_order_id, payment_status")
      .eq("id", orderId)
      .eq("user_id", user.id)
      .single();

    if (orderError || !order || !order.razorpay_order_id) {
      return new Response(JSON.stringify({ error: "Order not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify signature (global WebCrypto; the std/crypto module has no `subtle`)
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      encoder.encode(razorpayKeySecret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );

    const message = encoder.encode(`${order.razorpay_order_id}|${paymentId}`);
    const sig = await crypto.subtle.sign("HMAC", key, message);
    const expectedSignature = Array.from(new Uint8Array(sig))
      .map(b => b.toString(16).padStart(2, "0"))
      .join("");

    // Constant-time compare
    let diff = expectedSignature.length ^ String(signature).length;
    for (let i = 0; i < expectedSignature.length; i++) {
      diff |= expectedSignature.charCodeAt(i) ^ (String(signature).charCodeAt(i) || 0);
    }
    const isValid = diff === 0;

    if (!isValid) {
      // Mark payment as failed
      await supabase
        .from("orders")
        .update({
          payment_status: "failed",
          payment_failure_reason: "Invalid signature",
        })
        .eq("id", orderId)
        .eq("user_id", user.id);

      return new Response(JSON.stringify({ 
        success: false, 
        error: "Invalid payment signature" 
      }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Update order with successful payment
    const { error: updateError } = await supabase
      .from("orders")
      .update({
        payment_status: "completed",
        razorpay_payment_id: paymentId,
        razorpay_signature: signature,
        status: "confirmed",
      })
      .eq("id", orderId)
      .eq("user_id", user.id);

    if (updateError) {
      console.error("Order update error:", updateError);
      return new Response(JSON.stringify({ error: "Failed to update order" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ 
      success: true, 
      message: "Payment verified successfully" 
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("Verify payment error:", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});