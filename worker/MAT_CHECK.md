# Prayer-mat check Worker

Claude judges the Step 2 photo. The phone cannot hold the Anthropic key — it
would be extracted from the IPA within minutes — so the photo comes here, the
Worker adds the key, and Claude answers.

Cloudflare's free tier is 100,000 requests/day with no card. That is why this
is a Worker rather than a Firebase Function: Cloud Functions would have needed
the Blaze plan for a feature costing a few pounds a month.

## Deploy

    cd worker
    npx wrangler secret put ANTHROPIC_API_KEY --config wrangler.mat.toml
    npx wrangler deploy --config wrangler.mat.toml

Live at <https://layla-mat-check.adenzia04.workers.dev>.

`workers_dev = true` in `wrangler.mat.toml` is what gives it that address, and
it is not optional. Deployed without it the Worker uploads cleanly, takes the
secret, and reports "No URLs enabled" with zero invocations — no error
anywhere, just nothing to call. It sat in that state for a day.

## Building the app against it

The endpoint reaches the app through `--dart-define`, and a build that forgets
it silently loses the feature: `AppConfig.matCheckEndpoint` falls back to the
empty string, `canAskClaudeAboutMat` goes false, and the on-device check
decides alone with nothing logged. So it lives in a file rather than in
whichever command line last remembered it:

    flutter run --release --dart-define-from-file=dart_defines.json
    flutter build ios --release --dart-define-from-file=dart_defines.json

`dart_defines.json` holds no secrets — the endpoint is public and refuses
anyone without a Firebase ID token.

## What it costs

`claude-haiku-4-5`, one image plus a short prompt: roughly **£0.0005 per
check**. The app only escalates photos the on-device check is unsure about —
around 5–10% — so 100 users praying five times a day is a few pounds a month,
not the ~£9 it would be if every photo were sent.

## What it does not do

No photo is stored or logged, here or at Anthropic. It is forwarded, judged,
and dropped. Only signed-in users can call it, or the endpoint would be an
open door to a metered API on your bill.
