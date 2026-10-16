-- Naplens Business Hub: initial schema (single-tenant, authenticated users only)

create type currency_code as enum ('GHS', 'USD');
create type doc_status as enum ('draft', 'sent', 'accepted', 'declined');
create type invoice_status as enum ('draft', 'sent', 'partial', 'paid', 'overdue', 'void');
create type payment_method as enum ('momo', 'bank_transfer', 'card', 'cash');

create table clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text,
  phone text,
  address text,
  notes text,
  created_at timestamptz not null default now()
);

create table proposals (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete restrict,
  number text not null unique,
  title text not null,
  currency currency_code not null default 'GHS',
  status doc_status not null default 'draft',
  content jsonb not null default '{}'::jsonb, -- offer sections (outcome, stack, bonuses, guarantee, CTA)
  total_minor bigint not null default 0,      -- amounts stored in minor units (pesewas/cents)
  created_at timestamptz not null default now()
);

create table invoices (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete restrict,
  proposal_id uuid references proposals(id) on delete set null,
  number text not null unique,
  currency currency_code not null default 'GHS',
  status invoice_status not null default 'draft',
  issue_date date not null default current_date,
  due_date date not null,
  tax_minor bigint not null default 0,
  total_minor bigint not null default 0,
  created_at timestamptz not null default now()
);

create table invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references invoices(id) on delete cascade,
  description text not null,
  quantity numeric(12,2) not null default 1,
  unit_price_minor bigint not null
);

create table payments (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references invoices(id) on delete restrict,
  amount_minor bigint not null check (amount_minor > 0),
  method payment_method not null,
  reference text,
  paid_at timestamptz not null default now()
);

create table expenses (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  description text,
  currency currency_code not null default 'GHS',
  amount_minor bigint not null check (amount_minor > 0),
  incurred_on date not null default current_date,
  receipt_path text -- Supabase Storage object path
);

create table retainers (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  description text not null,
  currency currency_code not null default 'GHS',
  amount_minor bigint not null,
  interval_months int not null default 1,
  next_run date not null,
  active boolean not null default true
);

-- Row level security: only signed-in users (the 1-3 Naplens admins) can access data.
do $$
declare t text;
begin
  foreach t in array array['clients','proposals','invoices','invoice_items','payments','expenses','retainers']
  loop
    execute format('alter table %I enable row level security', t);
    execute format(
      'create policy "authenticated full access" on %I for all to authenticated using (true) with check (true)', t);
  end loop;
end $$;
