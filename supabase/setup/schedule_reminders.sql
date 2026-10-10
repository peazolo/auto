-- Run once in the Supabase SQL editor AFTER deploying the `reminders` function.
-- Replace <PROJECT_REF> with your project ref (Settings → General), e.g. abcdefghijklmnop.
-- The secret is read from Vault (created by the 20261010000100_reminders_secret migration).

select cron.unschedule('autox-daily-reminders')
where exists (select 1 from cron.job where jobname = 'autox-daily-reminders');

select cron.schedule(
  'autox-daily-reminders',
  '0 7 * * *',  -- every day at 07:00 UTC
  $$
  select net.http_post(
    url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'autox_cron_secret')),
    body    := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
  $$
);
