// lib/logic.dart
import 'models.dart';

// ── Calendar ──────────────────────────────────────────────────────────────────

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class CalendarInfo {
  final String key;
  final String label;
  final String fullLabel;
  const CalendarInfo(
      {required this.key, required this.label, required this.fullLabel});
}

CalendarInfo getCalendarInfo([DateTime? date]) {
  final d = (date ?? DateTime.now()).toLocal();
  final day = d.day;
  final month = _monthNames[d.month - 1];
  final weekday = _weekdayNames[d.weekday - 1];
  final year = d.year;
  final m = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');

  return CalendarInfo(
    key: '$year-$m-$dd',
    label: '$day $month',
    fullLabel: '$weekday, $day $month $year',
  );
}

// ── State builders ────────────────────────────────────────────────────────────

AppState createInitialState() {
  final cal = getCalendarInfo();
  return AppState(
    isDark: false,
    repeatDays: 0,
    cycleStartKey: cal.key,
    currentDayKey: cal.key,
    currentDayLabel: cal.label,
    currentDayFullLabel: cal.fullLabel,
    dayIndex: 0,
    templates: const [],
    currentTasks: const [],
    history: const [],
    lastSyncedAt: DateTime.now().toIso8601String(),
  );
}

List<Task> _sortByPriority(List<Task> tasks) {
  final sorted = [...tasks];
  sorted.sort((a, b) {
    final byWeight = b.priorityWeight.compareTo(a.priorityWeight);
    if (byWeight != 0) return byWeight;
    return a.createdAt.compareTo(b.createdAt);
  });
  return sorted;
}

List<Task> buildTasksFromTemplates(List<Task> templates) => _sortByPriority(
      templates.map((t) => t.copyWith(id: uid(), done: false)).toList(),
    );

AppState archiveCurrentDay(AppState state) {
  if (state.currentTasks.isEmpty && state.templates.isEmpty) return state;
  final cal = getCalendarInfo();
  final stats = calculateProgress(state.currentTasks);
  final record = DayRecord(
    dayKey: state.currentDayKey,
    dayLabel:
        state.currentDayLabel.isNotEmpty ? state.currentDayLabel : cal.label,
    fullLabel: state.currentDayFullLabel.isNotEmpty
        ? state.currentDayFullLabel
        : cal.fullLabel,
    progress: stats.progress,
    totalWeight: stats.totalWeight,
    completedWeight: stats.completedWeight,
    taskCount: state.currentTasks.length,
    completedTaskCount: state.currentTasks.where((t) => t.done).length,
    archivedAt: DateTime.now().toIso8601String(),
    tasks: List.unmodifiable(state.currentTasks),
  );
  return state.copyWith(history: [...state.history, record]);
}

AppState advanceToToday(AppState state, [DateTime? now]) {
  final today = getCalendarInfo(now);

  if (state.currentDayKey == today.key) {
    // Same day – rehydrate if needed
    if (state.currentTasks.isEmpty &&
        state.templates.isNotEmpty &&
        state.dayIndex <= state.repeatDays) {
      return state.copyWith(
        currentTasks: buildTasksFromTemplates(state.templates),
        currentDayLabel: today.label,
        currentDayFullLabel: today.fullLabel,
      );
    }
    return state.copyWith(
      currentDayLabel: today.label,
      currentDayFullLabel: today.fullLabel,
    );
  }

  // New day
  final archived = archiveCurrentDay(state);
  final nextIndex = archived.dayIndex + 1;
  final fresh = nextIndex <= archived.repeatDays
      ? buildTasksFromTemplates(archived.templates)
      : <Task>[];

  return archived.copyWith(
    currentDayKey: today.key,
    currentDayLabel: today.label,
    currentDayFullLabel: today.fullLabel,
    dayIndex: nextIndex,
    currentTasks: fresh,
    lastSyncedAt: DateTime.now().toIso8601String(),
  );
}

// ── Task mutations ────────────────────────────────────────────────────────────

AppState addTask(AppState state, String text, String priorityLabel) {
  final p = getPriority(priorityLabel);
  final id = uid();
  final task = Task(
    id: id,
    templateId: id,
    text: text,
    priorityLabel: p['label'] as String,
    priorityWeight: p['weight'] as int,
    done: false,
    createdAt: DateTime.now().toIso8601String(),
  );
  final templates =
      _sortByPriority([...state.templates, task.copyWith(done: false)]);
  final current =
      _sortByPriority([...state.currentTasks, task.copyWith(done: false)]);
  return state.copyWith(
    templates: templates,
    currentTasks: current,
  );
}

AppState removeTask(AppState state, String templateId) {
  return state.copyWith(
    templates:
        state.templates.where((t) => t.templateId != templateId).toList(),
    currentTasks:
        state.currentTasks.where((t) => t.templateId != templateId).toList(),
  );
}

AppState toggleTask(AppState state, String taskId) {
  return state.copyWith(
    currentTasks: state.currentTasks
        .map((t) => t.id == taskId ? t.copyWith(done: !t.done) : t)
        .toList(),
  );
}

AppState changePriority(
    AppState state, String templateId, String priorityLabel) {
  final p = getPriority(priorityLabel);
  Task update(Task t) => t.copyWith(
        priorityLabel: p['label'] as String,
        priorityWeight: p['weight'] as int,
      );
  return state.copyWith(
    templates: _sortByPriority(state.templates
        .map((t) => t.templateId == templateId ? update(t) : t)
        .toList()),
    currentTasks: _sortByPriority(state.currentTasks
        .map((t) => t.templateId == templateId ? update(t) : t)
        .toList()),
  );
}

AppState setRepeatDays(AppState state, int days) {
  final clamped = days.clamp(1, 365);
  final nextDayIndex = state.dayIndex <= 0 ? 1 : state.dayIndex;
  final rehydrate = state.currentTasks.isEmpty &&
      state.templates.isNotEmpty &&
      nextDayIndex <= clamped;
  return state.copyWith(
    repeatDays: clamped,
    dayIndex: nextDayIndex,
    currentTasks: rehydrate
        ? buildTasksFromTemplates(state.templates)
        : state.currentTasks,
  );
}

AppState resetProgress(AppState state) {
  final cal = getCalendarInfo();
  return state.copyWith(
    cycleStartKey: cal.key,
    currentDayKey: cal.key,
    currentDayLabel: cal.label,
    currentDayFullLabel: cal.fullLabel,
    dayIndex: 1,
    currentTasks: buildTasksFromTemplates(state.templates),
    history: const [],
    lastSyncedAt: DateTime.now().toIso8601String(),
  );
}

AppState resetEverything(AppState state) {
  final cal = getCalendarInfo();
  return state.copyWith(
    repeatDays: 0,
    cycleStartKey: cal.key,
    currentDayKey: cal.key,
    currentDayLabel: cal.label,
    currentDayFullLabel: cal.fullLabel,
    dayIndex: 0,
    templates: const [],
    currentTasks: const [],
    history: const [],
    lastSyncedAt: DateTime.now().toIso8601String(),
  );
}

AppState toggleTheme(AppState state) => state.copyWith(isDark: !state.isDark);
