-- ============================================================================
-- 0020: ALL ERP — Comprehensive Business Operating System Schema
-- Extends the Business Super Platform with complete modular ERP tables
-- ============================================================================

-- 1. COMPANIES & BRANCHES (Multi-Company & Multi-Branch Architecture)
create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  legal_name text not null,
  trade_name text,
  gstin text,
  pan text,
  state text default 'Maharashtra',
  country text default 'India',
  currency text default 'INR',
  financial_year_start date default '2026-04-01',
  logo_url text,
  is_active boolean default true,
  created_at timestamptz default now()
);

create table if not exists public.branches (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  company_id uuid references public.companies(id) on delete cascade,
  name text not null,
  code text,
  city text,
  state text default 'Maharashtra',
  address text,
  phone text,
  is_main boolean default false,
  created_at timestamptz default now()
);

-- 2. CRM (Leads, Opportunities, Pipeline)
create table if not exists public.crm_leads (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  company_name text,
  email text,
  phone text not null,
  source text default 'direct', -- website, referral, call, ads, walk-in
  stage text default 'new' check (stage in ('new', 'contacted', 'qualified', 'proposal', 'negotiation', 'won', 'lost')),
  expected_value numeric(12,2) default 0,
  assigned_to uuid references public.users(id),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. SALES & INVOICING (GST, Quotes, Orders, Invoices)
create table if not exists public.sales_quotations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  quotation_number text not null,
  customer_id uuid references public.customers(id),
  customer_name text not null,
  customer_phone text,
  quotation_date date default current_date,
  valid_until date default (current_date + interval '30 days'),
  subtotal numeric(12,2) default 0,
  tax_amount numeric(12,2) default 0,
  discount_amount numeric(12,2) default 0,
  grand_total numeric(12,2) default 0,
  status text default 'draft' check (status in ('draft', 'sent', 'accepted', 'rejected', 'converted')),
  items jsonb default '[]',
  notes text,
  created_at timestamptz default now()
);

create table if not exists public.sales_invoices (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  invoice_number text not null,
  customer_id uuid references public.customers(id),
  customer_name text not null,
  customer_phone text,
  customer_gstin text,
  invoice_date date default current_date,
  due_date date default (current_date + interval '15 days'),
  subtotal numeric(12,2) default 0,
  cgst numeric(12,2) default 0,
  sgst numeric(12,2) default 0,
  igst numeric(12,2) default 0,
  discount numeric(12,2) default 0,
  grand_total numeric(12,2) default 0,
  paid_amount numeric(12,2) default 0,
  balance_amount numeric(12,2) default 0,
  payment_status text default 'unpaid' check (payment_status in ('unpaid', 'partially_paid', 'paid', 'overdue')),
  items jsonb default '[]',
  notes text,
  created_at timestamptz default now()
);

-- 4. PURCHASE MANAGEMENT (PO, Bills)
create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  po_number text not null,
  supplier_id uuid references public.suppliers(id),
  supplier_name text not null,
  order_date date default current_date,
  expected_delivery date,
  total_amount numeric(12,2) default 0,
  paid_amount numeric(12,2) default 0,
  status text default 'draft' check (status in ('draft', 'ordered', 'received', 'billed', 'cancelled')),
  items jsonb default '[]',
  created_at timestamptz default now()
);

-- 5. ACCOUNTING & EXPENSES
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  category text not null, -- rent, electricity, salary, transport, maintenance, marketing, other
  title text not null,
  amount numeric(12,2) not null,
  payment_mode text default 'cash' check (payment_mode in ('cash', 'upi', 'bank_transfer', 'cheque', 'card')),
  expense_date date default current_date,
  vendor_name text,
  receipt_url text,
  notes text,
  created_by uuid references public.users(id),
  created_at timestamptz default now()
);

create table if not exists public.accounts_ledger (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  account_name text not null,
  account_type text not null, -- asset, liability, equity, revenue, expense
  debit numeric(12,2) default 0,
  credit numeric(12,2) default 0,
  balance numeric(12,2) default 0,
  reference_type text, -- invoice, payment, expense, po
  reference_id uuid,
  narration text,
  entry_date date default current_date,
  created_at timestamptz default now()
);

-- 6. HR & PAYROLL
create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  phone text not null,
  email text,
  department text default 'General',
  designation text default 'Staff',
  salary_amount numeric(12,2) default 0,
  salary_type text default 'monthly' check (salary_type in ('monthly', 'daily', 'hourly')),
  joining_date date default current_date,
  status text default 'active' check (status in ('active', 'on_leave', 'resigned', 'terminated')),
  created_at timestamptz default now()
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  date date default current_date,
  status text default 'present' check (status in ('present', 'absent', 'half_day', 'holiday', 'leave')),
  check_in time,
  check_out time,
  unique(employee_id, date)
);

create table if not exists public.payroll_records (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  month text not null, -- e.g. 2026-08
  basic_salary numeric(12,2) not null,
  allowances numeric(12,2) default 0,
  deductions numeric(12,2) default 0,
  net_salary numeric(12,2) not null,
  payment_status text default 'pending' check (payment_status in ('pending', 'paid')),
  paid_date date,
  created_at timestamptz default now()
);

-- 7. PROJECTS & CONTRACTOR ERP
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  client_name text,
  site_location text,
  budget numeric(12,2) default 0,
  estimated_cost numeric(12,2) default 0,
  actual_cost numeric(12,2) default 0,
  billed_amount numeric(12,2) default 0,
  received_amount numeric(12,2) default 0,
  start_date date,
  deadline date,
  status text default 'planning' check (status in ('planning', 'in_progress', 'review', 'completed', 'on_hold')),
  created_at timestamptz default now()
);

create table if not exists public.project_tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  title text not null,
  assigned_to text,
  status text default 'todo' check (status in ('todo', 'in_progress', 'review', 'done')),
  priority text default 'medium' check (priority in ('low', 'medium', 'high', 'urgent')),
  due_date date,
  created_at timestamptz default now()
);

-- 8. MANUFACTURING & RECIPES (BOM, Production)
create table if not exists public.bill_of_materials (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  finished_product_name text not null,
  output_quantity numeric(12,2) default 1,
  unit text default 'pcs',
  raw_materials jsonb not null default '[]', -- [{name, qty, unit, cost}]
  estimated_cost numeric(12,2) default 0,
  notes text,
  created_at timestamptz default now()
);

create table if not exists public.production_orders (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  bom_id uuid references public.bill_of_materials(id),
  product_name text not null,
  target_qty numeric(12,2) not null,
  produced_qty numeric(12,2) default 0,
  status text default 'planned' check (status in ('planned', 'in_production', 'completed', 'cancelled')),
  start_date date default current_date,
  end_date date,
  created_at timestamptz default now()
);

-- 9. SERVICE HELPDESK & APPOINTMENTS
create table if not exists public.service_tickets (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  ticket_number text not null,
  customer_name text not null,
  customer_phone text not null,
  service_type text not null, -- repair, amc, installation, consultation, complaint
  issue_description text,
  assigned_technician text,
  charge_amount numeric(12,2) default 0,
  status text default 'new' check (status in ('new', 'assigned', 'in_progress', 'resolved', 'closed')),
  created_at timestamptz default now()
);

create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_name text not null,
  customer_phone text not null,
  service_name text not null,
  staff_name text,
  appointment_date date not null,
  appointment_time time not null,
  status text default 'scheduled' check (status in ('scheduled', 'confirmed', 'completed', 'cancelled')),
  notes text,
  created_at timestamptz default now()
);

-- 10. DOCUMENT REPOSITORY
create table if not exists public.business_documents (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  category text not null default 'general', -- gst, license, contract, employee, tax, invoice, site
  title text not null,
  file_url text not null,
  file_type text,
  file_size text,
  tags text[],
  created_at timestamptz default now()
);

-- 11. ENABLE RLS FOR ALL NEW TABLES
alter table public.companies enable row level security;
alter table public.branches enable row level security;
alter table public.crm_leads enable row level security;
alter table public.sales_quotations enable row level security;
alter table public.sales_invoices enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.expenses enable row level security;
alter table public.accounts_ledger enable row level security;
alter table public.employees enable row level security;
alter table public.attendance enable row level security;
alter table public.payroll_records enable row level security;
alter table public.projects enable row level security;
alter table public.project_tasks enable row level security;
alter table public.bill_of_materials enable row level security;
alter table public.production_orders enable row level security;
alter table public.service_tickets enable row level security;
alter table public.appointments enable row level security;
alter table public.business_documents enable row level security;

-- Tenant Isolation RLS Policies
do $$
declare
  tbl text;
begin
  for tbl in select unnest(array[
    'companies','branches','crm_leads','sales_quotations','sales_invoices',
    'purchase_orders','expenses','accounts_ledger','employees','attendance',
    'payroll_records','projects','bill_of_materials','production_orders',
    'service_tickets','appointments','business_documents'
  ]) loop
    execute format('
      drop policy if exists %I_tenant_policy on public.%I;
      create policy %I_tenant_policy on public.%I
      for all using (public.is_business_member(business_id) or public.is_admin())
      with check (public.is_business_member(business_id) or public.is_admin());
    ', tbl, tbl, tbl, tbl);
  end loop;
end $$;

-- Tasks policy (via project_id)
drop policy if exists project_tasks_tenant_policy on public.project_tasks;
create policy project_tasks_tenant_policy on public.project_tasks
for all using (
  exists (select 1 from public.projects p where p.id = project_id and (public.is_business_member(p.business_id) or public.is_admin()))
);
