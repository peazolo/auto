-- Shared secret between the daily cron job and the `reminders` function, kept in Vault.
create extension if not exists pg_cron;
create extension if not exists pg_net;

select vault.create_secret(encode(extensions.gen_random_bytes(24), 'hex'), 'autox_cron_secret', 'Authenticates the daily reminders job')
where not exists (select 1 from vault.secrets where name = 'autox_cron_secret');

-- Lets the reminders function (service role only) check the header it received.
create or replace function public.verify_cron_secret(p_secret text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from vault.decrypted_secrets where name = 'autox_cron_secret' and decrypted_secret = p_secret);
$$;
revoke execute on function public.verify_cron_secret(text) from public, anon, authenticated;
grant execute on function public.verify_cron_secret(text) to service_role;
