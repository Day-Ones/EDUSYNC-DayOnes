# Implementation Plan: Schedule Conflict Detection

## Overview

This implementation adds automatic schedule conflict detection for faculty members when creating or editing classes. The implementation creates a new `ScheduleConflictService` and integrates conflict checking into the existing `AddEditClassScreen`.

## Tasks

- [x] 1. Create ScheduleConflictService
  - [x] 1.1 Create `lib/services/schedule_conflict_service.dart` with static utility methods
    - Implement `timesOverlap()` method to check if two time ranges overlap
    - Implement `daysOverlap()` method to check if two day lists share common days
    - Implement `findConflicts()` method to find all conflicting classes
    - Implement `formatConflictMessage()` method to format conflict info for display
    - _Requirements: 4.1, 4.2, 4.4_

  - [x] 1.2 Write property test for conflict detection accuracy
    - **Property 6: Conflict Detection Accuracy**
    - **Property 7: Adjacent Times Non-Conflicting**
    - **Property 8: Same Day Non-Overlapping Times Non-Conflicting**
    - **Validates: Requirements 4.1, 4.2, 4.4**

- [x] 2. Integrate conflict detection into AddEditClassScreen
  - [x] 2.1 Add conflict state variables to `_AddEditClassScreenState`
    - Add `_conflictingClasses` list to track detected conflicts
    - Add `_hasScheduleConflict` boolean for quick conflict check
    - _Requirements: 2.1, 3.1_

  - [x] 2.2 Implement `_checkScheduleConflicts()` method
    - Get faculty classes from ClassProvider
    - Call ScheduleConflictService.findConflicts()
    - Exclude current class when editing
    - Update conflict state
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 4.3_

  - [x] 2.3 Trigger conflict check on schedule changes
    - Call `_checkScheduleConflicts()` in `_pickTime()` after time selection
    - Call `_checkScheduleConflicts()` when days are selected/deselected
    - Call `_checkScheduleConflicts()` in `didChangeDependencies()` for edit mode
    - _Requirements: 1.1, 1.2, 1.3_

  - [x] 2.4 Write property test for self-exclusion when editing
    - **Property 2: Self-Exclusion When Editing**
    - **Validates: Requirements 1.4**

- [x] 3. Implement conflict warning UI
  - [x] 3.1 Create conflict warning banner widget
    - Display warning icon and "Schedule Conflict" header
    - List conflicting class names with their times
    - Show overlapping days
    - Style with warning colors (orange/amber)
    - _Requirements: 2.1, 2.2, 2.4_

  - [x] 3.2 Add warning banner to AddEditClassScreen build method
    - Show banner below the existing time conflict warning
    - Only display when `_hasScheduleConflict` is true
    - _Requirements: 2.1, 2.3_

  - [x] 3.3 Write property test for warning content completeness
    - **Property 3: Warning Content Completeness**
    - **Validates: Requirements 2.1, 2.2, 2.4**

- [x] 4. Implement save prevention
  - [x] 4.1 Update save button state based on conflicts
    - Disable Save/Update button when `_hasScheduleConflict` is true
    - Update `_buildSaveButtons()` method to check conflict state
    - _Requirements: 3.1, 3.3_

  - [x] 4.2 Update `_saveClass()` to check for conflicts
    - Add conflict check at the start of `_saveClass()`
    - Show error snackbar if conflicts exist and save is attempted
    - _Requirements: 3.2_

  - [x] 4.3 Write property test for save button state
    - **Property 5: Save Button State Follows Conflict State**
    - **Validates: Requirements 3.1, 3.3, 3.4**

- [x] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement student conflict warning (optional)
  - [x] 6.1 Add conflict check to join class flow
    - Check for conflicts when student enters invite code
    - Compare new class schedule with enrolled classes
    - _Requirements: 5.1_

  - [x] 6.2 Show warning dialog for student conflicts
    - Display warning with conflicting class names
    - Allow student to proceed with join despite conflicts
    - _Requirements: 5.2, 5.3_

  - [x] 6.3 Write property test for student conflict warning
    - **Property 10: Student Conflict Warning Allows Join**
    - **Validates: Requirements 5.1, 5.2, 5.3**

- [x] 7. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- All tasks are required for comprehensive implementation
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- The existing `ClassModel.conflictsWith()` method can be leveraged but the service provides more flexibility for checking before a ClassModel is created
