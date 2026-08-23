/**
 * Layla — welcome email.
 *
 * The one job: send a greeting to somebody who has just created an account.
 *
 * The address is never taken from the request body. The client sends only its
 * Firebase ID token; this asks Google who that token belongs to and mails the
 * address Google returns. That is what stops the endpoint being used as an
 * open relay — a stranger with the URL can, at most, send a welcome email to
 * themselves.
 */

const ALLOWED_ORIGIN = "*";

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": ALLOWED_ORIGIN,
    },
  });
}

/** Asks Google to resolve an ID token. Returns null if it is not valid. */
async function resolveUser(idToken, apiKey) {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${apiKey}`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ idToken }),
    },
  );
  if (!res.ok) return null;
  const data = await res.json();
  const user = data.users && data.users[0];
  if (!user || !user.email) return null;
  return { email: user.email, name: user.displayName || "", uid: user.localId };
}

function body(name) {
  const greeting = name ? `Assalamu alaikum, ${name}` : "Assalamu alaikum";
  return `
<div style="background:#060D1B;padding:32px 0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
  <div style="max-width:520px;margin:0 auto;background:#0B1B34;border-radius:18px;padding:32px;color:#FAF6EE">
    <h1 style="margin:0 0 6px;font-size:26px;color:#FAF6EE">${greeting}</h1>
    <p style="margin:0 0 24px;color:#D9B26A;font-size:15px">Welcome to Layla.</p>

    <p style="margin:0 0 16px;line-height:1.6;color:#C7D2E3;font-size:15px">
      Layla keeps your prayers close: accurate times for where you are, the
      direction of the Kaaba, dhikr, and supplications from the Qur'an and
      Sunnah.
    </p>
    <p style="margin:0 0 16px;line-height:1.6;color:#C7D2E3;font-size:15px">
      When a prayer begins, your phone quietens down for thirty minutes. Confirm
      the prayer and your streak grows. Miss one and you can say so honestly —
      the streak resets, and nothing pretends otherwise.
    </p>
    <p style="margin:0;line-height:1.6;color:#8C9AB0;font-size:13px">
      May your prayers be accepted.
    </p>
  </div>
</div>`.trim();
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "access-control-allow-origin": ALLOWED_ORIGIN,
          "access-control-allow-methods": "POST, OPTIONS",
          "access-control-allow-headers": "content-type, authorization",
        },
      });
    }
    if (request.method !== "POST") return json(405, { error: "POST only" });

    const auth = request.headers.get("authorization") || "";
    const idToken = auth.startsWith("Bearer ") ? auth.slice(7) : "";
    if (!idToken) return json(401, { error: "missing token" });

    const user = await resolveUser(idToken, env.FIREBASE_API_KEY);
    if (!user) return json(401, { error: "invalid token" });

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        authorization: `Bearer ${env.RESEND_API_KEY}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        from: env.MAIL_FROM,
        to: [user.email],
        subject: "Welcome to Layla",
        html: body(user.name),
      }),
    });

    if (!res.ok) {
      const detail = await res.text();
      // Surfaced, not swallowed: a silent failure here means nobody ever
      // learns that welcome mail stopped going out.
      return json(502, { error: "send failed", detail: detail.slice(0, 300) });
    }
    return json(200, { sent: true });
  },
};
