# Rule: Debugging & Troubleshooting

## Scope
Strategies for diagnosing Flutter build issues, Dart analyzer errors, and hot reload problems.

## Rules
1. **Always Check Active Running Tasks**:
   - Before executing arbitrary restart scripts, check background tasks using `manage_task(action='status')`.
   - Send `'r'` (hot reload) or `'R'` (hot restart) directly to the running Flutter daemon process.
2. **Static Analysis Pre-Flight**:
   - Always run `flutter analyze <path>` on modified files prior to notifying user or hot reloading.
3. **Common Pitfalls & Resolutions**:
   - `File(...)` in Flutter Web: `dart:io` `File` is NOT supported on web! Use `kIsWeb` conditional checks or `Image.network` / fallback avatars.
   - `sqflite` Missing Plugin on Web: Always ensure `sqflite_common_ffi_web` is registered in `main.dart`.
   - `SingleTickerProviderStateMixin` vs `TabController`: If removing tabs, remove the ticker mixin to avoid memory leaks.
