import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'deadline_notifications.dart';

const _purple = Color(0xFF7048C8);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudyTaskApp());
}

class StudyTaskApp extends StatefulWidget {
  const StudyTaskApp({super.key});

  @override
  State<StudyTaskApp> createState() => _StudyTaskAppState();
}

class _StudyTaskAppState extends State<StudyTaskApp> {
  late final Future<_Bootstrap> _bootstrap = _load();
  bool? _isDark;

  Future<_Bootstrap> _load() async {
    final database = await TaskDatabase.open();
    await DeadlineNotifications.initialize();
    return _Bootstrap(
      database,
      await database.getTasks(),
      await database.getDarkMode(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Bootstrap>(
      future: _bootstrap,
      builder: (context, snapshot) {
        final bootstrap = snapshot.data;
        return MaterialApp(
          title: 'StudyTask',
          debugShowCheckedModeBanner: false,
          themeMode: (_isDark ?? bootstrap?.isDark) == true
              ? ThemeMode.dark
              : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: _purple),
            scaffoldBackgroundColor: const Color(0xFFF8F7FB),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFEAE7F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _purple, width: 1.5),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: _purple,
              brightness: Brightness.dark,
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          home: snapshot.hasError
              ? _StartupError(error: snapshot.error)
              : bootstrap == null
              ? const _LoadingScreen()
              : _AppShell(
                  bootstrap: bootstrap,
                  onThemeChanged: (value) => setState(() => _isDark = value),
                ),
        );
      },
    );
  }
}

class _Bootstrap {
  const _Bootstrap(this.database, this.tasks, this.isDark);

  final TaskDatabase database;
  final List<Task> tasks;
  final bool isDark;
}

class Task {
  const Task({
    this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.category,
    required this.isCompleted,
    required this.createdAt,
  });

  final int? id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final String priority;
  final String category;
  final bool isCompleted;
  final DateTime createdAt;

  bool isOverdue(DateTime now) =>
      !isCompleted &&
      dueDate != null &&
      DateUtils.dateOnly(dueDate!).isBefore(DateUtils.dateOnly(now));

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'dueDate': dueDate?.toIso8601String(),
    'priority': priority,
    'category': category,
    'isCompleted': isCompleted ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Task.fromMap(Map<String, Object?> map) => Task(
    id: map['id'] as int,
    title: map['title'] as String,
    description: map['description'] as String,
    dueDate: map['dueDate'] == null
        ? null
        : DateTime.parse(map['dueDate'] as String),
    priority: map['priority'] as String,
    category: map['category'] as String,
    isCompleted: (map['isCompleted'] as int) == 1,
    createdAt: DateTime.parse(map['createdAt'] as String),
  );
}

class TaskDatabase {
  TaskDatabase._(this._database);

  final Database _database;

  static Future<TaskDatabase> open() async {
    final path = p.join(await getDatabasesPath(), 'study_task.db');
    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            dueDate TEXT,
            priority TEXT NOT NULL,
            category TEXT NOT NULL,
            isCompleted INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
    return TaskDatabase._(database);
  }

  Future<List<Task>> getTasks() async {
    final rows = await _database.query('tasks');
    final tasks = rows.map(Task.fromMap).toList();
    tasks.sort((a, b) {
      if (a.dueDate == null && b.dueDate != null) return 1;
      if (a.dueDate != null && b.dueDate == null) return -1;
      final dateOrder = a.dueDate?.compareTo(b.dueDate!) ?? 0;
      return dateOrder != 0 ? dateOrder : b.createdAt.compareTo(a.createdAt);
    });
    return tasks;
  }

  Future<Task> saveTask(Task task) async {
    final values = task.toMap()..remove('id');
    if (task.id == null) {
      final id = await _database.insert('tasks', values);
      return Task(
        id: id,
        title: task.title,
        description: task.description,
        dueDate: task.dueDate,
        priority: task.priority,
        category: task.category,
        isCompleted: task.isCompleted,
        createdAt: task.createdAt,
      );
    } else {
      await _database.update(
        'tasks',
        values,
        where: 'id = ?',
        whereArgs: [task.id],
      );
      return task;
    }
  }

  Future<void> setCompleted(Task task, bool completed) async {
    await _database.update(
      'tasks',
      {'isCompleted': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> deleteTask(Task task) async {
    await _database.delete('tasks', where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> clearTasks() async => _database.delete('tasks');

  Future<bool> getDarkMode() async {
    final rows = await _database.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['darkMode'],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['value'] == 'true';
  }

  Future<void> setDarkMode(bool value) async {
    await _database.insert('settings', {
      'key': 'darkMode',
      'value': value.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell({required this.bootstrap, required this.onThemeChanged});

  final _Bootstrap bootstrap;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  late List<Task> _tasks = widget.bootstrap.tasks;
  late bool _isDark = widget.bootstrap.isDark;
  int _selectedPage = 0;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  Future<void> _refresh() async {
    final tasks = await widget.bootstrap.database.getTasks();
    if (mounted) setState(() => _tasks = tasks);
  }

  Future<void> _editTask([Task? task]) async {
    final result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => TaskEditorSheet(task: task),
    );
    if (result == null) return;
    final savedTask = await widget.bootstrap.database.saveTask(result);
    await _refresh();
    final reminderCreated = await DeadlineNotifications.syncTask(
      id: savedTask.id!,
      title: savedTask.title,
      dueDate: savedTask.dueDate,
      isCompleted: savedTask.isCompleted,
    );
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          reminderCreated
              ? task == null
                    ? 'Task added'
                    : 'Changes saved'
              : 'Task saved, but notification permission is disabled.',
        ),
      ),
    );
  }

  Future<void> _toggleTask(Task task, bool completed) async {
    await widget.bootstrap.database.setCompleted(task, completed);
    await _refresh();
    if (completed) {
      await DeadlineNotifications.cancel(task.id!);
    } else {
      final reminderCreated = await DeadlineNotifications.syncTask(
        id: task.id!,
        title: task.title,
        dueDate: task.dueDate,
        isCompleted: false,
      );
      if (!reminderCreated) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              'Task restored, but notification permission is disabled.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('“${task.title}” will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.bootstrap.database.deleteTask(task);
    await _refresh();
    await DeadlineNotifications.cancel(task.id!);
    _messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Task deleted')),
    );
  }

  Future<void> _setDarkMode(bool value) async {
    await widget.bootstrap.database.setDarkMode(value);
    if (mounted) {
      setState(() => _isDark = value);
      widget.onThemeChanged(value);
    }
  }

  Future<void> _clearTasks() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all tasks?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.bootstrap.database.clearTasks();
    await _refresh();
    await DeadlineNotifications.cancelAll();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(
        tasks: _tasks,
        onToggle: _toggleTask,
        onEdit: _editTask,
        onDelete: _deleteTask,
      ),
      _CompletedPage(
        tasks: _tasks.where((task) => task.isCompleted).toList(),
        onToggle: _toggleTask,
        onDelete: _deleteTask,
      ),
      _ProfilePage(
        tasks: _tasks,
        isDark: _isDark,
        onThemeChanged: _setDarkMode,
        onClearTasks: _clearTasks,
      ),
    ];

    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        body: IndexedStack(index: _selectedPage, children: pages),
        floatingActionButton: _selectedPage == 0
            ? FloatingActionButton.extended(
                onPressed: () => _editTask(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New task'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedPage,
          onDestinationSelected: (index) =>
              setState(() => _selectedPage = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.task_alt_outlined),
              selectedIcon: Icon(Icons.task_alt_rounded),
              label: 'Completed',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage({
    required this.tasks,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Task> tasks;
  final Future<void> Function(Task task, bool completed) onToggle;
  final Future<void> Function([Task? task]) onEdit;
  final Future<void> Function(Task task) onDelete;

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final _searchController = TextEditingController();
  String _statusFilter = 'Pending';
  String _categoryFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Task> get _visibleTasks {
    final now = DateTime.now();
    final query = _searchController.text.trim().toLowerCase();
    return widget.tasks.where((task) {
      final matchesSearch =
          query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query);
      final matchesCategory =
          _categoryFilter == 'All' || task.category == _categoryFilter;
      final matchesStatus = switch (_statusFilter) {
        'Pending' => !task.isCompleted,
        'Completed' => task.isCompleted,
        'Overdue' => task.isOverdue(now),
        _ => true,
      };
      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final pending = widget.tasks.where((task) => !task.isCompleted).length;
    final completed = widget.tasks.where((task) => task.isCompleted).length;
    final overdue = widget.tasks.where((task) => task.isOverdue(now)).length;
    final visibleTasks = _visibleTasks;

    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d').format(now),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Your day, organized.',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 25,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.checklist_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 640 ? 4 : 2;
              final gap = 12.0;
              final cardWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  _StatCard(
                    width: cardWidth,
                    label: 'Total tasks',
                    value: '${widget.tasks.length}',
                    icon: Icons.checklist_rounded,
                    color: _purple,
                  ),
                  _StatCard(
                    width: cardWidth,
                    label: 'Pending',
                    value: '$pending',
                    icon: Icons.pending_actions_rounded,
                    color: const Color(0xFFE29A29),
                  ),
                  _StatCard(
                    width: cardWidth,
                    label: 'Completed',
                    value: '$completed',
                    icon: Icons.task_alt_rounded,
                    color: const Color(0xFF3A9D78),
                  ),
                  _StatCard(
                    width: cardWidth,
                    label: 'Overdue',
                    value: '$overdue',
                    icon: Icons.alarm_rounded,
                    color: const Color(0xFFD95B65),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search tasks',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          _ChoiceRow(
            options: const ['All', 'Pending', 'Completed', 'Overdue'],
            selected: _statusFilter,
            onSelected: (value) => setState(() => _statusFilter = value),
          ),
          const SizedBox(height: 12),
          _ChoiceRow(
            options: const [
              'All',
              'Assignment',
              'Project',
              'Examination',
              'Personal',
              'Other',
            ],
            selected: _categoryFilter,
            onSelected: (value) => setState(() => _categoryFilter = value),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your tasks',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${visibleTasks.length} ${visibleTasks.length == 1 ? 'task' : 'tasks'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (visibleTasks.isEmpty)
            _EmptyState(
              icon: widget.tasks.isEmpty
                  ? Icons.auto_awesome_rounded
                  : Icons.search_off_rounded,
              title: widget.tasks.isEmpty ? 'A fresh start' : 'No tasks found',
              message: widget.tasks.isEmpty
                  ? 'Add your first task and make today count.'
                  : 'Try another search or change your filters.',
            )
          else
            ...visibleTasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TaskCard(
                  task: task,
                  onToggle: (value) => widget.onToggle(task, value),
                  onEdit: () => widget.onEdit(task),
                  onDelete: () => widget.onDelete(task),
                ),
              ),
            ),
          const SizedBox(height: 72),
        ],
      ),
    );
  }
}

class _CompletedPage extends StatelessWidget {
  const _CompletedPage({
    required this.tasks,
    required this.onToggle,
    required this.onDelete,
  });

  final List<Task> tasks;
  final Future<void> Function(Task task, bool completed) onToggle;
  final Future<void> Function(Task task) onDelete;

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completed',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'A little progress adds up. Look what you’ve finished.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (tasks.isEmpty)
            const _EmptyState(
              icon: Icons.celebration_rounded,
              title: 'Nothing completed yet',
              message: 'Finished tasks will show up here.',
            )
          else
            ...tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TaskCard(
                  task: task,
                  onToggle: (value) => onToggle(task, value),
                  onDelete: () => onDelete(task),
                  showEdit: false,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.tasks,
    required this.isDark,
    required this.onThemeChanged,
    required this.onClearTasks,
  });

  final List<Task> tasks;
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  final Future<void> Function() onClearTasks;

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((task) => task.isCompleted).length;
    final pending = tasks.length - completed;
    final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;

    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your profile',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    child: Icon(
                      Icons.school_rounded,
                      size: 30,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'StudyTask',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Plan • Organize • Get Things Done',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your progress',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileMetric(
                          label: 'Created',
                          value: '${tasks.length}',
                        ),
                      ),
                      Expanded(
                        child: _ProfileMetric(
                          label: 'Completed',
                          value: '$completed',
                        ),
                      ),
                      Expanded(
                        child: _ProfileMetric(
                          label: 'Pending',
                          value: '$pending',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${(progress * 100).round()}% complete'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Settings',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark theme'),
                  subtitle: const Text('Choose a comfortable appearance'),
                  value: isDark,
                  onChanged: onThemeChanged,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About StudyTask'),
                  subtitle: const Text('Version 1.0.0'),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'StudyTask',
                    applicationVersion: '1.0.0',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_sweep_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Clear all tasks',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: onClearTasks,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onToggle,
    required this.onDelete,
    this.onEdit,
    this.showEdit = true,
  });

  final Task task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final bool showEdit;

  Color _priorityColor(BuildContext context) => switch (task.priority) {
    'High' => const Color(0xFFD95B65),
    'Medium' => const Color(0xFFE29A29),
    _ => const Color(0xFF3A9D78),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = task.isOverdue(DateTime.now());
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: task.isCompleted,
              onChanged: (value) => onToggle(value ?? false),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted ? muted : null,
                      ),
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Tag(
                          label: task.priority,
                          color: _priorityColor(context),
                        ),
                        _Tag(
                          label: task.category,
                          color: theme.colorScheme.primary,
                        ),
                        if (task.dueDate != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: overdue
                                    ? theme.colorScheme.error
                                    : muted,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                DateFormat('MMM d').format(task.dueDate!),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: overdue
                                      ? theme.colorScheme.error
                                      : muted,
                                  fontWeight: overdue ? FontWeight.w700 : null,
                                ),
                              ),
                            ],
                          ),
                        if (overdue)
                          Text(
                            'Overdue',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Task options',
              onSelected: (action) {
                if (action == 'edit') onEdit?.call();
                if (action == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                if (showEdit)
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Delete'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.more_vert_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({super.key, this.task});

  final Task? task;

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _priority;
  late String _category;
  DateTime? _dueDate;

  static const _priorities = ['Low', 'Medium', 'High'];
  static const _categories = [
    'Assignment',
    'Project',
    'Examination',
    'Personal',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _priority = task?.priority ?? 'Medium';
    _category = task?.category ?? 'Assignment';
    _dueDate = task?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (selected != null) setState(() => _dueDate = selected);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.task;
    Navigator.pop(
      context,
      Task(
        id: existing?.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
        category: _category,
        isCompleted: existing?.isCompleted ?? false,
        createdAt: existing?.createdAt ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.task != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      editing ? 'Edit task' : 'Create a task',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Task title',
                  hintText: 'e.g. Finish biology assignment',
                  counterText: '',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter a task title'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: _priorities
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _priority = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _category = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(
                  _dueDate == null
                      ? 'Choose due date'
                      : DateFormat('EEEE, MMM d, y').format(_dueDate!),
                ),
              ),
              if (_dueDate != null)
                TextButton(
                  onPressed: () => setState(() => _dueDate = null),
                  child: const Text('Remove due date'),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(editing ? 'Save changes' : 'Add task'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options
            .map(
              (option) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(option),
                  selected: selected == option,
                  onSelected: (_) => onSelected(option),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
        child: Column(
          children: [
            Icon(icon, size: 46, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8F68E8), Color(0xFF4F2E9C)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.checklist_rounded,
                color: _purple,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'StudyTask',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Plan • Organize • Get Things Done',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 30),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(
              'StudyTask could not finish starting.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
