# Rule: Change Management & Re-analysis Prevention

## Scope
Preventing repeated full-repository re-analysis on every user prompt.

## Rules
1. **Never Re-Analyze From Scratch**:
   - The repository architecture, files, domain rules, and models are already indexed in `.agent/rules/`, `AGENTS.md`, and `PROJECT_CONTEXT.md`.
   - When receiving a user request, inspect the exact targeted files directly using `grep_search` or `view_file` rather than crawling the entire directory tree.
2. **Atomic Targeted Changes**:
   - Keep code diffs focused strictly on the user's explicit request. Do not refactor unrelated classes or unmentioned components.
3. **Verify Before Declaring Complete**:
   - Run `flutter analyze` on modified files.
   - Send hot reload `'r'` or hot restart `'R'` to `task-548`.
   - Report concise, clear results with clickable links to modified files.
