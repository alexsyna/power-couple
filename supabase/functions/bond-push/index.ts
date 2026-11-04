// Sends Bond push notifications through Firebase Cloud Messaging.
//
// Called by a database trigger after each new answer, with { answer_id }.
// Everything else is read here with the service role, and each answer is
// handled once (question_answers.notified_at), so the endpoint is safe to
// leave without a secret.
//
// Secret required (Supabase → Edge Functions → Secrets):
//   FCM_SERVICE_ACCOUNT: the Firebase service account JSON, pasted whole.
import { createClient } from "jsr:@supabase/supabase-js@2";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  let answerId: string | undefined;
  try {
    answerId = (await req.json())?.answer_id;
  } catch {
    // fall through
  }
  if (!answerId) return new Response("missing answer_id", { status: 400 });

  // Claim the answer so it's only ever handled once.
  const { data: claimed, error } = await db
    .from("question_answers")
    .update({ notified_at: new Date().toISOString() })
    .eq("id", answerId)
    .is("notified_at", null)
    .select("couple_id, user_id, day")
    .maybeSingle();
  if (error) return new Response(error.message, { status: 500 });
  if (!claimed) return new Response("already handled");

  const { data: members } = await db
    .from("couple_members")
    .select("user_id")
    .eq("couple_id", claimed.couple_id);
  const partnerId = members?.map((m) => m.user_id).find((id) => id !== claimed.user_id);
  if (!partnerId) return new Response("no partner");

  const { data: partnerAnswer } = await db
    .from("question_answers")
    .select("id")
    .eq("user_id", partnerId)
    .eq("day", claimed.day)
    .maybeSingle();

  let body: string;
  if (partnerAnswer) {
    body = "💞 Both answers are in! Tap to reveal.";
  } else {
    const { data: profile } = await db
      .from("profiles")
      .select("display_name")
      .eq("id", claimed.user_id)
      .maybeSingle();
    const name = profile?.display_name ?? "Your partner";
    body = `💌 ${name} answered today's question. Your turn!`;
  }

  const { data: tokens } = await db
    .from("device_tokens")
    .select("token")
    .eq("user_id", partnerId);
  if (!tokens?.length) return new Response("partner has notifications off");

  const account = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
  const accessToken = await googleAccessToken(account);
  let sent = 0;
  for (const { token } of tokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
      {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: {
            token,
            notification: { body },
            data: { tab: "bond" },
            apns: { payload: { aps: { sound: "default" } } },
          },
        }),
      },
    );
    if (res.ok) {
      sent++;
    } else {
      const text = await res.text();
      console.error(`FCM ${res.status}: ${text}`);
      // The app was deleted from that phone: forget it.
      if (text.includes("UNREGISTERED")) {
        await db.from("device_tokens").delete().eq("token", token);
      }
    }
  }
  return new Response(`sent ${sent}/${tokens.length}`);
});

/** OAuth access token for FCM from a service account (JWT bearer flow). */
async function googleAccessToken(account: { client_email: string; private_key: string }) {
  const now = Math.floor(Date.now() / 1000);
  const b64url = (data: string | Uint8Array) =>
    btoa(typeof data === "string" ? data : String.fromCharCode(...data))
      .replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = account.private_key.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`)),
  );
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${b64url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`Google token error: ${await res.text()}`);
  return (await res.json()).access_token as string;
}
