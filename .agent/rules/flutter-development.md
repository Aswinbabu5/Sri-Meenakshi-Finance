# Rule: Flutter Development Guidelines

## Scope
Widget construction, state reactivity, responsiveness, and hot reload verification.

## Rules
1. **Responsive & Adaptive UI**:
   - The UI must render seamlessly on mobile phones (360px+), tablets, and widescreen desktop browsers (`width >= 860px`).
   - Use `LayoutBuilder` or flexible columns for action grids and tables.
2. **Proactive Hot Reload Rule**:
   - When modifying any file under `mobile_loan_app/lib/`:
     - Run `flutter analyze` immediately to confirm zero lint errors/syntax bugs.
     - Send `'r'` (hot reload) or `'R'` (hot restart) to active runner task `task-548`.
3. **Typography & Aesthetics**:
   - Modern clean cards, subtle elevation (2-4dp), clear border contrasts, and semantic status colors (`AppColors.primary`, `AppColors.success`, `AppColors.error`).
4. **State Management**:
   - `LoanRepository` is the central reactive state source extending `ChangeNotifier`.
   - Call `notifyListeners()` when modifying repository lists so subscribers automatically rebuild.
