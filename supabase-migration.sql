-- Supabase Database Schema for TAPN Classroom Attendance App
-- Run this in your Supabase SQL Editor: https://app.supabase.com/project/_/sql

-- ============================================================================
-- TABLES
-- ============================================================================

-- class_sessions table
create table if not exists class_sessions (
  id uuid primary key default gen_random_uuid(),
  subject text not null,
  time_label text not null,
  start_time timestamptz,
  end_time timestamptz,
  settings jsonb not null default '{
    "categories": [],
    "allowedApps": [],
    "durationMinutes": 30
  }'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- students table
create table if not exists students (
  id uuid primary key default gen_random_uuid(),
  class_session_id uuid not null references class_sessions(id) on delete cascade,
  name text not null,
  tapped_in_at timestamptz,
  tapped_out_at timestamptz,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- INDEXES
-- ============================================================================

create index if not exists students_class_session_id_idx
  on students(class_session_id);

create index if not exists class_sessions_start_time_idx
  on class_sessions(start_time);

create index if not exists students_name_idx
  on students(name);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS
alter table class_sessions enable row level security;
alter table students enable row level security;

-- Public access policies (for prototype - restrict later with authentication)
create policy "Public can read class_sessions"
  on class_sessions for select
  to anon using (true);

create policy "Public can insert class_sessions"
  on class_sessions for insert
  to anon with check (true);

create policy "Public can update class_sessions"
  on class_sessions for update
  to anon using (true);

create policy "Public can delete class_sessions"
  on class_sessions for delete
  to anon using (true);

create policy "Public can read students"
  on students for select
  to anon using (true);

create policy "Public can insert students"
  on students for insert
  to anon with check (true);

create policy "Public can update students"
  on students for update
  to anon using (true);

create policy "Public can delete students"
  on students for delete
  to anon using (true);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Function to update updated_at timestamp
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Trigger for class_sessions
drop trigger if exists update_class_sessions_updated_at on class_sessions;
create trigger update_class_sessions_updated_at
  before update on class_sessions
  for each row execute function update_updated_at_column();

-- ============================================================================
-- REALTIME
-- ============================================================================

-- Enable Realtime for live attendance updates
alter publication supabase_realtime add table class_sessions;
alter publication supabase_realtime add table students;

-- ============================================================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================================================

-- Uncomment to insert sample data:
-- insert into class_sessions (subject, time_label) values
--   ('Math', '10:00–11:00'),
--   ('Science', '11:00–12:00'),
--   ('English', '1:00–2:00');
