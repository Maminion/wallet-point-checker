-- Wallet Point Checker: shared snapshots (kept 7 days)
create table if not exists public.wallet_snapshots (
  id          bigint generated always as identity primary key,
  server      text not null check (server in ('CBPC-SEA','CBPC-TH','CBM-SEA','CBM-TH')),
  file_name   text not null check (char_length(file_name) <= 200),
  row_count   integer not null default 0,
  data        jsonb not null default '{}'::jsonb check (pg_column_size(data) < 20000),
  uploaded_at timestamptz not null default now()
);
create index if not exists wallet_snapshots_server_time on public.wallet_snapshots (server, uploaded_at desc);

alter table public.wallet_snapshots enable row level security;

drop policy if exists "read last 7 days" on public.wallet_snapshots;
create policy "read last 7 days" on public.wallet_snapshots
  for select to anon, authenticated
  using (uploaded_at > now() - interval '7 days');

drop policy if exists "anyone can upload" on public.wallet_snapshots;
create policy "anyone can upload" on public.wallet_snapshots
  for insert to anon, authenticated
  with check (uploaded_at > now() - interval '1 minute');

grant select, insert on public.wallet_snapshots to anon, authenticated;

-- Remove snapshots older than 7 days whenever a new file is uploaded
create or replace function public.wallet_snapshots_cleanup() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  delete from public.wallet_snapshots where uploaded_at < now() - interval '7 days';
  return null;
end $$;

drop trigger if exists wallet_snapshots_cleanup on public.wallet_snapshots;
create trigger wallet_snapshots_cleanup after insert on public.wallet_snapshots
  for each statement execute function public.wallet_snapshots_cleanup();
