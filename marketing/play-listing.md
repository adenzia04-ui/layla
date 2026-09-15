# Google Play listing — Layla Pro

Package `com.adenzia.layla`. Everything below is ready to paste into Play
Console. Nothing here claims a feature the Android build does not have.

## App name (30 characters max)

    Layla Pro: Prayer Times

## Short description (80 characters max)

    Prayer times, a year of prayer in dots, and Tahajjud with people worldwide.

## Full description (4000 characters max)

Layla Pro keeps your five prayers with you through the day.

The day, drawn as the sun moves
Home opens on one arc from Fajr to Isha. The sun sits where it is right now,
the next prayer is lit, and a countdown ticks underneath. Times are computed
on your phone from your location and the calculation method you choose, so
they work with no signal.

A year of prayer, in one look
Every day is a dot. Green for five confirmed, amber for a day still open, rose
for a prayer missed. Tap any dot to see which prayers it holds. Only a prayer
you confirm counts — nothing is inferred from movement or screen time.

You are not the only one awake
Layla Pro divides the night from Maghrib to Fajr into thirds and lights the
last one, because that is when Tahajjud is best. Tap "I am praying Tahajjud"
and a small light appears on a globe of the Earth at night, where other lights
are glowing too. Each glow is a five-kilometre area, never a person, and it
fades by itself after four hours.

Friends, without a leaderboard
Your code is six letters and numbers. Share it, or send the link, and a friend
appears on your screen with five dots, one for each prayer, filled as their day
is prayed. Nothing is ranked. "Quiet for now" hides your numbers from every
friend until you switch it off. Milestones are celebrated, not compared, and
forty-day circles let a few people keep one prayer together.

For the moments between the prayers
Tasbih with eight counter styles. Mood: tell Layla Pro what you are feeling and
it finds the verse or hadith for it, recited aloud. The ninety-nine names, one
a day, with what each one means. Duas for morning, evening, travel and sleep,
in Arabic with transliteration and meaning.

A quiet note for sisters
If you chose "sister" when you set up the app, Layla Pro offers a prayer pause
for the days of menstruation. Those days are simply not counted: nothing is
recorded as missed, nothing is owed, and the streak carries on where it left
off. The pause is never visible to friends or circles.

Prayer focus
Layla Pro can hold the apps that pull at you during a prayer window and return
you to the prayer screen. On Android this is a gentle, honest nudge that you
can always step past — it is not a lock, and the app says so plainly.

What leaves your phone, and what never does
Prayer times are computed on the device. Your location is used there and
nowhere else. On the globe your position is a rough five-kilometre area that
expires by itself. Friends see only five dots, this year's counts and a
milestone. The prayer pause is never shared. Nothing is inferred; a prayer
counts when you say it does.

Seven percent of every subscription is set aside for those in need, shown in
the app with a live bar and, when there is enough, receipts.

Free for everyone: prayer times, the streak, the year of dots, Tahajjud and the
globe, Friends, Mood, Duas and the names.

## Category and tags

    Category: Lifestyle
    Tags: prayer times, qibla, islamic, adhan, tasbih, dhikr, tahajjud

## Contact and policy

    Website:        https://adenzia04-ui.github.io/layla-pro/
    Privacy policy: https://adenzia04-ui.github.io/layla-pro/#privacy
    Email:          (a real address is required by Play — add yours)

## Graphics Play asks for

    App icon          512 x 512 PNG      → marketing/play-icon-512.png
    Feature graphic   1024 x 500 PNG     → still to make
    Phone screenshots 2 to 8, 16:9 or 9:16, at least 1080 px on the short side
                      → the five panels already made for the App Store fit,
                        once exported at 1080 x 1920 or larger

## Data safety form — the truthful answers

    Collected: email address and name (account), app activity (prayers
      confirmed, streak), approximate location (prayer times and the globe).
    Shared with third parties: none.
    Encrypted in transit: yes.
    Deletion: an account can be deleted in the app, which removes its data.
    Location: approximate only, used for prayer times, the Qibla and the
      Tahajjud globe, never sold or shared.
    Photos: the prayer-mat photo is judged on the device and is never uploaded.

## In-app products to create in Play Console

The app asks the store for these three ids. They are the same strings the App
Store uses, so both platforms stay in step. Create them before the first
release or the paywall will show its fallback prices and every purchase will
fail.

    Subscriptions
      layla_pro_monthly    Monthly   USD 3.99   base plan, monthly, auto-renew
      layla_pro_yearly     Yearly    USD 24.99  base plan, yearly, auto-renew

    One-time product
      layla_pro_lifetime   Lifetime  USD 59.99  non-consumable

Google Play also requires a licence-testing account before purchases can be
tried without being charged: Play Console → Setup → License testing.

## Before the first upload

    1. Play Console account, USD 25 once, and identity verification.
    2. Create the app: Layla Pro, Lifestyle, free with in-app purchases.
    3. Upload build/app/outputs/bundle/release/app-release.aab to internal
       testing first.
    4. Keep Play App Signing ON. The upload key is
       ~/Documents/layla-keys/layla-upload.jks and its password is in
       android/key.properties. Back both up somewhere that is not this Mac.
    5. Fill in the data safety form with the answers above.
    6. Content rating questionnaire: the app has no ads and no user-generated
       content beyond the Tahajjud stories, which are short text lines a user
       writes about their own night.

## One review question to expect

The manifest declares `USE_EXACT_ALARM`. Play restricts that permission to
apps whose core purpose is alarms, timers or calendar events, and asks for a
declaration in the console under App content → Sensitive permissions. Prayer
reminders qualify: the whole app exists to notify at times fixed by the sun,
and a reminder that drifts by fifteen minutes is useless. The answer to give:

> Layla Pro notifies the user at the five daily Islamic prayer times, which
> are computed from the sun's position for their location and cannot be
> shifted. A reminder delivered late has missed the window it exists for, so
> the app schedules each one as an exact alarm. It sets no other alarms and
> shows no ads.

If the declaration is refused, the app still works: reminders fall back to
inexact scheduling and can arrive a few minutes late.
