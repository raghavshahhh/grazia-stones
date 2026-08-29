// Supabase Edge Function: Process AI Visualization
// Deploy with: supabase functions deploy process-ai-visualization

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

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const { jobId, inputImageUrl, stoneId, color, finish } = body;

    if (!jobId || !inputImageUrl) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Update job status to processing
    const startTime = Date.now();
    await supabase
      .from("ai_jobs")
      .update({
        status: "processing",
        started_at: new Date().toISOString(),
      })
      .eq("id", jobId)
      .eq("user_id", user.id);

    // Check if API key is configured
    const nvidiaApiKey = Deno.env.get("NVIDIA_NIM_API_KEY");
    const replicateApiToken = Deno.env.get("REPLICATE_API_TOKEN");

    if (!nvidiaApiKey && !replicateApiToken) {
      // Update job as failed with configuration error
      await supabase
        .from("ai_jobs")
        .update({
          status: "failed",
          error_message: "AI service not configured",
          completed_at: new Date().toISOString(),
        })
        .eq("id", jobId);

      return new Response(JSON.stringify({ 
        success: false, 
        error: "AI_SERVICE_NOT_CONFIGURED",
        message: "AI visualization service requires API configuration"
      }), {
        status: 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get stone texture if stoneId provided
    let textureUrl = null;
    if (stoneId) {
      const { data: stone } = await supabase
        .from("stones")
        .select("images, arTexture")
        .eq("id", stoneId)
        .single();
      
      if (stone) {
        textureUrl = stone.arTexture || (stone.images && stone.images[0]);
      }
    }

    // Call AI service (NVIDIA NIM or Replicate)
    let resultImageUrl: string | null = null;
    let aiProvider = "none";

    if (nvidiaApiKey) {
      // NVIDIA NIM API call
      aiProvider = "nvidia-nim";
      try {
        const nvidiaResponse = await fetch("https://api.nvcf.nvidia.com/v2/nvcf/pexec/functions/YOUR_FUNCTION_ID", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${nvidiaApiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            input_image: inputImageUrl,
            texture_image: textureUrl,
            color: color,
            finish: finish,
          }),
        });

        if (nvidiaResponse.ok) {
          const result = await nvidiaResponse.json();
          resultImageUrl = result.output_image_url || result.image_url;
        }
      } catch (err) {
        console.error("NVIDIA NIM error:", err);
      }
    }

    if (!resultImageUrl && replicateApiToken) {
      // Replicate API call as fallback
      aiProvider = "replicate";
      try {
        const replicateResponse = await fetch("https://api.replicate.com/v1/predictions", {
          method: "POST",
          headers: {
            "Authorization": `Token ${replicateApiToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            version: "YOUR_MODEL_VERSION",
            input: {
              image: inputImageUrl,
              texture: textureUrl,
              color: color,
            },
          }),
        });

        if (replicateResponse.ok) {
          const prediction = await replicateResponse.json();
          // Poll for completion
          let attempts = 0;
          while (attempts < 30 && prediction.status !== "succeeded" && prediction.status !== "failed") {
            await new Promise(resolve => setTimeout(resolve, 2000));
            const statusResponse = await fetch(prediction.urls.get, {
              headers: { "Authorization": `Token ${replicateApiToken}` },
            });
            const status = await statusResponse.json();
            if (status.status === "succeeded" && status.output) {
              resultImageUrl = Array.isArray(status.output) ? status.output[0] : status.output;
              break;
            }
            if (status.status === "failed") break;
            attempts++;
          }
        }
      } catch (err) {
        console.error("Replicate error:", err);
      }
    }

    const processingTime = Date.now() - startTime;

    if (resultImageUrl) {
      // Success - update job
      await supabase
        .from("ai_jobs")
        .update({
          status: "completed",
          result_image_url: resultImageUrl,
          processing_time_ms: processingTime,
          completed_at: new Date().toISOString(),
          metadata: {
            ai_provider: aiProvider,
            texture_url: textureUrl,
          },
        })
        .eq("id", jobId);

      return new Response(JSON.stringify({
        success: true,
        jobId,
        resultImageUrl,
        processingTimeMs: processingTime,
      }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } else {
      // Failed - update job
      await supabase
        .from("ai_jobs")
        .update({
          status: "failed",
          error_message: "AI service did not return a result",
          processing_time_ms: processingTime,
          completed_at: new Date().toISOString(),
        })
        .eq("id", jobId);

      return new Response(JSON.stringify({
        success: false,
        error: "AI_PROCESSING_FAILED",
        message: "AI service failed to generate visualization",
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

  } catch (err) {
    console.error("Process AI visualization error:", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
