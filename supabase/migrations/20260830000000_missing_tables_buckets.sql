-- Applies the tail end of schema.sql that never reached production:
-- saved_designs, projects, project_items, sample_requests, ai_jobs,
-- ar_sessions, measurements, notifications, admin_users, audit_logs,
-- the 4 missing storage buckets + their policies, and the triggers
-- that depend on these tables. Everything here is additive only —
-- no existing table, row, or policy is touched.

create extension if not exists "uuid-ossp";

-- ──────────────────────────────────────────────
-- 10B. SAVED DESIGNS
-- ──────────────────────────────────────────────
create table if not exists public.saved_designs (
  id                  uuid primary key default gen_random_uuid(),
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
create table if not exists public.projects (
  id              uuid primary key default gen_random_uuid(),
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
create table if not exists public.project_items (
  id              uuid primary key default gen_random_uuid(),
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
create table if not exists public.sample_requests (
  id              uuid primary key default gen_random_uuid(),
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

create index if not exists idx_sample_requests_status on public.sample_requests(status);
create index if not exists idx_sample_requests_user on public.sample_requests(user_id);

-- ──────────────────────────────────────────────
-- 10F. AI JOBS (AI Visualization Job Queue)
-- ──────────────────────────────────────────────
create table if not exists public.ai_jobs (
  id                  uuid primary key default gen_random_uuid(),
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

create index if not exists idx_ai_jobs_user on public.ai_jobs(user_id);
create index if not exists idx_ai_jobs_status on public.ai_jobs(status);
create index if not exists idx_ai_jobs_created on public.ai_jobs(created_at desc);

-- ──────────────────────────────────────────────
-- 10G. AR SESSIONS (AR View Session Tracking)
-- ──────────────────────────────────────────────
create table if not exists public.ar_sessions (
  id                uuid primary key default gen_random_uuid(),
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

create index if not exists idx_ar_sessions_user on public.ar_sessions(user_id);
create index if not exists idx_ar_sessions_created on public.ar_sessions(created_at desc);

-- ──────────────────────────────────────────────
-- 10H. MEASUREMENTS (AR-Assisted Wall Measurements)
-- ──────────────────────────────────────────────
create table if not exists public.measurements (
  id                uuid primary key default gen_random_uuid(),
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

create index if not exists idx_measurements_user on public.measurements(user_id);
create index if not exists idx_measurements_created on public.measurements(created_at desc);

-- ──────────────────────────────────────────────
-- 10I. NOTIFICATIONS
-- ──────────────────────────────────────────────
create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
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

create index if not exists idx_notifications_user on public.notifications(user_id);
create index if not exists idx_notifications_read on public.notifications(read) where read = false;
create index if not exists idx_notifications_created on public.notifications(created_at desc);

-- ──────────────────────────────────────────────
-- 10J. ADMIN USERS (Extended Admin Permissions)
-- ──────────────────────────────────────────────
create table if not exists public.admin_users (
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
create table if not exists public.audit_logs (
  id          uuid primary key default gen_random_uuid(),
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

create index if not exists idx_audit_logs_user on public.audit_logs(user_id);
create index if not exists idx_audit_logs_entity on public.audit_logs(entity_type, entity_id);
create index if not exists idx_audit_logs_created on public.audit_logs(created_at desc);

-- ──────────────────────────────────────────────
-- 11. MISSING STORAGE BUCKETS
-- ──────────────────────────────────────────────
insert into storage.buckets (id, name, public) values ('ai-visualizations', 'ai-visualizations', true) on conflict do nothing;
insert into storage.buckets (id, name, public) values ('ar-screenshots', 'ar-screenshots', true) on conflict do nothing;
insert into storage.buckets (id, name, public) values ('user-uploads', 'user-uploads', false) on conflict do nothing;
insert into storage.buckets (id, name, public) values ('pdfs', 'pdfs', false) on conflict do nothing;

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

-- ──────────────────────────────────────────────
-- 12. UPDATED_AT TRIGGERS for newly created tables
-- (public.update_updated_at() already exists from the original migration)
-- ──────────────────────────────────────────────
create trigger update_sample_requests_updated_at
  before update on public.sample_requests
  for each row execute function public.update_updated_at();

create trigger update_projects_updated_at
  before update on public.projects
  for each row execute function public.update_updated_at();

create trigger update_ai_jobs_updated_at
  before update on public.ai_jobs
  for each row execute function public.update_updated_at();
