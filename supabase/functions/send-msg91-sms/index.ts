import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const MSG91_AUTH_KEY = Deno.env.get("MSG91_AUTH_KEY");
const MSG91_FLOW_ID = Deno.env.get("MSG91_FLOW_ID") || Deno.env.get("MSG91_TEMPLATE_ID");
const MSG91_SENDER_ID = Deno.env.get("MSG91_SENDER_ID") || "GRAZIA";

serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return new Response("ok", {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
        },
      });
    }

    if (!MSG91_AUTH_KEY || !MSG91_FLOW_ID) {
      console.error("❌ MSG91_AUTH_KEY or MSG91_FLOW_ID environment variable is missing.");
      return new Response(
        JSON.stringify({ error: "MSG91 SMS credentials not configured on server." }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const payload = await req.json();
    console.log("宿 Received Supabase Auth SMS Hook Payload:", JSON.stringify(payload));

    const recipientPhone = payload.user?.phone || payload.phone;
    const otpCode = payload.sms?.otp || payload.otp;

    if (!recipientPhone || !otpCode) {
      return new Response(
        JSON.stringify({ error: "Missing phone number or OTP code in request payload." }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Strip leading '+' for MSG91 mobiles format (e.g. "+919924875382" -> "919924875382")
    const cleanMobile = recipientPhone.replace(/\+/g, "").trim();

    // Call official MSG91 Flow API v5
    const msg91Response = await fetch("https://control.msg91.com/api/v5/flow/", {
      method: "POST",
      headers: {
        "authkey": MSG91_AUTH_KEY,
        "content-type": "application/json",
        "accept": "application/json",
      },
      body: JSON.stringify({
        template_id: MSG91_FLOW_ID,
        sender: MSG91_SENDER_ID,
        short_url: "0",
        recipients: [
          {
            mobiles: cleanMobile,
            otp: otpCode,
          },
        ],
      }),
    });

    const msg91Result = await msg91Response.json();
    console.log("✅ MSG91 API Response:", JSON.stringify(msg91Result));

    if (!msg91Response.ok || msg91Result.type === "error") {
      return new Response(
        JSON.stringify({ error: msg91Result.message || "MSG91 API dispatch failed." }),
        { status: 502, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, message: "MSG91 SMS dispatched successfully.", data: msg91Result }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("❌ Exception in send-msg91-sms Edge Function:", err.message);
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error." }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
