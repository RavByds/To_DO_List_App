# StudyTask – Student To-Do List App

## Project Description

StudyTask is a student-focused TO-DO List application designed to make daily planning easier. It helps students organize their assignments, projects, activities, and deadlines so they can manage their time effectively and avoid forgetting important tasks.

The application provides a clean, modern, and user-friendly interface where students can create, edit, delete, and complete their tasks. It also allows users to monitor their progress and keep track of unfinished and completed activities.

## App Name

**StudyTask**

**Tagline:** Plan • Organize • Get Things Done

## Main Objective

Develop a fully functional Flutter TO-DO List application that helps students manage their academic responsibilities and daily activities.

IMPORTANT: Implement all the features below. Do not create just a UI design or static prototype. All buttons, navigation, forms, and task operations must work properly.

---

# 1. App Design and Theme

Create a modern and professional design.

### Design Requirements
- App name: StudyTask
- Primary color: Purple
- Secondary color: Dark Purple
- Background: White and light gray
- Text: Black and dark gray
- Buttons: Purple with rounded corners
- Cards: Rounded corners with subtle shadows
- Use clean icons and consistent spacing.
- Make the application responsive on different screen sizes.
- Use smooth transitions and animations where appropriate.

The overall design should look similar to a modern productivity and task management application.

# 2. Splash Screen

Create a custom splash screen that appears when the application starts.

### Requirements
- Display the StudyTask application logo.
- Display the app name "StudyTask".
- Display the tagline "Plan • Organize • Get Things Done".
- Use a purple gradient background.
- Add a simple loading animation.
- Automatically navigate to the Home Dashboard after loading.
- Make sure the splash screen displays properly when launching the installed application.

# 3. Custom App Icon

Create and configure a custom application icon.

### Icon Design
- Purple gradient background.
- White clipboard or checklist.
- Three purple or dark checkmarks.
- Small clock symbol.
- Modern and recognizable design.

### Requirements
- Generate or create a suitable app icon asset.
- Configure the icon for Android and iOS.
- Use the `flutter_launcher_icons` package.
- Ensure the icon appears on the device home screen after installation.

# 4. Home Dashboard

Create the main dashboard of StudyTask.

### Dashboard Elements
- Display the StudyTask app name.
- Display a welcome message.
- Display the current date.
- Show the total number of tasks.
- Show the number of pending tasks.
- Show the number of completed tasks.
- Show overdue tasks.
- Display a list of the user's tasks.
- Add a floating action button (+) for creating a new task.

### Task List Information
Each task should display:
- Task title.
- Due date.
- Completion status.
- Checkbox or completion button.
- Edit button.
- Delete button.

### Dashboard Behavior
- Automatically update task counts.
- Display newly added tasks immediately.
- Show unfinished tasks.
- Allow users to mark tasks as completed.
- Sort tasks by due date.
- Display an appropriate empty-state message when there are no tasks.

# 5. Add Task Feature

Create a fully functional Add Task screen.

### Input Fields
- Task Title (Required)
- Task Description (Optional)
- Due Date (Optional)
- Priority (Low, Medium, High)
- Category (Assignment, Project, Examination, Personal, Other)

### Requirements
- Validate the task title.
- Do not allow empty task titles.
- Provide a date picker for selecting deadlines.
- Provide a dropdown for priority.
- Provide a dropdown for category.
- Include an Add Task button.
- Display a success message after adding a task.
- Automatically return to the dashboard after saving.
- Save the new task locally.

# 6. Edit Task Feature

Allow users to edit existing tasks.

### Requirements
- Display the current task information.
- Allow users to change the title.
- Allow users to change the description.
- Allow users to update the due date.
- Allow users to change the priority.
- Allow users to change the category.
- Include a Save Changes button.
- Update the task immediately after saving.
- Preserve the task's completion status when editing.

# 7. Delete Task Feature

Allow users to delete tasks they no longer need.

### Requirements
- Add a delete button for every task.
- Display a confirmation dialog before deleting.
- Include Cancel and Delete options.
- Remove the selected task after confirmation.
- Update dashboard statistics automatically.

# 8. Mark Task as Completed

Allow users to mark unfinished tasks as completed.

### Requirements
- Add a checkbox beside each task.
- When checked, mark the task as completed.
- When unchecked, return the task to pending status.
- Completed tasks should have a visual difference, such as a checkmark and strikethrough text.
- Update the completed and pending task counts automatically.
- Save completion changes locally.

# 9. Completed Tasks Screen

Create a separate screen for completed tasks.

### Requirements
- Display all completed tasks.
- Show the task title and due date.
- Show a completed checkmark.
- Allow users to restore a completed task to pending status.
- Allow users to delete completed tasks.
- Display an empty-state message when there are no completed tasks.

# 10. Search and Filter Features

Add a search feature to help students find tasks quickly.

### Search Requirements
- Search tasks by title.
- Search tasks by description.
- Update search results while typing.
- Display a message when no matching tasks are found.

### Filter Requirements
Allow users to filter tasks by:
- All Tasks
- Pending Tasks
- Completed Tasks
- Overdue Tasks

Also provide category filters:
- Assignment
- Project
- Examination
- Personal
- Other

# 11. Task Priority

Implement a priority system.

### Priority Levels
- High – Red
- Medium – Orange
- Low – Green

Display a colored priority label on each task.

Allow users to change the priority when adding or editing tasks.

# 12. Due Date and Overdue Detection

Implement proper deadline tracking.

### Requirements
- Allow optional due dates.
- Display readable dates.
- Highlight overdue tasks.
- Automatically identify tasks whose deadlines have passed and that are not completed.
- Do not mark completed tasks as overdue.
- Display upcoming deadlines on the dashboard.

# 13. Profile Screen

Create a simple Profile screen.

### Display
- StudyTask logo.
- Application name.
- Total tasks created.
- Completed tasks.
- Pending tasks.
- Completion percentage.
- App version.

Add a settings section with:
- About StudyTask.
- Theme settings (Light and Dark mode).
- Clear All Tasks option with confirmation.
- App information.

# 14. Local Data Storage

The application must save tasks locally on the device.

### Requirements
- Use SQLite with the `sqflite` package or another suitable local database.
- Store all task information.
- Keep tasks even after closing and reopening the application.
- Update stored information whenever a task is added, edited, deleted, or completed.
- Load saved tasks when the application starts.
- Avoid duplicate task records when updating existing tasks.

### Task Data Structure

Each task should contain:

- id
- title
- description
- dueDate
- priority
- category
- isCompleted
- createdAt

Use a unique ID for every task.

# 15. Navigation

Create a bottom navigation bar with three main sections:

1. **Home** – Dashboard and pending tasks.
2. **Completed** – List of completed tasks.
3. **Profile** – User statistics and settings.

Make sure navigation works correctly and preserves task information.

# 16. Notifications and Reminders

If supported by the platform, implement local task reminders.

### Requirements
- Allow users to receive deadline reminders.
- Request notification permission when needed.
- Schedule reminders for tasks with due dates.
- Allow reminders to be updated or canceled when tasks are edited or deleted.

## Run the Flutter app

Install the Flutter SDK, then run these commands from the project directory:

```shell
flutter pub get
flutter run
```

Connect an Android device or emulator before running. iOS builds require macOS
and an available iOS simulator or device.

The app is configured for Android and iOS. Tasks and the selected theme are
stored in a local SQLite database on the device. Tasks with future due dates
receive a 9:00 AM local reminder when notification permission is granted;
completing or deleting a task cancels its reminder.