/**
 * Prayer-mat check, proxied to Claude.
 *
 * The Anthropic key cannot live in the app — anyone can pull it out of an IPA
 * in minutes and spend it. So the phone sends the photo here, this Worker adds
 * the key, and Claude answers.
 *
 * Cloudflare's free tier is 100,000 requests a day with no card, which is why
 * this is a Worker and not a Firebase Function: Cloud Functions would have
 * meant the Blaze plan for a feature that costs pennies.
 *
 * The photo is forwarded and dropped. Nothing is written to disk or logged.
 */

const MODEL = "claude-haiku-4-5";

// One yes/no question, no room to wander. Kept short because every token is
// billed on every prayer.
const SYSTEM = `You judge whether a photo shows a prayer mat (sajjada).

Answer with one word: MAT or OTHER.

MAT: a prayer mat or prayer rug, including plain embossed velvet ones with no
printed pattern, folded or travel mats, and mats being prayed on. An ordinary
decorative rug counts as MAT if it is clearly laid out and being used to pray.

OTHER: bare carpet or flooring, a towel or bedsheet, furniture, a wall or
ceiling, a person's face, a screen, or anything that is not a mat.

If it is genuinely unclear, answer MAT. Refusing someone who has just prayed is
worse than letting a carpet through.`;

function json(status, data) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": "*",
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
  return user ? { uid: user.localId } : null;
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-methods": "POST, OPTIONS",
          "access-control-allow-headers": "content-type, authorization",
        },
      });
    }
    if (request.method !== "POST") return json(405, { error: "POST only" });

    // Signed-in users only. Without this the endpoint is an open door to a
    // metered API and the bill is the owner's.
    const auth = request.headers.get("authorization") || "";
    const idToken = auth.startsWith("Bearer ") ? auth.slice(7) : "";
    if (!idToken) return json(401, { error: "missing token" });
    const user = await resolveUser(idToken, env.FIREBASE_API_KEY);
    if (!user) return json(401, { error: "invalid token" });

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json(400, { error: "bad json" });
    }
    const image = payload && payload.image;
    const mediaType = (payload && payload.mediaType) || "image/jpeg";
    if (typeof image !== "string" || image.length < 100) {
      return json(400, { error: "missing image" });
    }
    // A 512px JPEG is ~50KB, so ~68KB of base64. Anything far larger is a
    // mistake or an attempt to run up the bill.
    if (image.length > 400_000) return json(413, { error: "image too large" });

    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 8,
        system: SYSTEM,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: { type: "base64", media_type: mediaType, data: image },
              },
              { type: "text", text: "MAT or OTHER?" },
            ],
          },
        ],
      }),
    });

    if (!res.ok) {
      const detail = await res.text();
      // Never surface the upstream body to the app; it can echo request
      // details. The app treats any failure as "unsure" and lets the user
      // through, so a bad day here never blocks a prayer.
      console.log("anthropic error", res.status, detail.slice(0, 300));
      return json(502, { error: "upstream" });
    }

    const data = await res.json();
    const text = (data.content || [])
      .filter((b) => b.type === "text")
      .map((b) => b.text)
      .join(" ")
      .trim()
      .toUpperCase();

    const verdict = text.startsWith("MAT")
      ? "mat"
      : text.startsWith("OTHER")
        ? "other"
        : "unsure";

    return json(200, { verdict, usage: data.usage || null });
  },
};
