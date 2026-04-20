// send_push — fan-out push delivery via FCM HTTP v1.
//
// Invocation sources:
//   1. pg_cron scheduled job scanning match_reminders (see
//      supabase/migrations/future_cron_reminders.sql)
//   2. AFTER INSERT trigger on messages (chat deliveries)
//   3. Ad-hoc from the app (test button in settings/dev_tools)
//
// Deploy:
//   supabase functions deploy send_push
//   supabase secrets set FCM_SERVICE_ACCOUNT='<base64 service-account.json>'
//
// Body shape:
//   { "user_ids": string[], "title"?: string, "body"?: string,
//     "data"?: { "route": string, [k:string]: string } }
//
// NOTE: This file is a skeleton — replace `TODO` markers before first
// production run. The function runs on Deno; imports use URL-based modules.

// @ts-expect-error: Deno module resolution (URL imports) is not typed by default.
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
// @ts-expect-error: Deno module resolution (URL imports) is not typed by default.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// deno-lint-ignore no-explicit-any
declare const Deno: any;

interface PushBody {
  user_ids: string[];
  title?: string;
  body?: string;
  data?: Record<string, string>;
}

interface Subscription {
  token: string;
  platform: "ios" | "android" | "web";
  user_id: string;
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
// Base64-encoded GCP service account JSON (for FCM HTTP v1 auth).
const FCM_SERVICE_ACCOUNT_B64 = Deno.env.get("FCM_SERVICE_ACCOUNT");

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

async function handler(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  let payload: PushBody;
  try {
    payload = await req.json();
  } catch {
    return new Response("invalid json", { status: 400 });
  }

  if (!payload.user_ids || payload.user_ids.length === 0) {
    return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
  }

  const { data: subs, error } = await supabase
    .from("push_subscriptions")
    .select("token, platform, user_id")
    .in("user_id", payload.user_ids);

  if (error) {
    console.error("[send_push] lookup failed:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }

  const tokens = (subs as Subscription[]).map((s) => s.token);
  if (tokens.length === 0) {
    return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
  }

  if (!FCM_SERVICE_ACCOUNT_B64) {
    console.warn(
      "[send_push] FCM_SERVICE_ACCOUNT not set — skipping delivery",
    );
    return new Response(
      JSON.stringify({
        sent: 0,
        skipped: "FCM_SERVICE_ACCOUNT not set",
      }),
      { status: 200 },
    );
  }

  let sent = 0;
  const failures: Array<{ token: string; error: string }> = [];

  for (const token of tokens) {
    const ok = await sendToToken(token, payload);
    if (ok) sent++;
    else failures.push({ token, error: "fcm send failed" });
  }

  return new Response(
    JSON.stringify({ sent, failures }),
    { status: 200, headers: { "content-type": "application/json" } },
  );
}

// TODO(S4): Implement real FCM HTTP v1 send using OAuth2 minted from the
// service-account JSON. Structure:
//   1. Decode FCM_SERVICE_ACCOUNT_B64 → JSON.
//   2. Mint a JWT → exchange for an access token at oauth2.googleapis.com.
//   3. POST https://fcm.googleapis.com/v1/projects/{projectId}/messages:send
//      with { message: { token, notification: {...}, data: {...} } }.
// Keep the access token cached (~55 min) across invocations.
async function sendToToken(token: string, body: PushBody): Promise<boolean> {
  console.log("[send_push:stub] would send to", token.slice(0, 12), "…", {
    title: body.title,
    body: body.body,
    data: body.data,
  });
  return true;
}

serve(handler);
