-- Fix: Remove all conflicting RLS policies and recreate clean ones
-- Run this in your Supabase SQL Editor

-- ============================================================================
-- STEP 1: Drop ALL existing policies on class_sessions
-- ============================================================================

DROP POLICY IF EXISTS "Public can read class_sessions" ON class_sessions;
DROP POLICY IF EXISTS "Public can insert class_sessions" ON class_sessions;
DROP POLICY IF EXISTS "Public can update class_sessions" ON class_sessions;
DROP POLICY IF EXISTS "Public can delete class_sessions" ON class_sessions;
DROP POLICY IF EXISTS "Anyone can view class sessions" ON class_sessions;
DROP POLICY IF EXISTS "Teachers can manage their own classes" ON class_sessions;
DROP POLICY IF EXISTS "Students can view classes they're rostered in" ON class_sessions;

-- ============================================================================
-- STEP 2: Drop ALL existing policies on students
-- ============================================================================

DROP POLICY IF EXISTS "Public can read students" ON students;
DROP POLICY IF EXISTS "Public can insert students" ON students;
DROP POLICY IF EXISTS "Public can update students" ON students;
DROP POLICY IF EXISTS "Public can delete students" ON students;
DROP POLICY IF EXISTS "Students can view own attendance" ON students;
DROP POLICY IF EXISTS "Users can view attendance for rostered classes" ON students;
DROP POLICY IF EXISTS "Rostered students can record attendance" ON students;
DROP POLICY IF EXISTS "Students can update own attendance" ON students;

-- ============================================================================
-- STEP 3: Create clean, non-conflicting policies for class_sessions
-- ============================================================================

-- Policy 1: Authenticated users can insert classes (they become the teacher)
CREATE POLICY "Authenticated users can create classes"
  ON class_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK (teacher_id = auth.uid());

-- Policy 2: Teachers can view/update/delete their own classes
CREATE POLICY "Teachers can manage their own classes"
  ON class_sessions
  FOR ALL
  TO authenticated
  USING (teacher_id = auth.uid())
  WITH CHECK (teacher_id = auth.uid());

-- Policy 3: Students can view classes they're rostered in
CREATE POLICY "Students can view rostered classes"
  ON class_sessions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM class_rosters
      WHERE class_rosters.class_session_id = class_sessions.id
      AND class_rosters.student_user_id = auth.uid()
    )
  );

-- ============================================================================
-- STEP 4: Create clean, non-conflicting policies for students
-- ============================================================================

-- Policy 1: Teachers can view all students in their classes
CREATE POLICY "Teachers can view class attendance"
  ON students
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM class_sessions
      WHERE class_sessions.id = students.class_session_id
      AND class_sessions.teacher_id = auth.uid()
    )
  );

-- Policy 2: Students can view their own attendance
CREATE POLICY "Students can view own attendance"
  ON students
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Policy 3: Rostered students can insert their attendance
CREATE POLICY "Rostered students can tap in"
  ON students
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM class_rosters
      WHERE class_rosters.class_session_id = students.class_session_id
      AND class_rosters.student_user_id = auth.uid()
    )
    AND user_id = auth.uid()
  );

-- Policy 4: Students can update their own attendance (tap out)
CREATE POLICY "Students can tap out"
  ON students
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- STEP 5: Fix class_rosters policies to prevent circular references
-- ============================================================================

DROP POLICY IF EXISTS "Teachers can manage their class rosters" ON class_rosters;
DROP POLICY IF EXISTS "Students can view their class rosters" ON class_rosters;

-- Policy 1: Teachers can manage rosters (simplified - no circular reference)
CREATE POLICY "Teachers manage rosters"
  ON class_rosters
  FOR ALL
  TO authenticated
  USING (
    -- Check class_sessions table directly without recursion
    (SELECT teacher_id FROM class_sessions WHERE id = class_session_id) = auth.uid()
  )
  WITH CHECK (
    (SELECT teacher_id FROM class_sessions WHERE id = class_session_id) = auth.uid()
  );

-- Policy 2: Students can view their roster entries
CREATE POLICY "Students view own roster"
  ON class_rosters
  FOR SELECT
  TO authenticated
  USING (student_user_id = auth.uid());

-- ============================================================================
-- Done! Policies are now clean and non-recursive
-- ============================================================================
