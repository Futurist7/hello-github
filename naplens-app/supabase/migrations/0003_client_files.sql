-- Files and receipts attached to clients, stored in a private Storage bucket.

create table client_files (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  name text not null,
  path text not null unique, -- object path inside the client-files bucket
  size_bytes bigint,
  created_at timestamptz not null default now()
);

alter table client_files enable row level security;
create policy "authenticated full access" on client_files
  for all to authenticated using (true) with check (true);

insert into storage.buckets (id, name, public)
values ('client-files', 'client-files', false)
on conflict (id) do nothing;

create policy "authenticated read client files" on storage.objects
  for select to authenticated using (bucket_id = 'client-files');
create policy "authenticated upload client files" on storage.objects
  for insert to authenticated with check (bucket_id = 'client-files');
create policy "authenticated delete client files" on storage.objects
  for delete to authenticated using (bucket_id = 'client-files');
