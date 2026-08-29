-- Grazia Stones / StoneVerse — Supabase Schema
-- Run this in: Supabase Dashboard → SQL Editor

-- ──────────────────────────────────────────────
-- 0. Extensions
-- ──────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ──────────────────────────────────────────────
-- 1. PROFILES (extends Supabase auth.users)
-- ──────────────────────────────────────────────
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null default '',
  phone       text,
  email       text,
  avatar_url  text,
  role        text not null default 'customer',  -- customer | dealer | admin
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Public profiles are viewable by everyone"
  on public.profiles for select using (true);

create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert with check (auth.uid() = id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, email, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.email,
    coalesce(new.raw_user_meta_data ->> 'phone', '')
  );
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ──────────────────────────────────────────────
-- 2. COLLECTIONS
-- ──────────────────────────────────────────────
create table public.collections (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  slug        text unique not null,
  description text,
  image_url   text,
  sort_order  int not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

alter table public.collections enable row level security;

create policy "Collections viewable by everyone"
  on public.collections for select using (active = true);

create policy "Admins can manage collections"
  on public.collections for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- ──────────────────────────────────────────────
-- 3. STONES (Products)
-- ──────────────────────────────────────────────
create table public.stones (
  id                uuid primary key default uuid_generate_v4(),
  name              text not null,
  slug              text unique not null,
  product_code      text unique,
  collection_id     uuid references public.collections(id) on delete set null,
  category          text not null default 'stone',  -- stone | tile | slab | accessory
  description       text,
  short_description text,

  -- Pricing
  price_per_sqft    numeric(10,2) not null default 0,
  price_per_unit    numeric(10,2),
  currency          text not null default 'INR',
  discount_percent  numeric(5,2) default 0,
  moq               int default 1,  -- minimum order quantity

  -- Dimensions
  length_cm         numeric(8,2),
  width_cm          numeric(8,2),
  thickness_mm      numeric(8,2),
  weight_kg         numeric(8,2),
  coverage_sqft     numeric(8,2),  -- sqft per piece

  -- Attributes
  finish            text,          -- polished, honed, flamed, brushed, etc.
  material          text,          -- marble, granite, sandstone, slate, etc.
  colors            text[],        -- array of color names
  patterns          text[],        -- array of pattern names
  origin            text,          -- country/region of origin

  -- Media
  images            text[] not null default '{}',  -- array of image URLs
  thumbnail_url     text,
  model_3d_url      text,         -- GLB/GLTF for AR
  video_url         text,
  catalogue_pdf_url text,

  -- Inventory
  stock_status      text not null default 'in_stock',  -- in_stock | out_of_stock | made_to_order
  stock_quantity    int default 0,
  lead_time_days    int default 0,

  -- SEO & Meta
  tags              text[],
  meta_title        text,
  meta_description  text,

  -- Status
  active            boolean not null default true,
  featured          boolean not null default false,
  sort_order        int not null default 0,

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

alter table public.stones enable row level security;

create policy "Stones viewable by everyone"
  on public.stones for select using (active = true);

create policy "Admins can manage stones"
  on public.stones for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create index idx_stones_collection on public.stones(collection_id);
create index idx_stones_category on public.stones(category);
create index idx_stones_featured on public.stones(featured) where featured = true;
create index idx_stones_price on public.stones(price_per_sqft);

-- ──────────────────────────────────────────────
-- 4. DEALERS
-- ──────────────────────────────────────────────
create table public.dealers (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid references public.profiles(id) on delete set null,
  name        text not null,
  company     text,
  phone       text not null,
  email       text,
  address     text,
  city        text,
  state       text,
  pincode     text,
  latitude    numeric(10,7),
  longitude   numeric(10,7),
  rating      numeric(3,2) default 0,
  verified    boolean not null default false,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

alter table public.dealers enable row level security;

create policy "Dealers viewable by everyone"
  on public.dealers for select using (active = true);

create policy "Admins can manage dealers"
  on public.dealers for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- ──────────────────────────────────────────────
-- 5. CART ITEMS
-- ──────────────────────────────────────────────
create table public.cart_items (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  stone_id    uuid not null references public.stones(id) on delete cascade,
  quantity    int not null default 1,
  unit_price  numeric(10,2) not null,
  notes       text,
  created_at  timestamptz not null default now(),

  unique(user_id, stone_id)
);

alter table public.cart_items enable row level security;

create policy "Users can view own cart"
  on public.cart_items for select using (auth.uid() = user_id);

create policy "Users can manage own cart"
  on public.cart_items for all using (auth.uid() = user_id);

-- ──────────────────────────────────────────────
-- 6. ORDERS
-- ──────────────────────────────────────────────
create table public.orders (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references public.profiles(id),
  order_number    text unique not null,

  -- Status
  status          text not null default 'pending',
  -- pending | confirmed | processing | shipped | delivered | cancelled

  -- Amounts
  subtotal        numeric(12,2) not null default 0,
  shipping_cost   numeric(10,2) default 0,
  tax             numeric(10,2) default 0,
  discount        numeric(10,2) default 0,
  total           numeric(12,2) not null default 0,
  currency        text not null default 'INR',

  -- Shipping address (snapshot)
  shipping_name   text,
  shipping_phone  text,
  shipping_address text,
  shipping_city   text,
  shipping_state  text,
  shipping_pincode text,

  -- Payment
  payment_method  text,          -- razorpay | cod | bank_transfer
  payment_status  text not null default 'pending',
  -- pending | paid | failed | refunded
  payment_id      text,          -- Razorpay payment ID
  razorpay_order_id text,

  -- Notes
  notes           text,
  cancellation_reason text,

  -- Tracking
  tracking_number text,
  carrier         text,
  shipped_at      timestamptz,
  delivered_at    timestamptz,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.orders enable row level security;

create policy "Users can view own orders"
  on public.orders for select using (auth.uid() = user_id);

create policy "Users can create own orders"
  on public.orders for insert with check (auth.uid() = user_id);

create policy "Admins can manage all orders"
  on public.orders for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create index idx_orders_user on public.orders(user_id);
create index idx_orders_status on public.orders(status);

-- ──────────────────────────────────────────────
-- 7. ORDER ITEMS
-- ──────────────────────────────────────────────
create table public.order_items (
  id          uuid primary key default uuid_generate_v4(),
  order_id    uuid not null references public.orders(id) on delete cascade,
  stone_id    uuid references public.stones(id) on delete set null,
  name        text not null,        -- snapshot of stone name
  product_code text,
  image_url   text,
  quantity    int not null default 1,
  unit_price  numeric(10,2) not null,
  total_price numeric(12,2) not null,
  created_at  timestamptz not null default now()
);

alter table public.order_items enable row level security;

create policy "Users can view own order items"
  on public.order_items for select
  using (
    exists (
      select 1 from public.orders
      where orders.id = order_items.order_id
      and orders.user_id = auth.uid()
    )
  );

create policy "Admins can manage all order items"
  on public.order_items for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- ──────────────────────────────────────────────
-- 8. WISHLIST
-- ──────────────────────────────────────────────
create table public.wishlist_items (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  stone_id    uuid not null references public.stones(id) on delete cascade,
  created_at  timestamptz not null default now(),

  unique(user_id, stone_id)
);

alter table public.wishlist_items enable row level security;

create policy "Users can view own wishlist"
  on public.wishlist_items for select using (auth.uid() = user_id);

create policy "Users can manage own wishlist"
  on public.wishlist_items for all using (auth.uid() = user_id);

-- ──────────────────────────────────────────────
-- 9. QUOTE REQUESTS
-- ──────────────────────────────────────────────
create table public.quote_requests (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid references public.profiles(id) on delete set null,
  name            text not null,
  email           text,
  phone           text not null,
  company         text,
  stone_id        uuid references public.stones(id) on delete set null,
  stone_name      text,
  quantity        int,
  area_sqft       numeric(10,2),
  message         text,
  status          text not null default 'pending',
  -- pending | contacted | quoted | closed
  admin_notes     text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.quote_requests enable row level security;

create policy "Users can view own quotes"
  on public.quote_requests for select
  using (auth.uid() = user_id);

create policy "Anyone can create quotes"
  on public.quote_requests for insert with check (true);

create policy "Admins can manage all quotes"
  on public.quote_requests for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- ──────────────────────────────────────────────
-- 10. ADDRESSES
-- ──────────────────────────────────────────────
create table public.addresses (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  label       text not null default 'Home',  -- Home | Office | Site | Other
  name        text not null,
  phone       text not null,
  address_line1 text not null,
  address_line2 text,
  city        text not null,
  state       text not null,
  pincode     text not null,
  landmark    text,
  latitude    numeric(10,7),
  longitude   numeric(10,7),
  is_default  boolean not null default false,
  created_at  timestamptz not null default now()
);

alter table public.addresses enable row level security;

create policy "Users can view own addresses"
  on public.addresses for select using (auth.uid() = user_id);

create policy "Users can manage own addresses"
  on public.addresses for all using (auth.uid() = user_id);

-- ──────────────────────────────────────────────
-- 10B. SAVED DESIGNS (AI Studio Room Visualizations)
-- ──────────────────────────────────────────────
create table public.saved_designs (
  id                  uuid primary key default uuid_generate_v4(),
  user_id             uuid not null references public.profiles(id) on delete cascade,
  stone_id            uuid references public.stones(id) on delete set null,
  stone_name          text not null,
  room_image_url      text,
  generated_image_url text not null,
  color               text,
  finish              text,
  notes               text,
  created_at          timestamptz not null default now()
);

alter table public.saved_designs enable row level security;

create policy "Users can view own saved designs"
  on public.saved_designs for select using (auth.uid() = user_id);

create policy "Users can manage own saved designs"
  on public.saved_designs for all using (auth.uid() = user_id);

-- ──────────────────────────────────────────────
-- 10C. PROJECTS (Wall Measurement & Design Projects)
-- ──────────────────────────────────────────────
create table public.projects (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  name            text not null,
  description     text,
  project_type    text not null default 'wall',  -- wall | floor | custom
  status          text not null default 'active',  -- active | completed | archived
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.projects enable row level security;

create policy "Users can view own projects"
  on public.projects for select using (auth.uid() = user_id);

create policy "Users can manage own projects"
  on public.projects for all using (auth.uid() = user_id);

-- ──────────────────────────────────────────────
-- 10D. PROJECT ITEMS (Stones within a project)
-- ──────────────────────────────────────────────
create table public.project_items (
  id              uuid primary key default uuid_generate_v4(),
  project_id      uuid not null references public.projects(id) on delete cascade,
  stone_id        uuid references public.stones(id) on delete set null,
  stone_name      text not null,
  quantity        int not null default 1,
  wall_width_ft   numeric(10,2),
  wall_height_ft  numeric(10,2),
  area_sqft       numeric(10,2),
  wastage_percent numeric(5,2) default 10,
  notes           text,
  created_at      timestamptz not null default now()
);

alter table public.project_items enable row level security;

create policy "Users can view own project items"
  on public.project_items for select
  using (
    exists (
      select 1 from public.projects
      where projects.id = project_items.project_id
      and projects.user_id = auth.uid()
    )
  );

create policy "Users can manage own project items"
  on public.project_items for all
  using (
    exists (
      select 1 from public.projects
      where projects.id = project_items.project_id
      and projects.user_id = auth.uid()
    )
  );

-- ──────────────────────────────────────────────
-- 10E. SAMPLE REQUESTS
-- ──────────────────────────────────────────────
create table public.sample_requests (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid references public.profiles(id) on delete set null,
  stone_id        uuid references public.stones(id) on delete set null,
  name            text not null,
  email           text,
  phone           text not null,
  company         text,
  address         text,
  city            text,
  state           text,
  pincode         text,
  stone_name      text not null,
  quantity        int not null default 1,
  message         text,
  status          text not null default 'pending',
  -- pending | processing | shipped | delivered | cancelled
  admin_notes     text,
  tracking_number text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.sample_requests enable row level security;

create policy "Users can view own sample requests"
  on public.sample_requests for select
  using (auth.uid() = user_id);

create policy "Anyone can create sample requests"
  on public.sample_requests for insert with check (true);

create policy "Admins can manage all sample requests"
  on public.sample_requests for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create index idx_sample_requests_status on public.sample_requests(status);
create index idx_sample_requests_user on public.sample_requests(user_id);

-- ──────────────────────────────────────────────
-- 10F. AI JOBS (AI Visualization Job Queue)
-- ──────────────────────────────────────────────
create table public.ai_jobs (
  id                  uuid primary key default uuid_generate_v4(),
  user_id             uuid references public.profiles(id) on delete set null,
  job_type            text not null default 'visualization',
  -- visualization | room_analysis | material_detection
  status              text not null default 'queued',
  -- queued | processing | completed | failed | cancelled
  input_image_url     text not null,
  stone_id            uuid references public.stones(id) on delete set null,
  stone_name          text,
  color               text,
  finish              text,
  result_image_url    text,
  error_message       text,
  metadata            jsonb default '{}',
  -- Additional parameters like wall coordinates, confidence scores, etc.
  processing_time_ms  int,
  created_at          timestamptz not null default now(),
  started_at          timestamptz,
  completed_at        timestamptz,
  updated_at          timestamptz not null default now()
);

alter table public.ai_jobs enable row level security;

create policy "Users can view own AI jobs"
  on public.ai_jobs for select using (auth.uid() = user_id);

create policy "Users can create AI jobs"
  on public.ai_jobs for insert with check (auth.uid() = user_id);

create policy "Admins can manage all AI jobs"
  on public.ai_jobs for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create index idx_ai_jobs_user on public.ai_jobs(user_id);
create index idx_ai_jobs_status on public.ai_jobs(status);
create index idx_ai_jobs_created on public.ai_jobs(created_at desc);

-- ──────────────────────────────────────────────
-- 10G. AR SESSIONS (AR View Session Tracking)
-- ──────────────────────────────────────────────
create table public.ar_sessions (
  id                uuid primary key default uuid_generate_v4(),
  user_id           uuid references public.profiles(id) on delete set null,
  stone_id          uuid references public.stones(id) on delete set null,
  session_type      text not null default 'live_ar',
  -- live_ar | measurement | visualization
  duration_seconds  int,
  interactions      int default 0,
  texture_switches  int default 0,
  measurements_taken int default 0,
  screenshot_taken  boolean default false,
  device_type       text,
  -- iOS | Android | Web
  ar_capability     text,
  -- ARKit | ARCore | WebXR | Fallback
  metadata          jsonb default '{}',
  created_at        timestamptz not null default now(),
  ended_at          timestamptz
);

alter table public.ar_sessions enable row level security;

create policy "Users can view own AR sessions"
  on public.ar_sessions for select using (auth.uid() = user_id);

create policy "Users can create AR sessions"
  on public.ar_sessions for insert with check (auth.uid() = user_id);

create policy "Users can update own AR sessions"
  on public.ar_sessions for update using (auth.uid() = user_id);

create index idx_ar_sessions_user on public.ar_sessions(user_id);
create index idx_ar_sessions_created on public.ar_sessions(created_at desc);

-- ──────────────────────────────────────────────
-- 10H. MEASUREMENTS (AR-Assisted Wall Measurements)
-- ──────────────────────────────────────────────
create table public.measurements (
  id                uuid primary key default uuid_generate_v4(),
  user_id           uuid references public.profiles(id) on delete set null,
  ar_session_id     uuid references public.ar_sessions(id) on delete set null,
  stone_id          uuid references public.stones(id) on delete set null,
  measurement_type  text not null default 'wall',
  -- wall | floor | area
  width_ft          numeric(10,2) not null,
  height_ft         numeric(10,2),
  area_sqft         numeric(10,2) not null,
  wastage_percent   numeric(5,2) default 10,
  total_with_wastage numeric(10,2),
  boxes_needed      int,
  estimated_cost    numeric(12,2),
  unit_system       text not null default 'imperial',
  -- imperial | metric
  confidence_score  numeric(3,2),
  -- 0.0-1.0 AR measurement confidence
  is_ar_assisted    boolean default true,
  notes             text,
  created_at        timestamptz not null default now()
);

alter table public.measurements enable row level security;

create policy "Users can view own measurements"
  on public.measurements for select using (auth.uid() = user_id);

create policy "Users can manage own measurements"
  on public.measurements for all using (auth.uid() = user_id);

create index idx_measurements_user on public.measurements(user_id);
create index idx_measurements_created on public.measurements(created_at desc);

-- ──────────────────────────────────────────────
-- 10I. NOTIFICATIONS
-- ──────────────────────────────────────────────
create table public.notifications (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  title       text not null,
  body        text not null,
  type        text not null default 'info',
  -- info | success | warning | error | order | quote | sample
  data        jsonb default '{}',
  -- Additional context (order_id, quote_id, etc.)
  read        boolean not null default false,
  action_url  text,
  created_at  timestamptz not null default now()
);

alter table public.notifications enable row level security;

create policy "Users can view own notifications"
  on public.notifications for select using (auth.uid() = user_id);

create policy "Users can update own notifications"
  on public.notifications for update using (auth.uid() = user_id);

create policy "System can create notifications"
  on public.notifications for insert with check (true);

create index idx_notifications_user on public.notifications(user_id);
create index idx_notifications_read on public.notifications(read) where read = false;
create index idx_notifications_created on public.notifications(created_at desc);

-- ──────────────────────────────────────────────
-- 10J. ADMIN USERS (Extended Admin Permissions)
-- ──────────────────────────────────────────────
create table public.admin_users (
  id              uuid primary key references public.profiles(id) on delete cascade,
  admin_role      text not null default 'moderator',
  -- super_admin | admin | moderator | content_manager
  permissions     text[] default '{}',
  -- ['manage_products', 'manage_orders', 'manage_users', etc.]
  department      text,
  last_active_at  timestamptz,
  created_at      timestamptz not null default now()
);

alter table public.admin_users enable row level security;

create policy "Admins can view admin users"
  on public.admin_users for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create policy "Super admins can manage admin users"
  on public.admin_users for all
  using (
    exists (
      select 1 from public.admin_users
      where id = auth.uid() and admin_role = 'super_admin'
    )
  );

-- ──────────────────────────────────────────────
-- 10K. AUDIT LOGS (Admin Action Tracking)
-- ──────────────────────────────────────────────
create table public.audit_logs (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid references public.profiles(id) on delete set null,
  action      text not null,
  -- 'created', 'updated', 'deleted', 'login', 'logout'
  entity_type text not null,
  -- 'stone', 'order', 'user', 'collection', etc.
  entity_id   uuid,
  old_value   jsonb,
  new_value   jsonb,
  ip_address  text,
  user_agent  text,
  created_at  timestamptz not null default now()
);

alter table public.audit_logs enable row level security;

create policy "Admins can view audit logs"
  on public.audit_logs for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create policy "System can create audit logs"
  on public.audit_logs for insert with check (true);

create index idx_audit_logs_user on public.audit_logs(user_id);
create index idx_audit_logs_entity on public.audit_logs(entity_type, entity_id);
create index idx_audit_logs_created on public.audit_logs(created_at desc);

-- ──────────────────────────────────────────────
-- 11. STORAGE BUCKETS
-- ──────────────────────────────────────────────
insert into storage.buckets (id, name, public) values ('stones', 'stones', true) on conflict do nothing;
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict do nothing;
insert into storage.buckets (id, name, public) values ('catalogues', 'catalogues', false) on conflict do nothing;
insert into storage.buckets (id, name, public) values ('ai-visualizations', 'ai-visualizations', true) on conflict do nothing;
insert into storage.buckets (id, name, public) values ('ar-screenshots', 'ar-screenshots', true) on conflict do nothing;
insert into storage.buckets (id, name, public) values ('user-uploads', 'user-uploads', false) on conflict do nothing;
insert into storage.buckets (id, name, public) values ('pdfs', 'pdfs', false) on conflict do nothing;

-- ─── Stone images storage policies ───
create policy "Stone images publicly viewable"
  on storage.objects for select using (bucket_id = 'stones');

create policy "Admins can upload stone images"
  on storage.objects for insert
  with check (
    bucket_id = 'stones'
    and exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create policy "Admins can update stone images"
  on storage.objects for update
  using (
    bucket_id = 'stones'
    and exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create policy "Admins can delete stone images"
  on storage.objects for delete
  using (
    bucket_id = 'stones'
    and exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- ─── Avatar storage policies ───
create policy "Avatar images publicly viewable"
  on storage.objects for select using (bucket_id = 'avatars');

create policy "Users can upload own avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can update own avatar"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can delete own avatar"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ─── AI visualizations storage policies ───
create policy "AI visualizations publicly viewable"
  on storage.objects for select using (bucket_id = 'ai-visualizations');

create policy "Users can upload AI visualizations"
  on storage.objects for insert
  with check (
    bucket_id = 'ai-visualizations'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can delete own AI visualizations"
  on storage.objects for delete
  using (
    bucket_id = 'ai-visualizations'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ─── AR screenshots storage policies ───
create policy "AR screenshots publicly viewable"
  on storage.objects for select using (bucket_id = 'ar-screenshots');

create policy "Users can upload AR screenshots"
  on storage.objects for insert
  with check (
    bucket_id = 'ar-screenshots'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can delete own AR screenshots"
  on storage.objects for delete
  using (
    bucket_id = 'ar-screenshots'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ─── User uploads storage policies ───
create policy "Users can view own uploads"
  on storage.objects for select
  using (
    bucket_id = 'user-uploads'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can upload to own folder"
  on storage.objects for insert
  with check (
    bucket_id = 'user-uploads'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can delete own uploads"
  on storage.objects for delete
  using (
    bucket_id = 'user-uploads'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ─── PDF storage policies ───
create policy "Users can view own PDFs"
  on storage.objects for select
  using (
    bucket_id = 'pdfs'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can upload PDFs"
  on storage.objects for insert
  with check (
    bucket_id = 'pdfs'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Admins can view all PDFs"
  on storage.objects for select
  using (
    bucket_id = 'pdfs'
    and exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- ─── Catalogues storage policies (admin only) ───
create policy "Admins can manage catalogues"
  on storage.objects for all
  using (
    bucket_id = 'catalogues'
    and exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- ──────────────────────────────────────────────
-- 12. UPDATED_AT TRIGGER
-- ──────────────────────────────────────────────
create or replace function public.update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger update_profiles_updated_at
  before update on public.profiles
  for each row execute function public.update_updated_at();

create trigger update_stones_updated_at
  before update on public.stones
  for each row execute function public.update_updated_at();

create trigger update_orders_updated_at
  before update on public.orders
  for each row execute function public.update_updated_at();

create trigger update_quote_requests_updated_at
  before update on public.quote_requests
  for each row execute function public.update_updated_at();

create trigger update_sample_requests_updated_at
  before update on public.sample_requests
  for each row execute function public.update_updated_at();

create trigger update_projects_updated_at
  before update on public.projects
  for each row execute function public.update_updated_at();

create trigger update_ai_jobs_updated_at
  before update on public.ai_jobs
  for each row execute function public.update_updated_at();

-- ──────────────────────────────────────────────
-- 13. SEED DATA (Optional — run after schema)
-- ──────────────────────────────────────────────
-- INSERT INTO public.collections (name, slug, description, image_url, sort_order) VALUES
--   ('Grande Ledge', 'grande-ledge', 'Premium ledge collection', null, 1),
--   ('Classic Ledge', 'classic-ledge', 'Timeless classic stones', null, 2),
--   ('Heritage', 'heritage', 'Heritage natural stones', null, 3);

