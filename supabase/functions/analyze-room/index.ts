// Supabase Edge Function: Analyze Room for Wall Detection
// Deploy with: supabase functions deploy analyze-room

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface DetectedWall {
  id: string;
  confidence: number;
  polygon: number[][];
  boundingBox: { [key: string]: number };
  area: number;
}

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
    const { imageUrl, imageBase64 } = body;

    if (!imageUrl && !imageBase64) {
      return new Response(JSON.stringify({ error: "Missing image data" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check if AI service is configured
    const nvidiaApiKey = Deno.env.get("NVIDIA_NIM_API_KEY");
    const replicateApiToken = Deno.env.get("REPLICATE_API_TOKEN");

    if (!nvidiaApiKey && !replicateApiToken) {
      // Return configuration required response
      return new Response(JSON.stringify({
        success: false,
        error: "AI_SERVICE_NOT_CONFIGURED",
        message: "Room analysis requires AI service configuration",
        wallDetected: false,
        confidence: 0,
        walls: [],
        objects: [],
      }), {
        status: 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let walls: DetectedWall[] = [];
    let overallConfidence = 0;

    // Call AI service for semantic segmentation / object detection
    if (nvidiaApiKey) {
      try {
        const response = await fetch("https://api.nvcf.nvidia.com/v2/nvcf/pexec/functions/YOUR_SEGMENTATION_FUNCTION", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${nvidiaApiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            image: imageBase64 || imageUrl,
            classes: ["wall", "floor", "ceiling", "furniture", "window", "door"],
          }),
        });

        if (response.ok) {
          const result = await response.json();
          // Process segmentation results
          if (result.detections) {
            walls = result.detections
              .filter((d: any) => d.class === "wall" && d.confidence > 0.5)
              .map((d: any, idx: number) => ({
                id: `wall_${idx}`,
                confidence: d.confidence,
                polygon: d.polygon || [],
                boundingBox: d.bbox || {},
                area: d.area || 0,
              }));
            
            overallConfidence = walls.length > 0 
              ? walls.reduce((sum, w) => sum + w.confidence, 0) / walls.length
              : 0;
          }
        }
      } catch (err) {
        console.error("NVIDIA segmentation error:", err);
      }
    }

    // Fallback to Replicate if NVIDIA didn't work
    if (walls.length === 0 && replicateApiToken) {
      try {
        // Use Segment Anything Model or similar
        const response = await fetch("https://api.replicate.com/v1/predictions", {
          method: "POST",
          headers: {
            "Authorization": `Token ${replicateApiToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            version: "SAM_MODEL_VERSION",
            input: {
              image: imageBase64 || imageUrl,
            },
          }),
        });

        if (response.ok) {
          const prediction = await response.json();
          // Poll for results
          let attempts = 0;
          while (attempts < 20) {
            await new Promise(resolve => setTimeout(resolve, 1000));
            const statusResponse = await fetch(prediction.urls.get, {
              headers: { "Authorization": `Token ${replicateApiToken}` },
            });
            const status = await statusResponse.json();
            
            if (status.status === "succeeded" && status.output) {
              // Process segmentation masks
              const segments = Array.isArray(status.output) ? status.output : [status.output];
              walls = segments
                .filter((s: any) => s.label === "wall")
                .map((s: any, idx: number) => ({
                  id: `wall_${idx}`,
                  confidence: s.score || 0.7,
                  polygon: s.polygon || [],
                  boundingBox: s.bbox || {},
                  area: s.area || 0,
                }));
              
              overallConfidence = walls.length > 0
                ? walls.reduce((sum, w) => sum + w.confidence, 0) / walls.length
                : 0;
              break;
            }
            if (status.status === "failed") break;
            attempts++;
          }
        }
      } catch (err) {
        console.error("Replicate segmentation error:", err);
      }
    }

    // Return results
    const wallDetected = walls.length > 0 && overallConfidence > 0.3;

    return new Response(JSON.stringify({
      success: true,
      wallDetected,
      confidence: overallConfidence,
      walls,
      objects: [], // Can add other detected objects
      message: wallDetected 
        ? `Detected ${walls.length} wall surface${walls.length > 1 ? 's' : ''}`
        : "No clear wall surfaces detected",
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("Analyze room error:", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
