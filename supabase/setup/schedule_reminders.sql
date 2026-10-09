-- Run once in the Supabase SQL editor AFTER deploying the `reminders` function.
-- Replace the two placeholders:
--   <PROJECT_REF>  your project ref (Settings → General), e.g. abcdefghijklmnop
--   <CRON_SECRET>  the same value you set with `supabase secrets set CRON_SECRET=...`

create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.unschedule('autox-daily-reminders')
where exists (select 1 from cron.job where jobname = 'autox-daily-reminders');

select cron.schedule(
  'autox-daily-reminders',
  '0 7 * * *',  -- every day at 07:00 UTC
  $$
  select net.http_post(
    url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/reminders',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', '<CRON_SECRET>'),
    body    := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
  $$
);
