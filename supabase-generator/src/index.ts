#!/usr/bin/env node
import 'dotenv/config';
import { generateFromPrompt } from './generateFromPrompt.js';
import * as path from 'path';
import * as fs from 'fs';

async function main() {
  const args = process.argv.slice(2);

  // Show help
  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    console.log(`
┌─────────────────────────────────────────────────────────────────┐
│  Supabase Code Generator - Powered by Claude Agent SDK         │
└─────────────────────────────────────────────────────────────────┘

Usage:
  npm run generate -- "your prompt here" [options]

Options:
  --auto-apply    Auto-accept all file edits (no confirmation prompts)
  --help, -h      Show this help message

Examples:
  # Database migrations
  npm run generate -- "Add email field to students table with unique constraint"
  npm run generate -- "Create an index on students.name for faster lookups"

  # Swift client updates
  npm run generate -- "Update studentTapIn to validate the class is currently active"
  npm run generate -- "Add error handling for network failures in all API methods"

  # JSONB operations
  npm run generate -- "Fix setCategories to merge categories into existing settings"

  # Real-time features
  npm run generate -- "Add real-time subscription to AppState for student changes"

  # RLS policies
  npm run generate -- "Create RLS policies requiring authentication for write operations"

  # Bug fixes
  npm run generate -- "Fix timezone handling for consistent UTC storage"

Environment:
  ANTHROPIC_API_KEY  Required - Get yours at https://console.anthropic.com
  IOS_PROJECT_PATH   Optional - Defaults to ../TAPN_T-S
    `);
    process.exit(0);
  }

  // Check for API key
  if (!process.env.ANTHROPIC_API_KEY) {
    console.error('❌ Error: ANTHROPIC_API_KEY environment variable is not set');
    console.error('');
    console.error('Please create a .env file with your API key:');
    console.error('  ANTHROPIC_API_KEY=your_key_here');
    console.error('');
    console.error('Get your API key at: https://console.anthropic.com/settings/keys');
    process.exit(1);
  }

  // Parse arguments
  const autoApply = args.includes('--auto-apply');
  const prompt = args.filter(arg => !arg.startsWith('--')).join(' ');

  if (!prompt.trim()) {
    console.error('❌ Error: Please provide a prompt');
    console.error('');
    console.error('Example:');
    console.error('  npm run generate -- "Add a new endpoint for teacher authentication"');
    process.exit(1);
  }

  // Determine iOS project directory
  const iosProjectDir = process.env.IOS_PROJECT_PATH
    ? path.resolve(process.env.IOS_PROJECT_PATH)
    : path.resolve(__dirname, '../../TAPN_T-S');

  // Verify iOS project exists
  if (!fs.existsSync(iosProjectDir)) {
    console.error(`❌ Error: iOS project not found at ${iosProjectDir}`);
    console.error('');
    console.error('Set the correct path using IOS_PROJECT_PATH environment variable');
    process.exit(1);
  }

  console.log('📱 iOS Project:', iosProjectDir);
  console.log('🔧 Auto-apply:', autoApply ? 'Yes' : 'No (will prompt for confirmation)');
  console.log('');

  // Run code generation
  try {
    await generateFromPrompt(prompt, {
      iosProjectDir,
      autoApply
    });
  } catch (error) {
    console.error('');
    console.error('❌ Code generation failed');
    if (error instanceof Error) {
      console.error('Error:', error.message);
    }
    process.exit(1);
  }
}

main().catch((error) => {
  console.error('❌ Unexpected error:', error);
  process.exit(1);
});
