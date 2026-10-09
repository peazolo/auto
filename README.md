<p align="center"><img src="docs/icon.png" width="96" alt="AUTOX"></p>

# AUTOX

Car maintenance for Android, iOS and the web, from one Flutter codebase.

- **Accounts:** email sign-up with confirmation, login, password reset, profile, units and currency.
- **Garage:** your vehicles with photo, plate, VIN and odometer.
- **Maintenance reminders:** by time, by distance, or whichever comes first, with 15 ready-made presets. "Mark done" logs the service and reschedules it automatically.
- **Service history:** every job with cost, shop and mileage.
- **Documents:** upload a photo or PDF of your licence, insurance, registration and more. Set the expiry and how early to be reminded (3 days to 3 months).
- **Alerts:** a daily check creates in-app alerts and sends one email digest per user.
- **AI Mechanic:** describe the problem, add photos, or record a short video. Claude replies with likely causes, urgency, whether it's safe to drive, and what to do next, using your car's mileage and service history.

The backend is [Supabase](https://supabase.com): auth, Postgres with row-level security, private file storage, and edge functions for the AI and the reminders.

---

## 1. Set up the backend (Supabase), about 10 minutes

1. Create a free project at [supabase.com](https://supabase.com/dashboard).
2. **Database:** open *SQL Editor*, paste the whole of [`supabase/migrations/20261009000000_init.sql`](supabase/migrations/20261009000000_init.sql) and run it. This creates the tables, security rules and the private `files` storage bucket.
3. **Edge functions:** install the [Supabase CLI](https://supabase.com/docs/guides/cli), then from this folder:
   ```bash
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   supabase functions deploy diagnose
   supabase functions deploy delete-account
   supabase functions deploy reminders --no-verify-jwt
   ```
4. **Secrets** for the functions:
   ```bash
   supabase secrets set \
     ANTHROPIC_API_KEY=sk-ant-...            \
     RESEND_API_KEY=re_...                   \
     EMAIL_FROM="AUTOX <alerts@yourdomain.com>" \
     APP_URL=https://your-site.example.com   \
     CRON_SECRET=$(openssl rand -hex 24)
   ```
   | Secret | What it's for |
   |---|---|
   | `ANTHROPIC_API_KEY` | The AI mechanic. Get one at [console.anthropic.com](https://console.anthropic.com). |
   | `RESEND_API_KEY`, `EMAIL_FROM` | Reminder emails via [resend.com](https://resend.com) (free tier is fine). `EMAIL_FROM` must use a domain you verified there. Without these, in-app alerts still work. |
   | `APP_URL` | Your web app's address, used for links in emails. |
   | `CRON_SECRET` | Protects the reminders endpoint. Any long random string. |
   | `AI_MODEL` *(optional)* | Defaults to `claude-opus-5-5`. |
   | `AI_DAILY_LIMIT` *(optional)* | AI questions per user per day. Defaults to 40. |
5. **Daily reminders:** open [`supabase/setup/schedule_reminders.sql`](supabase/setup/schedule_reminders.sql), replace `<PROJECT_REF>` and `<CRON_SECRET>`, and run it in the SQL editor. It runs every day at 07:00 UTC.
6. **Auth settings** (*Authentication → URL Configuration*):
   - *Site URL*: your web app's address.
   - *Redirect URLs*: add your web address and `io.autox.app://login-callback` (for the phone apps).
   - For real users, set up custom SMTP under *Authentication → Emails*. Supabase's built-in sender is rate-limited to a few emails an hour.

## 2. Configure the app

Copy `env.example.json` to `env.json` and fill it in (*Project Settings → API*):

```json
{
  "SUPABASE_URL": "https://YOUR-PROJECT-REF.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-or-publishable-key",
  "WEB_REDIRECT_URL": "https://your-site.example.com"
}
```

`env.json` is git-ignored. The anon/publishable key is safe in a client app; row-level security protects the data.

## 3. Run and build

Requires Flutter 3.47 or newer.

```bash
flutter pub get
flutter run --dart-define-from-file=env.json                 # phone or emulator
flutter run -d chrome --dart-define-from-file=env.json       # web

flutter build apk --release --dart-define-from-file=env.json          # Android APK
flutter build appbundle --release --dart-define-from-file=env.json    # Play Store
flutter build ipa --release --dart-define-from-file=env.json          # App Store (on a Mac)
flutter build web --release --no-web-resources-cdn --dart-define-from-file=env.json
```

Before publishing to the stores, change the app id (`io.autox.app` in `android/app/build.gradle.kts`, and the bundle id in Xcode), and set up release signing for Android.

## 4. Host the web app

**Automatic (GitHub Pages):** this repo includes [`.github/workflows/build.yml`](.github/workflows/build.yml). In your GitHub repo:
1. *Settings → Secrets and variables → Actions*: add `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
2. *Settings → Pages*: set *Source* to **GitHub Actions**.
3. Push to `main`. The site goes live at `https://<you>.github.io/<repo>/`, and an Android APK is attached to each workflow run under *Artifacts*.
4. Add that address to Supabase's Site URL / Redirect URLs, and set `APP_URL` to it.

**Anywhere else:** run the web build and upload `build/web` to Netlify, Firebase Hosting, Cloudflare Pages or any static host. Configure it to serve `index.html` for unknown paths (a Netlify `_redirects` file is already included).

---

## Project layout

```
lib/
  main.dart, router.dart, config.dart
  data/        models, Supabase queries, formatting
  ui/          theme (brown & butter), shared widgets, logo
  screens/     auth, dashboard, vehicles, maintenance, documents, diagnose, alerts, settings
supabase/
  migrations/  database schema, security rules, storage bucket
  functions/   diagnose (AI, streaming), reminders (daily job), delete-account
  setup/       cron schedule for reminders
```

### How the AI handles video
Videos never leave the device. The app samples up to six still frames (in the browser with a canvas, on phones with a thumbnail plugin) and sends those, so it works on any plan and stays fast. Ask users to describe sounds, since the AI sees frames, not audio.

### Security
Every table has row-level security so users only ever see their own rows. Files live in a private bucket under each user's own folder and are served with short-lived signed URLs. The AI and account-deletion functions verify the user's token; the reminders function requires `CRON_SECRET`.

Fonts: Fraunces and Plus Jakarta Sans, both under the SIL Open Font License (see `assets/fonts`).
