-- Zaki Supermarché - قاعدة بيانات أولية لـ Supabase
-- لا تشغّل هذا المخطط على بيانات إنتاج قبل مراجعته واختباره.
create extension if not exists pgcrypto;

create type public.staff_role as enum ('admin','cashier','stock','debts');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role public.staff_role not null default 'cashier',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  barcode text unique,
  category_id uuid references public.categories(id),
  purchase_price numeric(14,2) not null default 0 check (purchase_price >= 0),
  sale_price numeric(14,2) not null default 0 check (sale_price >= 0),
  quantity numeric(14,3) not null default 0 check (quantity >= 0),
  unit text not null default 'حبة',
  expiry_date date,
  min_quantity numeric(14,3) not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text,
  notes text,
  loyalty_points integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  invoice_number bigint generated always as identity unique,
  cashier_id uuid references public.profiles(id),
  customer_id uuid references public.customers(id),
  payment_method text not null check(payment_method in ('cash','credit','mixed')),
  subtotal numeric(14,2) not null default 0,
  discount numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  paid numeric(14,2) not null default 0,
  credit_balance numeric(14,2) not null default 0,
  status text not null default 'completed' check(status in ('completed','cancelled','returned')),
  created_at timestamptz not null default now()
);

create table public.invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  product_id uuid references public.products(id),
  product_name_snapshot text not null,
  quantity numeric(14,3) not null check(quantity > 0),
  unit_price numeric(14,2) not null check(unit_price >= 0),
  unit_cost_snapshot numeric(14,2) not null default 0,
  line_total numeric(14,2) not null
);

create table public.customer_payments (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id),
  invoice_id uuid references public.invoices(id),
  amount numeric(14,2) not null check(amount > 0),
  received_by uuid references public.profiles(id),
  note text,
  created_at timestamptz not null default now()
);

create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  supplier_name text,
  reference text,
  created_by uuid references public.profiles(id),
  total numeric(14,2) not null default 0,
  created_at timestamptz not null default now()
);

create table public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  product_id uuid references public.products(id),
  quantity numeric(14,3) not null check(quantity > 0),
  unit_cost numeric(14,2) not null check(unit_cost >= 0)
);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  amount numeric(14,2) not null check(amount >= 0),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  entity text,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.current_role()
returns public.staff_role
language sql stable security definer
set search_path = public
as $$
  select role from public.profiles
  where id = auth.uid() and active = true
$$;

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;
alter table public.customer_payments enable row level security;
alter table public.purchases enable row level security;
alter table public.purchase_items enable row level security;
alter table public.expenses enable row level security;
alter table public.audit_log enable row level security;

-- ملف المستخدم: المستخدم يرى ملفه، والمدير يرى الجميع.
create policy "profile self or admin read" on public.profiles for select
using (id = auth.uid() or public.current_role() = 'admin');
create policy "admin manages profiles" on public.profiles for all
using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

-- قراءة المنتجات متاحة للعاملين المسجلين. التعديل للمدير ومسؤول المخزون.
create policy "staff read products" on public.products for select
using (auth.uid() is not null and exists(select 1 from public.profiles p where p.id=auth.uid() and p.active));
create policy "stock roles write products" on public.products for all
using (public.current_role() in ('admin','stock'))
with check (public.current_role() in ('admin','stock'));

create policy "staff read categories" on public.categories for select
using (auth.uid() is not null);
create policy "admin stock manage categories" on public.categories for all
using (public.current_role() in ('admin','stock'))
with check (public.current_role() in ('admin','stock'));

create policy "staff read customers" on public.customers for select
using (auth.uid() is not null);
create policy "authorized manage customers" on public.customers for all
using (public.current_role() in ('admin','cashier','debts'))
with check (public.current_role() in ('admin','cashier','debts'));

create policy "authorized read invoices" on public.invoices for select
using (public.current_role() in ('admin','cashier','debts'));
create policy "cashier creates invoices" on public.invoices for insert
with check (public.current_role() in ('admin','cashier'));
create policy "admin cancels invoices" on public.invoices for update
using (public.current_role()='admin') with check (public.current_role()='admin');

create policy "authorized invoice items read" on public.invoice_items for select
using (public.current_role() in ('admin','cashier','debts'));
create policy "cashier inserts invoice items" on public.invoice_items for insert
with check (public.current_role() in ('admin','cashier'));

create policy "authorized payment read" on public.customer_payments for select
using (public.current_role() in ('admin','debts','cashier'));
create policy "authorized payment insert" on public.customer_payments for insert
with check (public.current_role() in ('admin','debts','cashier'));

create policy "stock roles read purchases" on public.purchases for select
using (public.current_role() in ('admin','stock'));
create policy "stock roles create purchases" on public.purchases for insert
with check (public.current_role() in ('admin','stock'));
create policy "stock roles read purchase items" on public.purchase_items for select
using (public.current_role() in ('admin','stock'));
create policy "stock roles create purchase items" on public.purchase_items for insert
with check (public.current_role() in ('admin','stock'));

create policy "admin manages expenses" on public.expenses for all
using (public.current_role()='admin') with check (public.current_role()='admin');
create policy "admin reads audit" on public.audit_log for select
using (public.current_role()='admin');
create policy "staff append audit" on public.audit_log for insert
with check (actor_id=auth.uid());

-- ملاحظة: يفضّل تنفيذ البيع وتحديث المخزون داخل دالة PostgreSQL transaction
-- أو Edge Function موثوقة، حتى لا يحدث اختلاف بين الفاتورة والكمية.
