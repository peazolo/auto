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

## 1. Backend (Supabase)

The live backend is the Supabase project **auto** (`avfvbzfwvfdfvveebbgc`). It is already set up: tables, security rules, private file storage, the three edge functions, and the daily reminders job at 07:00 UTC. What is left to do in the [Supabase dashboard](https://supabase.com/dashboard/project/avfvbzfwvfdfvveebbgc):

1. **AI key:** *Edge Functions → Secrets*, add `ANTHROPIC_API_KEY` (from [console.anthropic.com](https://console.anthropic.com)). Until then the AI Mechanic replies "not configured yet".
2. **Login links:** *Authentication → URL Configuration*. Set *Site URL* to `https://peazolo.github.io/auto/` and add these *Redirect URLs*: `https://peazolo.github.io/auto/`, `io.autox.app://login-callback`, `http://localhost:8080`.
3. **Emails for real users:** Supabase's built-in sender only sends a few sign-up emails an hour. Set up custom SMTP under *Authentication → Emails* (Resend works well).
4. *(Optional)* **Reminder emails:** add `RESEND_API_KEY`, `EMAIL_FROM` (e.g. `AUTOX <alerts@yourdomain.com>`, on a domain verified in Resend) and `APP_URL` (`https://peazolo.github.io/auto/`) as function secrets. In-app alerts work without them.

Optional function secrets: `AI_MODEL` (default `claude-opus-5-5`) and `AI_DAILY_LIMIT` (AI questions per user per day, default 40).

### Setting up a fresh Supabase project instead
1. Run every file in [`supabase/migrations`](supabase/migrations) in order in the SQL editor (or `supabase db push`).
2. Deploy the functions with the [Supabase CLI](https://supabase.com/docs/guides/cli):
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   supabase functions deploy diagnose
   supabase functions deploy delete-account
   supabase functions deploy reminders --no-verify-jwt
   ```
3. Run [`supabase/setup/schedule_reminders.sql`](supabase/setup/schedule_reminders.sql) with your project ref filled in.
4. Do steps 1 to 4 above, and put your project's URL and publishable key in `env.json` and the workflow.

## 2. Configure the app

`env.example.json` already points at the live project. Copy it to `env.json` for local runs:

```json
{
  "SUPABASE_URL": "https://avfvbzfwvfdfvveebbgc.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_...",
  "WEB_REDIRECT_URL": "https://peazolo.github.io/auto/"
}
```

The publishable key is safe in a client app; row-level security protects the data.

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

**Automatic (GitHub Pages):** this repo includes [`.github/workflows/build.yml`](.github/workflows/build.yml). It builds against the live Supabase project, so the only setup is: *Settings → Pages*, set *Source* to **GitHub Actions**. Every push to `main` then publishes the site at `https://peazolo.github.io/auto/` and attaches an Android APK to the workflow run under *Artifacts*.

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
Every table has row-level security so users only ever see their own rows. Files live in a private bucket under each user's own folder and are served with short-lived signed URLs. The AI and account-deletion functions verify the user's token; the reminders function only runs with the secret the cron job reads from Vault.

Fonts: Fraunces and Plus Jakarta Sans, both under the SIL Open Font License (see `assets/fonts`).
