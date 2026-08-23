# Layla welcome email

A single Cloudflare Worker that sends one greeting when somebody creates an
account. Chosen over a Firebase Cloud Function because Functions require the
Blaze plan, and the free Spark tier blocks the outbound network call that
sending mail needs.

## Why it cannot be abused

The request body carries no address. The client sends only its Firebase ID
token; the Worker asks Google whose token it is and mails the address Google
returns. Someone who finds the URL can, at worst, send themselves a welcome
email.

## Deploy

    cd worker
    npx wrangler login                     # opens the browser once
    npx wrangler secret put RESEND_API_KEY # paste the key from resend.com
    npx wrangler deploy

`wrangler deploy` prints the URL. Put it in `lib/core/config/app_config.dart`.

## Free tiers, checked 2026-08-22

- Cloudflare Workers — 100,000 requests/day, no card required
- Resend — 3,000 emails/month (100/day), no card required

One sign-up is one request, so neither limit is in reach.

## Sending domain

`MAIL_FROM` uses `onboarding@resend.dev`, which works immediately but is
Resend's shared test domain. To send from your own address, verify a domain in
Resend and change `MAIL_FROM` in `wrangler.toml`.
