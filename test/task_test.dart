import 'package:flutter_test/flutter_test.dart';
import 'package:study_task/main.dart';

void main() {
  group('Task', () {
    test('round-trips all task fields through the database map', () {
      final task = Task(
        id: 7,
        title: 'Read chapter 4',
        description: 'Take notes',
        dueDate: DateTime(2026, 11, 20),
        priority: 'High',
        category: 'Assignment',
        isCompleted: true,
        createdAt: DateTime(2026, 11, 10, 9),
      );

      expect(Task.fromMap(task.toMap()).toMap(), task.toMap());
    });

    test('is overdue only when an unfinished due date is before today', () {
      final now = DateTime(2026, 11, 16, 15);
      Task makeTask(DateTime dueDate, {bool completed = false}) => Task(
        id: 1,
        title: 'Task',
        description: '',
        dueDate: dueDate,
        priority: 'Medium',
        category: 'Other',
        isCompleted: completed,
        createdAt: now,
      );

      expect(makeTask(DateTime(2026, 11, 15)).isOverdue(now), isTrue);
      expect(makeTask(DateTime(2026, 11, 16)).isOverdue(now), isFalse);
      expect(
        makeTask(DateTime(2026, 11, 15), completed: true).isOverdue(now),
        isFalse,
      );
    });
  });
}
