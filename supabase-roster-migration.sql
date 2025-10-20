-- Migration: Add teacher-managed rosters

-- 1. Add teacher_id to class_sessions
ALTER TABLE class_sessions
ADD COLUMN teacher_id UUID REFERENCES users(id) ON DELETE SET NULL;

-- Create index for faster teacher class lookups
CREATE INDEX IF NOT EXISTS idx_class_sessions_teacher_id ON class_sessions(teacher_id);

-- 2. Create class_rosters table
CREATE TABLE IF NOT EXISTS class_rosters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_session_id UUID NOT NULL REFERENCES class_sessions(id) ON DELETE CASCADE,
  student_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  added_at TIMESTAMPTZ DEFAULT NOW(),
  added_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE(class_session_id, student_user_id)
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_class_rosters_class_session ON class_rosters(class_session_id);
CREATE INDEX IF NOT EXISTS idx_class_rosters_student_user ON class_rosters(student_user_id);

-- Enable Row Level Security
ALTER TABLE class_rosters ENABLE ROW LEVEL SECURITY;

-- Policy: Teachers can manage rosters for their classes
CREATE POLICY "Teachers can manage their class rosters"
  ON class_rosters
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM class_sessions
      WHERE class_sessions.id = class_rosters.class_session_id
      AND class_sessions.teacher_id = auth.uid()
    )
  );

-- Policy: Students can view rosters they're part of
CREATE POLICY "Students can view their class rosters"
  ON class_rosters
  FOR SELECT
  USING (student_user_id = auth.uid());

-- 3. Add user_id to students table
ALTER TABLE students
ADD COLUMN user_id UUID REFERENCES users(id) ON DELETE SET NULL;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_students_user_id ON students(user_id);

-- 4. Update students table RLS policies to check roster membership
DROP POLICY IF EXISTS "Students can view own attendance" ON students;

CREATE POLICY "Users can view attendance for rostered classes"
  ON students
  FOR SELECT
  USING (
    -- Teacher can see all students in their classes
    EXISTS (
      SELECT 1 FROM class_sessions
      WHERE class_sessions.id = students.class_session_id
      AND class_sessions.teacher_id = auth.uid()
    )
    OR
    -- Student can see their own attendance
    user_id = auth.uid()
  );

CREATE POLICY "Rostered students can record attendance"
  ON students
  FOR INSERT
  WITH CHECK (
    -- Must be rostered in the class
    EXISTS (
      SELECT 1 FROM class_rosters
      WHERE class_rosters.class_session_id = students.class_session_id
      AND class_rosters.student_user_id = auth.uid()
    )
    AND user_id = auth.uid()
  );

CREATE POLICY "Students can update own attendance"
  ON students
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 5. Add RLS policies for class_sessions based on teacher ownership
DROP POLICY IF EXISTS "Anyone can view class sessions" ON class_sessions;

CREATE POLICY "Teachers can manage their own classes"
  ON class_sessions
  FOR ALL
  USING (teacher_id = auth.uid())
  WITH CHECK (teacher_id = auth.uid());

CREATE POLICY "Students can view classes they're rostered in"
  ON class_sessions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM class_rosters
      WHERE class_rosters.class_session_id = class_sessions.id
      AND class_rosters.student_user_id = auth.uid()
    )
  );

-- 6. Create helper function to get user's rostered classes
CREATE OR REPLACE FUNCTION get_user_rostered_classes(user_uuid UUID)
RETURNS TABLE (
  class_id UUID,
  subject TEXT,
  time_label TEXT,
  is_active BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    cs.id,
    cs.subject,
    cs.time_label,
    (cs.start_time IS NOT NULL AND cs.end_time IS NULL) as is_active
  FROM class_sessions cs
  INNER JOIN class_rosters cr ON cs.id = cr.class_session_id
  WHERE cr.student_user_id = user_uuid
  ORDER BY cs.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;