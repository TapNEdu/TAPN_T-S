import { query } from '@anthropic-ai/claude-agent-sdk';
import * as fs from 'fs';
import * as path from 'path';

export interface GenerateOptions {
  iosProjectDir: string;
  autoApply?: boolean;
}

export async function generateFromPrompt(
  userPrompt: string,
  options: GenerateOptions
): Promise<void> {
  console.log('🔍 Reading iOS project context...\n');

  // Read iOS Models.swift for context
  const modelsPath = path.join(options.iosProjectDir, 'TAPN_T+S/Models.swift');
  let modelsContent = '';
  if (fs.existsSync(modelsPath)) {
    modelsContent = fs.readFileSync(modelsPath, 'utf-8');
  } else {
    console.warn(`⚠️  Could not find Models.swift at ${modelsPath}`);
  }

  // Read existing SupabaseAPIClient if it exists
  const clientPath = path.join(options.iosProjectDir, 'TAPN_T+S/SupabaseAPIClient.swift');
  let clientContent = '';
  if (fs.existsSync(clientPath)) {
    clientContent = fs.readFileSync(clientPath, 'utf-8');
  }

  // Read TAPNAPI protocol definition
  const apiPath = path.join(options.iosProjectDir, 'TAPN_T+S/TAPNAPI.swift');
  let apiContent = '';
  if (fs.existsSync(apiPath)) {
    apiContent = fs.readFileSync(apiPath, 'utf-8');
  }

  const systemContext = `
You are an expert Supabase backend generator for an iOS classroom attendance tracking app.

## Technology Stack
- iOS: Swift + SwiftUI
- Database: Supabase (PostgreSQL)
- SDK: supabase-swift (v2.0+)
- Tables: class_sessions, students
- Real-time: Enabled via Supabase Realtime

## Current iOS Data Models
${modelsContent}

${apiContent ? `## TAPNAPI Protocol\n${apiContent}` : ''}

${clientContent ? `## Current SupabaseAPIClient Implementation\n${clientContent}` : ''}

## Your Capabilities
1. Generate SQL migrations for Supabase (save to supabase-migrations/ directory)
2. Create/update Row Level Security (RLS) policies
3. Generate or modify Swift code for SupabaseAPIClient implementing TAPNAPI protocol
4. Update database schema to match iOS models
5. Write real-time subscription code for AppState
6. Fix bugs and improve existing implementations

## Supabase Swift SDK Patterns

### Query with relations:
\`\`\`swift
let result: [ClassSessionDTO] = try await supabase
  .from("class_sessions")
  .select("*, students(*)")
  .execute()
  .value
\`\`\`

### Insert with return:
\`\`\`swift
let result: ClassSessionDTO = try await supabase
  .from("table")
  .insert(data)
  .select("*, students(*)")
  .single()
  .execute()
  .value
\`\`\`

### Update with filter:
\`\`\`swift
let result: ClassSessionDTO = try await supabase
  .from("table")
  .update(["field": value])
  .eq("id", value: id.uuidString)
  .select("*, students(*)")
  .single()
  .execute()
  .value
\`\`\`

### JSONB updates (for settings field):
\`\`\`swift
// For nested JSONB updates, fetch current, modify, then update entire object
let current: ClassSessionDTO = try await supabase
  .from("class_sessions")
  .select("settings")
  .eq("id", value: classID.uuidString)
  .single()
  .execute()
  .value

var updated = current.settings
updated.durationMinutes = newValue

try await supabase
  .from("class_sessions")
  .update(["settings": updated])
  .eq("id", value: classID.uuidString)
  .execute()
\`\`\`

### Date formatting:
\`\`\`swift
// Use ISO8601DateFormatter for timestamps
ISO8601DateFormatter().string(from: Date())
\`\`\`

### NULL values:
\`\`\`swift
// Use NSNull() to set fields to NULL
.update(["end_time": NSNull()])
\`\`\`

## Important Notes
- Always use snake_case for database field names (e.g., "time_label", "start_time")
- Always fetch related data with .select("*, students(*)") to match TAPNAPI expectations
- Use UUIDs as strings when querying: \`id.uuidString\`
- Return full ClassSession objects from all methods (match TAPNAPI protocol)
- Handle existing vs new records appropriately (check before insert)

Generate production-ready, type-safe code following these patterns.
  `;

  console.log('🤖 Claude Agent SDK is generating code...\n');
  console.log(`📝 User prompt: "${userPrompt}"\n`);
  console.log('─'.repeat(60));
  console.log();

  try {
    for await (const message of query({
      prompt: `${systemContext}\n\n## User Request\n${userPrompt}`,
      options: {
        cwd: options.iosProjectDir,
        allowedTools: ['Read', 'Write', 'Edit', 'Bash', 'Glob', 'Grep'],
        permissionMode: options.autoApply ? 'acceptEdits' : 'prompt',
        includePartialMessages: true
      }
    })) {
      if (message.type === 'assistant' && message.message?.content) {
        const content = Array.isArray(message.message.content)
          ? message.message.content.map(c => c.type === 'text' ? c.text : '').join('')
          : message.message.content;

        if (content) {
          console.log(content);
        }
      }
    }

    console.log();
    console.log('─'.repeat(60));
    console.log('✅ Code generation complete!\n');
  } catch (error) {
    console.error('\n❌ Error during code generation:', error);
    throw error;
  }
}