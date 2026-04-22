// room-info — Query LiveKit room participant count without joining.
//
// GET /functions/v1/room-info?matchId=<uuid>
// Authorization: Bearer <supabase-jwt>
// Response: { "participantCount": 12, "isActive": true }

// @ts-expect-error: Deno URL import
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
// @ts-expect-error: Deno URL import
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
// @ts-expect-error: Deno URL import
import { RoomServiceClient } from "https://esm.sh/livekit-server-sdk@2.6.1";

// deno-lint-ignore no-explicit-any
declare const Deno: any;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const LIVEKIT_API_KEY = Deno.env.get("LIVEKIT_API_KEY")!;
const LIVEKIT_API_SECRET = Deno.env.get("LIVEKIT_API_SECRET")!;
const LIVEKIT_WS_URL = Deno.env.get("LIVEKIT_WS_URL")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const livekitHost = LIVEKIT_WS_URL.replace("wss://", "https://");
const roomService = new RoomServiceClient(livekitHost, LIVEKIT_API_KEY, LIVEKIT_API_SECRET);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function handler(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "GET") {
    return new Response("method not allowed", { status: 405, headers: corsHeaders });
  }

  // 1. Verify caller
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "missing auth" }), {
      status: 401,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }
  const jwt = authHeader.replace("Bearer ", "");
  const { error: authError } = await supabase.auth.getUser(jwt);
  if (authError) {
    return new Response(JSON.stringify({ error: "invalid token" }), {
      status: 401,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }

  // 2. Get matchId from query string
  const url = new URL(req.url);
  const matchId = url.searchParams.get("matchId");
  if (!matchId) {
    return new Response(JSON.stringify({ error: "missing matchId param" }), {
      status: 400,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }

  const roomName = `match_${matchId}`;

  // 3. Query LiveKit for room participants
  try {
    const participants = await roomService.listParticipants(roomName);
    return new Response(
      JSON.stringify({
        participantCount: participants.length,
        isActive: true,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "content-type": "application/json" },
      },
    );
  } catch {
    return new Response(
      JSON.stringify({ participantCount: 0, isActive: false }),
      {
        status: 200,
        headers: { ...corsHeaders, "content-type": "application/json" },
      },
    );
  }
}

serve(handler);
