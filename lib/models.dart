// lib/models.dart
import 'dart:math';

// ── Priority ─────────────────────────────────────────────────────────────────

const priorityOptions = [
  {'label': 'Low', 'weight': 1},
  {'label': 'Medium', 'weight': 2},
  {'label': 'High', 'weight': 5},
  {'label': 'No way I can miss', 'weight': 10},
];

Map<String, dynamic> getPriority(String label) {
  return priorityOptions.firstWhere(
    (p) => p['label'] == label,
    orElse: () => priorityOptions[1], // default Medium
  );
}

// ── UID ──────────────────────────────────────────────────────────────────────

String uid() {
  final ts = DateTime.now().microsecondsSinceEpoch;
  final rand = Random().nextInt(0xFFFFFF).toRadixString(16);
  return '$ts-$rand';
}

// ── Task ─────────────────────────────────────────────────────────────────────

class Task {
  final String id;
  final String templateId;
  final String text;
  final String priorityLabel;
  final int priorityWeight;
  final bool done;
  final String createdAt;

  const Task({
    required this.id,
    required this.templateId,
    required this.text,
    required this.priorityLabel,
    required this.priorityWeight,
    required this.done,
    required this.createdAt,
  });

  Task copyWith({
    String? id,
    String? templateId,
    String? text,
    String? priorityLabel,
    int? priorityWeight,
    bool? done,
    String? createdAt,
  }) =>
      Task(
        id: id ?? this.id,
        templateId: templateId ?? this.templateId,
        text: text ?? this.text,
        priorityLabel: priorityLabel ?? this.priorityLabel,
        priorityWeight: priorityWeight ?? this.priorityWeight,
        done: done ?? this.done,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'text': text,
        'priorityLabel': priorityLabel,
        'priorityWeight': priorityWeight,
        'done': done,
        'createdAt': createdAt,
      };

  factory Task.fromJson(Map<String, dynamic> j) {
    final p = getPriority((j['priorityLabel'] as String?) ?? 'Medium');
    final id = (j['id'] as String?) ?? uid();
    return Task(
      id: id,
      templateId: (j['templateId'] as String?) ?? id,
      text: (j['text'] as String?) ?? '',
      priorityLabel: p['label'] as String,
      priorityWeight: p['weight'] as int,
      done: (j['done'] as bool?) ?? false,
      createdAt:
          (j['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }
}

// ── DayRecord ────────────────────────────────────────────────────────────────

class DayRecord {
  final String dayKey;
  final String dayLabel;
  final String fullLabel;
  final int progress;
  final int totalWeight;
  final int completedWeight;
  final int taskCount;
  final int completedTaskCount;
  final String archivedAt;
  final List<Task> tasks;

  const DayRecord({
    required this.dayKey,
    required this.dayLabel,
    required this.fullLabel,
    required this.progress,
    required this.totalWeight,
    required this.completedWeight,
    required this.taskCount,
    required this.completedTaskCount,
    required this.archivedAt,
    required this.tasks,
  });

  Map<String, dynamic> toJson() => {
        'dayKey': dayKey,
        'dayLabel': dayLabel,
        'fullLabel': fullLabel,
        'progress': progress,
        'totalWeight': totalWeight,
        'completedWeight': completedWeight,
        'taskCount': taskCount,
        'completedTaskCount': completedTaskCount,
        'archivedAt': archivedAt,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };

  factory DayRecord.fromJson(Map<String, dynamic> j) => DayRecord(
        dayKey: (j['dayKey'] as String?) ?? '',
        dayLabel: (j['dayLabel'] as String?) ?? '',
        fullLabel:
            (j['fullLabel'] as String?) ?? (j['dayLabel'] as String?) ?? '',
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        totalWeight: (j['totalWeight'] as num?)?.toInt() ?? 0,
        completedWeight: (j['completedWeight'] as num?)?.toInt() ?? 0,
        taskCount: (j['taskCount'] as num?)?.toInt() ?? 0,
        completedTaskCount: (j['completedTaskCount'] as num?)?.toInt() ?? 0,
        archivedAt:
            (j['archivedAt'] as String?) ?? DateTime.now().toIso8601String(),
        tasks: (j['tasks'] as List<dynamic>? ?? [])
            .map((t) => Task.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}

// ── AppState ─────────────────────────────────────────────────────────────────

const defaultRepeatDays = 40;

class AppState {
  final bool isDark;
  final int repeatDays;
  final String cycleStartKey;
  final String currentDayKey;
  final String currentDayLabel;
  final String currentDayFullLabel;
  final int dayIndex;
  final List<Task> templates;
  final List<Task> currentTasks;
  final List<DayRecord> history;
  final String lastSyncedAt;

  const AppState({
    required this.isDark,
    required this.repeatDays,
    required this.cycleStartKey,
    required this.currentDayKey,
    required this.currentDayLabel,
    required this.currentDayFullLabel,
    required this.dayIndex,
    required this.templates,
    required this.currentTasks,
    required this.history,
    required this.lastSyncedAt,
  });

  AppState copyWith({
    bool? isDark,
    int? repeatDays,
    String? cycleStartKey,
    String? currentDayKey,
    String? currentDayLabel,
    String? currentDayFullLabel,
    int? dayIndex,
    List<Task>? templates,
    List<Task>? currentTasks,
    List<DayRecord>? history,
    String? lastSyncedAt,
  }) =>
      AppState(
        isDark: isDark ?? this.isDark,
        repeatDays: repeatDays ?? this.repeatDays,
        cycleStartKey: cycleStartKey ?? this.cycleStartKey,
        currentDayKey: currentDayKey ?? this.currentDayKey,
        currentDayLabel: currentDayLabel ?? this.currentDayLabel,
        currentDayFullLabel: currentDayFullLabel ?? this.currentDayFullLabel,
        dayIndex: dayIndex ?? this.dayIndex,
        templates: templates ?? this.templates,
        currentTasks: currentTasks ?? this.currentTasks,
        history: history ?? this.history,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      );

  Map<String, dynamic> toJson() => {
        'isDark': isDark,
        'repeatDays': repeatDays,
        'cycleStartKey': cycleStartKey,
        'currentDayKey': currentDayKey,
        'currentDayLabel': currentDayLabel,
        'currentDayFullLabel': currentDayFullLabel,
        'dayIndex': dayIndex,
        'templates': templates.map((t) => t.toJson()).toList(),
        'currentTasks': currentTasks.map((t) => t.toJson()).toList(),
        'history': history.map((r) => r.toJson()).toList(),
        'lastSyncedAt': lastSyncedAt,
      };

  factory AppState.fromJson(Map<String, dynamic> j) => AppState(
        isDark: (j['isDark'] as bool?) ?? false,
        repeatDays: (j['repeatDays'] as num?)?.toInt() ?? 0,
        cycleStartKey: (j['cycleStartKey'] as String?) ?? '',
        currentDayKey: (j['currentDayKey'] as String?) ?? '',
        currentDayLabel: (j['currentDayLabel'] as String?) ?? '',
        currentDayFullLabel: (j['currentDayFullLabel'] as String?) ?? '',
        dayIndex: (j['dayIndex'] as num?)?.toInt() ?? 0,
        templates: (j['templates'] as List<dynamic>? ?? [])
            .map((t) => Task.fromJson(t as Map<String, dynamic>))
            .toList(),
        currentTasks: (j['currentTasks'] as List<dynamic>? ?? [])
            .map((t) => Task.fromJson(t as Map<String, dynamic>))
            .toList(),
        history: (j['history'] as List<dynamic>? ?? [])
            .map((r) => DayRecord.fromJson(r as Map<String, dynamic>))
            .toList(),
        lastSyncedAt:
            (j['lastSyncedAt'] as String?) ?? DateTime.now().toIso8601String(),
      );
}

// ── Progress ─────────────────────────────────────────────────────────────────

class ProgressStats {
  final int totalWeight;
  final int completedWeight;
  final int progress; // 0-100

  const ProgressStats({
    required this.totalWeight,
    required this.completedWeight,
    required this.progress,
  });
}

ProgressStats calculateProgress(List<Task> tasks) {
  final total = tasks.fold(0, (sum, t) => sum + t.priorityWeight);
  final completed =
      tasks.fold(0, (sum, t) => sum + (t.done ? t.priorityWeight : 0));
  final progress = total > 0 ? ((completed / total) * 100).round() : 0;
  return ProgressStats(
    totalWeight: total,
    completedWeight: completed,
    progress: progress,
  );
}
