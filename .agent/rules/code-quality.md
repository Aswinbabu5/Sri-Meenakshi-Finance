# Rule: Code Quality & Consistency

## Scope
Coding standards, linting, error handling, and formatting rules across Dart and C#.

## Rules
1. **Dart / Flutter Standards**:
   - Always run `flutter analyze` on modified files; zero warnings or errors allowed.
   - Adhere to `package:flutter_lints` standards. Avoid using deprecated APIs or raw print statements; use `debugPrint` or proper loggers.
   - Maintain `const` constructors wherever widget subtree does not depend on dynamic runtime variables.
2. **C# / .NET Standards**:
   - PascalCase for public methods, classes, and properties; camelCase for parameters and private members.
   - Use async/await throughout all I/O, EF Core database operations, and external calls.
   - Ensure nullability checks (`Nullable<T>` or `?`) are explicitly handled.
3. **Preserve Comments & Docstrings**:
   - Maintain documentation integrity. Never strip existing functional explanations, Tamil translations, or developer notes.
4. **Defensive Error Handling**:
   - Wrap user inputs, JSON parsing, file accesses, and database transactions in guarded `try-catch` blocks with intuitive user error messages.
