# Supabase Setup Guide for TAPN iOS App

This guide will help you integrate Supabase backend into your iOS classroom attendance app.

## What's Been Created

### iOS Swift Files
1. **SupabaseClient.swift** - Initializes the Supabase client
2. **SupabaseModels.swift** - Data Transfer Objects (DTOs) for database serialization
3. **SupabaseAPIClient.swift** - Implements all TAPNAPI methods using Supabase

### Database
1. **supabase-migration.sql** - Complete database schema with tables, indexes, RLS policies

### Code Generator
1. **supabase-generator/** - AI-powered code generator using Claude Agent SDK
   - Generates SQL migrations
   - Writes Swift client code
   - Creates RLS policies
   - Adds real-time features

## Quick Start (5 Steps)

### Step 1: Create Supabase Project

1. Go to https://database.new
2. Create a new project (remember your database password!)
3. Wait for project to finish setting up (~2 minutes)

### Step 2: Run Database Migration

1. In your Supabase dashboard, go to **SQL Editor**
2. Click **New Query**
3. Copy the contents of `supabase-migration.sql`
4. Paste and click **Run**

This creates:
- `class_sessions` table
- `students` table
- Indexes for performance
- Row Level Security policies
- Real-time subscriptions

### Step 3: Get Your Supabase Credentials

1. In Supabase dashboard, go to **Settings** > **API**
2. Copy:
   - **Project URL** (e.g., `https://abcdefgh.supabase.co`)
   - **anon/public key** (starts with `eyJhbGc...`)

### Step 4: Configure iOS App

1. Open `TAPN_T+S/SupabaseClient.swift`
2. Replace the placeholders:
   ```swift
   let supabaseURL = URL(string: "YOUR_SUPABASE_URL")!
   let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
   ```

3. Add Supabase Swift package to Xcode:
   - File → Add Package Dependencies
   - Enter: `https://github.com/supabase/supabase-swift.git`
   - Version: 2.0.0 or later

4. Add the new Swift files to your Xcode project:
   - Right-click `TAPN_T+S` folder in Xcode
   - Select **Add Files to "TAPN_T+S"...**
   - Add:
     - SupabaseClient.swift
     - SupabaseModels.swift
     - SupabaseAPIClient.swift

### Step 5: Switch to Supabase

Open `TAPN_T+S/TAPN_T_SApp.swift` and change line 5:

```swift
// FROM:
@StateObject private var app = AppState(api: MockAPIClient())

// TO:
@StateObject private var app = AppState(api: SupabaseAPIClient())
```

**That's it!** Build and run your app (Cmd+R). It's now using Supabase!

## Testing Your Setup

1. Launch the app in simulator
2. Select "Teacher" role
3. Create a new class
4. Start the class
5. Go to Supabase dashboard → **Table Editor** → `class_sessions`
6. You should see your class appear in the database!

## Using the Code Generator

The code generator lets you modify your backend with natural language prompts.

### Setup Generator

```bash
cd supabase-generator
npm install
cp .env.example .env
```

Edit `.env` and add your Anthropic API key:
```
ANTHROPIC_API_KEY=sk-ant-...
```

Get your API key at: https://console.anthropic.com/settings/keys

### Usage Examples

```bash
# Add a new field to database
npm run generate -- "Add an email field to the students table with unique constraint"

# Modify Swift client
npm run generate -- "Update studentTapIn to check if class is currently active before allowing tap-in"

# Add real-time updates
npm run generate -- "Add real-time subscription to AppState that updates when students tap in/out"

# Fix bugs
npm run generate -- "Fix the timezone handling to store all timestamps in UTC"
```

The generator will:
1. Read your iOS models for context
2. Generate the appropriate code
3. Prompt you to review and approve changes
4. Apply the changes to your files

## Troubleshooting

### "Cannot find 'supabase' in scope"

Make sure you added the Supabase Swift package via Xcode Package Dependencies.

### "Connection failed" errors

Double-check your URL and anon key in `SupabaseClient.swift`.

### Build errors after adding files

Make sure all new Swift files are added to your Xcode target:
1. Select the file in Xcode
2. Open File Inspector (right sidebar)
3. Check "TAPN_T+S" under Target Membership

### Generator: "ANTHROPIC_API_KEY not set"

Create `.env` file in `supabase-generator/` with your API key.

## Next Steps

### Enable Real-time Updates

For live attendance across devices, add real-time subscriptions:

```bash
cd supabase-generator
npm run generate -- "Add real-time subscription to AppState for live student updates"
```

### Add Authentication

For production, add teacher authentication:

```bash
npm run generate -- "Create teachers table with Supabase Auth integration"
npm run generate -- "Update RLS policies to require authentication for teacher actions"
```

### Deploy to Production

1. In Supabase dashboard, upgrade to a paid plan if needed
2. Update RLS policies to restrict public access
3. Add authentication for teachers
4. Enable database backups
5. Monitor usage in Supabase dashboard

## Architecture Overview

```
┌─────────────────┐
│   iOS App       │
│   (Swift)       │
└────────┬────────┘
         │ supabase-swift SDK
         ▼
┌─────────────────┐
│   Supabase      │
│   - PostgreSQL  │
│   - Auth        │
│   - Real-time   │
│   - Storage     │
└─────────────────┘
```

**No Node.js backend needed!** iOS connects directly to Supabase.

## Resources

- Supabase Docs: https://supabase.com/docs
- Supabase Swift SDK: https://github.com/supabase/supabase-swift
- Claude Agent SDK: https://docs.claude.com/en/api/agent-sdk
- Your code generator: `supabase-generator/README.md`

## Support

- For Supabase issues: https://supabase.com/support
- For Claude Agent SDK: https://anthropic.com/discord
- Check `CLAUDE.md` for project-specific documentation
