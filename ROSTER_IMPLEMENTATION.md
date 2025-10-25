# Roster Management Implementation

This document describes the teacher-managed roster system implemented for the TAPN app.

## Overview

The roster system allows teachers to create classes and manage student rosters. Students can only tap in to classes where they've been added to the roster by a teacher. This provides proper access control and ensures students are enrolled in the correct classes.

## Database Schema

### Tables Created

#### `class_rosters`
- `id` (UUID, PRIMARY KEY)
- `class_session_id` (UUID, REFERENCES class_sessions)
- `student_user_id` (UUID, REFERENCES users)
- `added_at` (TIMESTAMPTZ)
- `added_by_user_id` (UUID, REFERENCES users)
- **UNIQUE constraint** on (class_session_id, student_user_id)

### Tables Modified

#### `class_sessions`
- Added `teacher_id` (UUID, REFERENCES users) - Links class to teacher who created it

#### `students`
- Added `user_id` (UUID, REFERENCES users) - Links attendance records to user accounts

## Row Level Security (RLS)

The migration includes comprehensive RLS policies:

### class_rosters Policies
- **Teachers can manage their class rosters**: Teachers can create/read/update/delete roster entries for classes they own
- **Students can view their class rosters**: Students can view roster entries where they are the student

### students Policies
- **Users can view attendance for rostered classes**: Teachers see all students in their classes, students see their own attendance
- **Rostered students can record attendance**: Only students on the roster can create attendance records
- **Students can update own attendance**: Students can only update their own attendance records

### class_sessions Policies
- **Teachers can manage their own classes**: Full CRUD access to classes they created
- **Students can view classes they're rostered in**: Read-only access to classes they're enrolled in

## Data Models

### Swift Models (Models.swift)

#### `UserProfile` (Lines 7-20)
```swift
struct UserProfile: Codable, Hashable {
    let id: UUID
    let email: String
    var role: UserRole?
    var name: String
    let createdAt: Date
    var updatedAt: Date
}
```

#### `Student` (Lines 64-94)
```swift
struct Student: Identifiable, Hashable, Codable {
    let id: UUID
    var userId: UUID?  // Link to authenticated user
    var name: String
    var tappedInAt: Date?
    var tappedOutAt: Date?
}
```

#### `ClassSession` (Lines 97-138)
```swift
struct ClassSession: Identifiable, Hashable, Codable {
    let id: UUID
    var teacherId: UUID?  // Link to teacher who created the class
    var subject: String
    var timeLabel: String
    var students: [Student]
    var roster: [RosterEntry]  // Students assigned to this class
    var settings: SessionSettings = .init()
    var startTime: Date?
    var endTime: Date?
}
```

#### `RosterEntry` (Lines 140-158)
```swift
struct RosterEntry: Identifiable, Hashable, Codable {
    let id: UUID
    let classSessionId: UUID
    let studentUserId: UUID
    let studentName: String  // Denormalized for display
    let studentEmail: String  // For searching/inviting
    let addedAt: Date
    let addedByUserId: UUID?
}
```

### DTOs (SupabaseModels.swift)

Corresponding DTOs created for database mapping with snake_case fields:
- `ClassSessionDTO` - Updated to include roster
- `StudentDTO` - Updated to include user_id
- `RosterEntryDTO` - New DTO for roster entries
- `RosterEntryInsert` - Helper for inserting roster entries

## API Layer

### SupabaseAPIClient Methods

#### User Profile Methods (Lines 6-69)
- `getUserProfile(userId:)` - Fetch user profile
- `createUserProfile(userId:email:role:name:)` - Create new user profile
- `updateUserRole(userId:role:)` - Update user's role
- `updateUserName(userId:name:)` - Update user's name

#### Roster Management Methods (Lines 282-346)

##### `addStudentToRoster(classId:studentEmail:addedBy:)`
Adds a student to a class roster by email address:
1. Searches for user by email
2. Creates roster entry
3. Returns updated class with roster

##### `removeStudentFromRoster(classId:studentUserId:)`
Removes a student from a class roster:
1. Deletes roster entry
2. Returns updated class

##### `getStudentClasses(userId:)`
Gets all classes a student is rostered in:
1. Queries class_sessions with inner join on class_rosters
2. Filters by student user_id
3. Returns list of classes

##### `searchUsersByEmail(query:)`
Searches for users by email (for adding to roster):
1. Performs case-insensitive LIKE search
2. Limits to 10 results
3. Returns matching user profiles

#### Updated Methods

##### `studentTapIn(classID:userId:studentName:)` (Lines 228-279)
Enhanced with roster validation:
1. **Checks roster membership** - Throws error if student not on roster
2. Checks for existing attendance record
3. Either updates existing or creates new attendance record
4. Returns updated class

##### `createClass(subject:timeLabel:teacherId:)` (Lines 84-101)
Now requires `teacherId` parameter to link class to teacher

## State Management

### AppState Methods

#### Roster Operations (Lines 311-353)

##### `addStudentToRoster(classId:studentEmail:)`
```swift
func addStudentToRoster(classId: UUID, studentEmail: String) async throws
```
Adds student to roster and updates local state.

##### `removeStudentFromRoster(classId:studentUserId:)`
```swift
func removeStudentFromRoster(classId: UUID, studentUserId: UUID) async throws
```
Removes student from roster and updates local state.

##### `loadStudentClasses()`
```swift
func loadStudentClasses() async
```
Loads all classes for the current student user.

##### `searchUsersByEmail(query:)`
```swift
func searchUsersByEmail(query: String) async throws -> [UserProfile]
```
Searches for users to add to roster.

#### Updated Methods

##### `addClass(subject:timeLabel:)` (Lines 180-188)
Now passes current user's ID as teacherId when creating class.

##### `studentTapIn()` (Lines 277-287)
Updated to be async/throws for proper error handling:
```swift
func studentTapIn() async throws
```

## User Interface

### Teacher Views

#### AddStudentToRosterView
Search and add students to class roster:
- Email search functionality
- Filters to show only students
- Shows which users are already on roster
- Displays success/error messages
- Auto-clears search after successful add

#### ClassRosterManagementView
View and manage class roster:
- Lists all students on roster with email and add date
- Remove button for each student
- Confirmation dialog before removal
- Add button to open AddStudentToRosterView
- Empty state when no students on roster

#### TeacherClassView (Updated, Lines 22-44)
Enhanced to show roster information:
- Displays roster count
- "Manage" button to open roster management
- Helpful message when roster is empty
- Existing attendance list below roster section

### Student Views

#### StudentHomeView (Updated)

**Rostered Classes Display** (Lines 17-36)
- Horizontal scrolling list of rostered classes
- Shows subject, time label, and active status
- Automatically loads on view appear

**ClassCard Component** (Lines 144-173)
```swift
struct ClassCard: View {
    let classSession: ClassSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(classSession.subject)
            Text(classSession.timeLabel)
            if classSession.isActive {
                // Green "Active" indicator
            }
        }
    }
}
```

**Error Handling UI** (Lines 91-120)
- Displays error overlay when tap-in fails
- Shows error icon and message
- Clear "Dismiss" button
- Specifically handles "not on roster" errors

**Updated Scan Logic** (Lines 135-164)
- Async error handling in NFC callback
- Shows success or error based on result
- Only navigates to in-class view on success

## Error Handling

### RosterError Enum (SupabaseAPIClient.swift:362-377)

```swift
enum RosterError: LocalizedError {
    case userNotFound
    case alreadyOnRoster
    case notOnRoster

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "No user found with that email address"
        case .alreadyOnRoster:
            return "Student is already on the roster"
        case .notOnRoster:
            return "You are not on the roster for this class. Please contact your teacher."
        }
    }
}
```

## User Workflows

### Teacher Workflow

1. **Sign in** with Google account (role: teacher)
2. **Create a class** using the + button on TeacherHomeView
3. **Open the class** to view details
4. **Tap "Manage"** in the roster section
5. **Tap "+"** to add a student
6. **Search by email** to find student
7. **Tap "Add"** to add student to roster
8. **Remove students** using trash icon if needed
9. **Start class** when ready for attendance
10. **View attendance** as students tap in

### Student Workflow

1. **Sign in** with Google account (role: student)
2. **View rostered classes** on home screen
3. **Wait for active class** (teacher must start it)
4. **Tap NFC tag** to tap in
5. **Success**: Navigates to in-class view
6. **Failure**: Shows error message if not on roster
7. **Contact teacher** if not on roster but should be

## Security Features

1. **Database-level security**: RLS policies enforce access control at the database
2. **Roster validation**: Students cannot tap in unless on roster
3. **Teacher ownership**: Teachers can only manage their own classes
4. **Role-based access**: Teachers and students have different permissions
5. **Unique constraints**: Prevents duplicate roster entries
6. **Cascade deletes**: Removing a class removes all roster entries

## Migration Instructions

### Running the Migration

```bash
# In your Supabase SQL Editor, run:
cat supabase-roster-migration.sql
```

Or copy the contents of `supabase-roster-migration.sql` and paste into the Supabase SQL Editor.

### Migration Contents

The migration file includes:
1. Add teacher_id column to class_sessions
2. Create class_rosters table with indexes
3. Add user_id column to students table
4. Update RLS policies for all tables
5. Create helper function get_user_rostered_classes()

## Files Modified/Created

### Created Files
- `AddStudentToRosterView.swift` - Add student UI
- `ClassRosterManagementView.swift` - Manage roster UI
- `supabase-roster-migration.sql` - Database migration
- `ROSTER_IMPLEMENTATION.md` - This documentation

### Modified Files
- `Models.swift` - Added UserProfile, updated Student/ClassSession/RosterEntry
- `SupabaseModels.swift` - Added DTOs for roster management
- `SupabaseAPIClient.swift` - Added roster methods, updated studentTapIn
- `AppState.swift` - Added roster operations, updated studentTapIn
- `TeacherClassView.swift` - Added roster section and management
- `StudentHomeView.swift` - Added rostered classes display, error handling

## Testing Checklist

### Teacher Testing
- [ ] Create a new class
- [ ] Open roster management
- [ ] Search for student by email
- [ ] Add student to roster
- [ ] Verify student appears in roster list
- [ ] Remove student from roster
- [ ] Verify student is removed
- [ ] Start class and verify attendance works

### Student Testing
- [ ] Sign in as student
- [ ] Verify rostered classes appear on home screen
- [ ] Verify active classes show "Active" indicator
- [ ] Attempt to tap in to rostered class (should succeed)
- [ ] Attempt to tap in to non-rostered class (should fail with error)
- [ ] Verify error message is clear and helpful
- [ ] Verify navigation only happens on success

### Edge Cases
- [ ] Adding duplicate student (should fail gracefully)
- [ ] Searching for non-existent email
- [ ] Student with no rostered classes
- [ ] Teacher with no classes
- [ ] Class with no roster entries
- [ ] Multiple students tapping in simultaneously

## Future Enhancements

Possible improvements to the roster system:

1. **Bulk import**: CSV upload for adding multiple students
2. **Student invitations**: Email invites for students to join class
3. **Roster templates**: Save and reuse rosters across semesters
4. **Class codes**: Generate join codes for students to self-enroll
5. **Waitlist**: Queue for students requesting to join
6. **Attendance reports**: Export attendance data by roster
7. **Parent access**: Allow parents to view student's rostered classes
8. **Schedule integration**: Sync with school schedule systems
9. **Notifications**: Alert students when added to roster
10. **Audit log**: Track who added/removed students and when

## Troubleshooting

### Common Issues

**Issue**: Student can't tap in
- **Check**: Is student on the roster?
- **Check**: Is the class active?
- **Check**: Does student have the correct role?

**Issue**: Teacher can't add student
- **Check**: Does the student user exist with role=student?
- **Check**: Is the email spelled correctly?
- **Check**: Has the student signed in at least once?

**Issue**: Roster not loading
- **Check**: Did the migration run successfully?
- **Check**: Are RLS policies enabled?
- **Check**: Check browser console for errors

**Issue**: Duplicate roster entries
- **Check**: Database should prevent this with UNIQUE constraint
- **Check**: If occurring, check migration ran correctly

## Support

For questions or issues with the roster implementation, check:
1. This documentation
2. Database migration file: `supabase-roster-migration.sql`
3. RLS policies in Supabase dashboard
4. API client implementation: `SupabaseAPIClient.swift`
