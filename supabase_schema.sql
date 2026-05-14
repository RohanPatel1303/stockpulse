-- =============================================
-- STOCKPULSE - Supabase Schema
-- Run this in your Supabase SQL Editor
-- =============================================

-- 1. PROFILES TABLE (extends Supabase auth.users)
create table public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  full_name text not null,
  email text not null,
  is_admin boolean default false,
  created_at timestamp with time zone default now()
);

-- 2. ITEMS TABLE (inventory items)
create table public.items (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  quantity integer not null default 0,
  low_stock_threshold integer not null default 5,
  location text,
  image_url text,
  qr_code text unique, -- stores the item id as QR value
  created_by uuid references public.profiles(id),
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- 3. ACTIVITY LOG TABLE
create table public.activity_log (
  id uuid default gen_random_uuid() primary key,
  item_id uuid references public.items(id) on delete cascade,
  item_name text not null, -- store name in case item is deleted
  action text not null,    -- 'created', 'updated', 'deleted', 'stock_changed'
  old_quantity integer,
  new_quantity integer,
  changed_by uuid references public.profiles(id),
  changed_by_name text not null,
  created_at timestamp with time zone default now()
);

-- =============================================
-- AUTO-UPDATE updated_at ON ITEMS
-- =============================================
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger items_updated_at
before update on public.items
for each row execute function update_updated_at();

-- =============================================
-- AUTO-CREATE PROFILE ON SIGNUP
-- =============================================
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, email, is_admin)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'User'),
    new.email,
    coalesce((new.raw_user_meta_data->>'is_admin')::boolean, false)
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================

-- Enable RLS
alter table public.profiles enable row level security;
alter table public.items enable row level security;
alter table public.activity_log enable row level security;

-- PROFILES policies
create policy "Users can view all profiles"
  on public.profiles for select
  using (auth.role() = 'authenticated');

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- ITEMS policies
create policy "Authenticated users can view items"
  on public.items for select
  using (auth.role() = 'authenticated');

create policy "Admins can insert items"
  on public.items for insert
  with check (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and is_admin = true
    )
  );

create policy "Admins can update items"
  on public.items for update
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and is_admin = true
    )
  );

create policy "Admins can delete items"
  on public.items for delete
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and is_admin = true
    )
  );

-- ACTIVITY LOG policies
create policy "Authenticated users can view activity log"
  on public.activity_log for select
  using (auth.role() = 'authenticated');

create policy "Authenticated users can insert activity log"
  on public.activity_log for insert
  with check (auth.role() = 'authenticated');

-- =============================================
-- ENABLE REALTIME
-- =============================================
alter publication supabase_realtime add table public.items;
alter publication supabase_realtime add table public.activity_log;

-- =============================================
-- SAMPLE DATA (optional - for testing)
-- =============================================
-- Run AFTER creating your first admin user through the app

-- insert into public.items (name, description, quantity, low_stock_threshold, location, qr_code)
-- values
--   ('Laptop Dell XPS 15', '15 inch development laptop', 10, 3, 'Warehouse A - Shelf 1', gen_random_uuid()::text),
--   ('USB-C Hub', '7-in-1 USB-C Hub', 25, 5, 'Warehouse A - Shelf 2', gen_random_uuid()::text),
--   ('Monitor 27inch', '4K IPS Display', 8, 2, 'Warehouse B - Shelf 1', gen_random_uuid()::text);