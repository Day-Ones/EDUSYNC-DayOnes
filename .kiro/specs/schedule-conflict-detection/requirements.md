# Requirements Document

## Introduction

This feature implements automatic schedule conflict detection for faculty members when creating or editing classes in EduSync. The system will check for time overlaps between the new/edited class schedule and existing classes owned by the faculty, providing immediate feedback when conflicts are detected. This prevents faculty from accidentally double-booking their schedule.

## Glossary

- **Faculty**: A user with the faculty role who creates and manages classes
- **Schedule_Conflict**: A situation where two classes have overlapping time slots on the same day(s)
- **Time_Slot**: A combination of start time, end time, and days of the week
- **Conflict_Detector**: The service responsible for checking schedule conflicts
- **Add_Edit_Class_Screen**: The screen where faculty creates new classes or edits existing ones
- **ClassProvider**: The provider that manages class data and provides access to all faculty classes

## Requirements

### Requirement 1: Real-time Conflict Detection on Time Selection

**User Story:** As a faculty member, I want to be immediately notified when I select a time that conflicts with my existing classes, so that I can adjust the schedule before proceeding.

#### Acceptance Criteria

1. WHEN a faculty member selects a start time in the Add_Edit_Class_Screen, THE Conflict_Detector SHALL check for conflicts with all existing classes owned by that faculty
2. WHEN a faculty member selects an end time in the Add_Edit_Class_Screen, THE Conflict_Detector SHALL check for conflicts with all existing classes owned by that faculty
3. WHEN a faculty member selects or deselects a day of the week, THE Conflict_Detector SHALL re-check for conflicts with the updated schedule
4. WHEN editing an existing class, THE Conflict_Detector SHALL exclude the class being edited from conflict checks

### Requirement 2: Conflict Warning Display

**User Story:** As a faculty member, I want to see clear information about schedule conflicts, so that I understand which classes are affected and can make informed decisions.

#### Acceptance Criteria

1. WHEN a Schedule_Conflict is detected, THE Add_Edit_Class_Screen SHALL display a warning banner showing the conflicting class name and time
2. WHEN multiple Schedule_Conflicts are detected, THE Add_Edit_Class_Screen SHALL display all conflicting classes in the warning
3. WHEN no Schedule_Conflict exists, THE Add_Edit_Class_Screen SHALL not display any conflict warning
4. THE warning banner SHALL include the conflicting class name, the overlapping day(s), and the time range

### Requirement 3: Save Prevention on Conflict

**User Story:** As a faculty member, I want to be prevented from saving a class with schedule conflicts, so that I don't accidentally create overlapping schedules.

#### Acceptance Criteria

1. WHEN a Schedule_Conflict exists, THE Add_Edit_Class_Screen SHALL disable the Save/Update button
2. WHEN a Schedule_Conflict exists and the faculty attempts to save, THE System SHALL display an error message explaining the conflict
3. WHEN all Schedule_Conflicts are resolved, THE Add_Edit_Class_Screen SHALL enable the Save/Update button
4. IF the faculty resolves conflicts by changing time or days, THEN THE System SHALL immediately re-enable the Save/Update button

### Requirement 4: Conflict Detection Logic

**User Story:** As a system, I need to accurately detect time overlaps between classes, so that faculty schedules remain conflict-free.

#### Acceptance Criteria

1. THE Conflict_Detector SHALL identify a conflict when two classes share at least one common day AND their time ranges overlap
2. THE Conflict_Detector SHALL consider time ranges as overlapping when: (startA < endB) AND (endA > startB)
3. THE Conflict_Detector SHALL only check classes owned by the current faculty user
4. THE Conflict_Detector SHALL handle edge cases where class times are exactly adjacent (e.g., 9:00-10:00 and 10:00-11:00) as non-conflicting

### Requirement 5: Student Schedule Conflict Detection (Optional)

**User Story:** As a student, I want to be warned when joining a class that conflicts with my existing enrolled classes, so that I can manage my schedule effectively.

#### Acceptance Criteria

1. WHEN a student attempts to join a class via invite code, THE System SHALL check for conflicts with their enrolled classes
2. IF a Schedule_Conflict is detected for a student, THEN THE System SHALL display a warning but still allow joining
3. THE warning SHALL show which enrolled class(es) conflict with the new class
