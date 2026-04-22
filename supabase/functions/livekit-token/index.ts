// livekit-token — Generate a LiveKit access token for a match room.
//
// POST /functions/v1/livekit-token
// Authorization: Bearer <supabase-jwt>
// Body: { "matchId": "uuid" }
// Response: { "token": "...", "roomName": "match_<id>", "wsUrl": "wss://..." }
//
// Deploy:
//   supabase functions deploy livekit-token
//   supabase secrets set LIVEKIT_API_KEY=... LIVEKIT_API_SECRET=... LIVEKIT_WS_URL=...

// @ts-expect-error: Deno URL import
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
// @ts-expect-error: Deno URL import
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
// @ts-expect-error: Deno URL import
import { AccessToken } from "https://esm.sh/livekit-server-sdk@2.6.1";

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

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function handler(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405, headers: corsHeaders });
  }

  // 1. Verify caller identity from Supabase JWT
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "missing auth" }), {
      status: 401,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }
  const jwt = authHeader.replace("Bearer ", "");
  const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "invalid token" }), {
      status: 401,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }

  // 2. Parse body
  let matchId: string;
  try {
    const body = await req.json();
    matchId = body.matchId;
    if (!matchId) throw new Error("missing matchId");
  } catch {
    return new Response(JSON.stringify({ error: "invalid body, need { matchId }" }), {
      status: 400,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }

  // 3. Look up match + event to determine role
  const { data: match, error: matchErr } = await supabase
    .from("matches")
    .select("id, event_id")
    .eq("id", matchId)
    .single();
  if (matchErr || !match) {
    return new Response(JSON.stringify({ error: "match not found" }), {
      status: 404,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }

  const { data: event, error: eventErr } = await supabase
    .from("events")
    .select("creator_id")
    .eq("id", match.event_id)
    .single();
  if (eventErr || !event) {
    return new Response(JSON.stringify({ error: "event not found" }), {
      status: 404,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }

  const isHost = event.creator_id === user.id;
  const roomName = `match_${matchId}`;

  // 4. Generate LiveKit access token
  const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
    identity: user.id,
    name: user.user_metadata?.name || user.email || "anonymous",
    ttl: "6h",
  });
  at.addGrant({
    room: roomName,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
    roomAdmin: isHost,
  });
  const token = await at.toJwt();

  return new Response(
    JSON.stringify({ token, roomName, wsUrl: LIVEKIT_WS_URL }),
    {
      status: 200,
      headers: { ...corsHeaders, "content-type": "application/json" },
    },
  );
}

serve(handler);
