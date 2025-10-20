# Supabase Code Generator

AI-powered code generator for the TAPN iOS app backend, powered by Claude Agent SDK.

## What It Does

This tool uses Claude Agent SDK to generate and modify code for your Supabase backend. Just describe what you want in natural language, and Claude will:

- Generate SQL migrations for database schema changes
- Create/update Row Level Security (RLS) policies
- Write Swift code for `SupabaseAPIClient`
- Add real-time subscriptions
- Fix bugs and improve existing code
- Update database schemas to match iOS models

## Setup

### 1. Install Dependencies

```bash
cd supabase-generator
npm install
```

### 2. Configure API Key

Create a `.env` file:

```bash
cp .env.example .env
```

Edit `.env` and add your Anthropic API key:

```
ANTHROPIC_API_KEY=your_key_here
```

Get your API key at: https://console.anthropic.com/settings/keys

### 3. Verify iOS Project Path

By default, the generator expects the iOS project at `../TAPN_T-S`. If your project is elsewhere, set:

```bash
IOS_PROJECT_PATH=/path/to/your/ios/project
```

## Usage

### Basic Usage

```bash
npm run generate -- "your prompt here"
```

The generator will prompt you to approve each file change.

### Auto-Apply Mode

Skip confirmation prompts:

```bash
npm run generate -- "your prompt here" --auto-apply
```

## Example Prompts

### Database Migrations

```bash
npm run generate -- "Add an email field to students table with unique constraint"
npm run generate -- "Create teachers table with id, name, email, and auth_user_id"
npm run generate -- "Add an index on students.name for faster searches"
```

### Swift Client Updates

```bash
npm run generate -- "Update studentTapIn to check if the class is currently active"
npm run generate -- "Add retry logic with exponential backoff to all API methods"
npm run generate -- "Implement batch insert for multiple students at once"
```

### JSONB Operations

```bash
npm run generate -- "Fix setCategories to merge categories into existing settings instead of replacing"
npm run generate -- "Add a method to update only one field in the settings JSONB"
```

### Real-time Features

```bash
npm run generate -- "Add real-time subscription to AppState that listens for student table changes"
npm run generate -- "Implement presence tracking showing which teachers are viewing each class"
```

### Security & RLS Policies

```bash
npm run generate -- "Create RLS policies so only authenticated teachers can modify classes"
npm run generate -- "Add RLS policy allowing students to only update their own records"
```

### Bug Fixes

```bash
npm run generate -- "Fix timezone handling to store all timestamps in UTC"
npm run generate -- "Handle the case where a student taps in twice without tapping out"
```

## How It Works

1. **Context Loading**: Reads your iOS models (`Models.swift`, `TAPNAPI.swift`, etc.)
2. **Prompt Enhancement**: Combines your prompt with project context and best practices
3. **Code Generation**: Claude Agent SDK generates or modifies files
4. **Review & Apply**: You approve changes (unless `--auto-apply` is used)

## Tips

- Be specific in your prompts
- Mention if you want to modify existing code vs create new files
- For complex changes, break them into smaller prompts
- Use `--auto-apply` only when you trust the output

## Troubleshooting

### "ANTHROPIC_API_KEY not set"

Make sure you've created `.env` with your API key.

### "iOS project not found"

Set the correct path:
```bash
export IOS_PROJECT_PATH=/path/to/TAPN_T-S
```

### Import errors after generation

Make sure to add any new Swift files to your Xcode project:
1. Right-click on `TAPN_T+S` folder in Xcode
2. Select "Add Files to..."
3. Choose the generated files

## Architecture

```
supabase-generator/
├── src/
│   ├── index.ts              # CLI entry point
│   └── generateFromPrompt.ts # Core generation logic
├── package.json
├── tsconfig.json
└── .env                      # Your API key (gitignored)
```

## License

MIT