// delete-account — Permanently delete the authenticated user's account.
//
// POST /functions/v1/delete-account
// Authorization: Bearer <supabase-jwt>
// Body: (none)
// Response: { "success": true } | { "error": "..." }
//
// Deploy:
//   supabase functions deploy delete-account

// @ts-expect-error: Deno URL import
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
// @ts-expect-error: Deno URL import
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// deno-lint-ignore no-explicit-any
declare const Deno: any;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supaAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

async function handler(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  // 1. Authenticate caller
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "missing auth" }, 401);

  const jwt = authHeader.replace("Bearer ", "");
  const {
    data: { user },
    error: authError,
  } = await supaAdmin.auth.getUser(jwt);
  if (authError || !user) return json({ error: "invalid token" }, 401);

  const uid = user.id;

  // 2. Anonymize preserved records
  const anonymize = [
    supaAdmin.from("articles").update({ author_id: null }).eq("author_id", uid),
    supaAdmin.from("goals").update({ scorer_id: null }).eq("scorer_id", uid),
    supaAdmin.from("goals").update({ assist_id: null }).eq("assist_id", uid),
    supaAdmin.from("feedback").update({ user_id: null }).eq("user_id", uid),
  ];
  const results = await Promise.all(anonymize);
  for (const r of results) {
    if (r.error) {
      console.error("[delete-account] anonymize failed:", r.error);
      return json({ error: "failed to anonymize data" }, 500);
    }
  }

  // 3. Delete rows from tables with bare FK references to profiles
  const cleanup = [
    supaAdmin.from("match_participants").delete().eq("user_id", uid),
    supaAdmin.from("pickup_slots").delete().eq("user_id", uid),
    supaAdmin.from("comments").delete().eq("author_id", uid),
    supaAdmin.from("messages").delete().eq("sender_id", uid),
    supaAdmin.from("teams").delete().eq("captain_id", uid),
    supaAdmin.from("events").delete().eq("creator_id", uid),
  ];
  const cleanupResults = await Promise.all(cleanup);
  for (const r of cleanupResults) {
    if (r.error) {
      console.error("[delete-account] cleanup failed:", r.error);
      return json({ error: "failed to clean up data" }, 500);
    }
  }

  // 4. Delete auth user (cascades profiles + all ON DELETE CASCADE rows)
  const { error: deleteError } = await supaAdmin.auth.admin.deleteUser(uid);
  if (deleteError) {
    console.error("[delete-account] deleteUser failed:", deleteError);
    return json({ error: "failed to delete user" }, 500);
  }

  return json({ success: true });
}

serve(handler);
