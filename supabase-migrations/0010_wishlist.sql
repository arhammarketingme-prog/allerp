-- ============================================================================
-- 0010: Wishlist table. (Reviews already existed since 0001/0002 — just
-- needed frontend UI, which comes in this same batch.)
-- ============================================================================

create table public.wishlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  business_product_id uuid not null references public.business_products(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, business_product_id)
);

create index wishlists_user_idx on public.wishlists(user_id);

alter table public.wishlists enable row level security;

create policy wishlists_self_only on public.wishlists
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant all on public.wishlists to authenticated;
grant usage on all sequences in schema public to authenticated;
