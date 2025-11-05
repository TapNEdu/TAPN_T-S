# Commit Message Conventions

This document outlines the commit message standards for this project.

## Format

```
<type>: <subject>

<body>

<footer>
```

## Rules

### Required
- **No emojis** in commit messages
- **No AI attribution** (e.g., "Generated with Claude Code", "Co-Authored-By: Claude")
- Use conventional commit types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- Subject line should be concise and descriptive
- Use imperative mood ("Add feature" not "Added feature")

### Optional
- Body can include bullet points for detailed changes
- Body should explain the "why" not just the "what"
- Footer can include issue references, breaking changes, etc.

## Examples

### Good
```
feat: Add RealtimeManager for Supabase real-time subscriptions

Implements centralized real-time data synchronization to replace polling-based updates. This resolves sync issues where status changes (tap-in/out, class start/end) only appeared after sign-out/sign-in.

- Create RealtimeManager singleton for managing Supabase Realtime channels
- Subscribe to class_sessions, students, and class_rosters tables
- Implement debouncing (300ms) to prevent excessive refresh calls
```

### Bad
```
feat: Add cool new feature 🎉

Added some changes.

Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

## Commit Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, dependency updates
