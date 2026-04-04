// lib/home.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logic.dart';
import 'models.dart';

class HomeScreen extends StatefulWidget {
  final AppState state;
  final void Function(AppState Function(AppState)) onUpdate;

  const HomeScreen({super.key, required this.state, required this.onUpdate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _taskCtrl = TextEditingController();
  String _draftPriority = 'Medium';
  String _flash = '';
  Timer? _flashTimer;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _syncTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => widget.onUpdate((s) => advanceToToday(s)),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _taskCtrl.dispose();
    _flashTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  void _showFlash(String msg) {
    setState(() => _flash = msg);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _flash = '');
    });
  }

  void _addTask() {
    final text = _taskCtrl.text.trim();
    if (text.isEmpty) {
      _showFlash('Write a task first.');
      return;
    }
    widget.onUpdate((s) => addTask(s, text, _draftPriority));
    _taskCtrl.clear();
    setState(() => _draftPriority = 'Medium');
    _showFlash('Task added.');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final cs = Theme.of(context).colorScheme;
    final stats = calculateProgress(s.currentTasks);
    final isCycleDone = s.dayIndex > s.repeatDays;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgImage = isDark
        ? const AssetImage('images/dark_theme.jpeg')
        : const AssetImage('images/bright_theme.jpeg');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: bgImage,
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
            _Header(
              state: s,
              stats: stats,
              isCycleDone: isCycleDone,
              flash: _flash,
              onToggleTheme: () => widget.onUpdate(toggleTheme),
              onConfirm: () {
                if (s.currentTasks.isEmpty) {
                  _showFlash('Add tasks before confirming.');
                  return;
                }
                widget.onUpdate(confirmPriorities);
                _showFlash('Priority weights confirmed.');
              },
              onRepeatChanged: (v) {
                widget.onUpdate((s) => setRepeatDays(s, v));
                _showFlash('Repeat set to $v days.');
              },
            ),
            _AddTaskBar(
              controller: _taskCtrl,
              priority: _draftPriority,
              onPriorityChanged: (v) => setState(() => _draftPriority = v),
              onAdd: _addTask,
            ),
            TabBar(
              controller: _tabs,
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: cs.primary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [Tab(text: 'Today'), Tab(text: 'History')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _TodayTab(
                    state: s,
                    stats: stats,
                    onToggle: (id) => widget.onUpdate((s) => toggleTask(s, id)),
                    onRemove: (id) {
                      widget.onUpdate((s) => removeTask(s, id));
                      _showFlash('Task removed.');
                    },
                    onPriorityChanged: (tid, p) =>
                        widget.onUpdate((s) => changePriority(s, tid, p)),
                  ),
                  _HistoryTab(history: s.history.reversed.toList()),
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

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatefulWidget {
  final AppState state;
  final ProgressStats stats;
  final bool isCycleDone;
  final String flash;
  final VoidCallback onToggleTheme;
  final VoidCallback onConfirm;
  final void Function(int) onRepeatChanged;

  const _Header({
    required this.state,
    required this.stats,
    required this.isCycleDone,
    required this.flash,
    required this.onToggleTheme,
    required this.onConfirm,
    required this.onRepeatChanged,
  });

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late final TextEditingController _repeatCtrl;
  late final FocusNode _repeatFocus;
  Timer? _repeatDebounce;

  @override
  void initState() {
    super.initState();
    _repeatCtrl = TextEditingController(text: widget.state.repeatDays.toString());
    _repeatFocus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _Header oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.state.repeatDays.toString();
    if (!_repeatFocus.hasFocus && _repeatCtrl.text != nextText) {
      _repeatCtrl.text = nextText;
    }
  }

  @override
  void dispose() {
    _repeatDebounce?.cancel();
    _repeatCtrl.dispose();
    _repeatFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final progressNote = widget.isCycleDone
      ? 'Repeat cycle done. Extend the repeat window to continue.'
      : widget.state.prioritiesConfirmed
        ? 'Weighted progress active.'
        : '';

    final daysLeft =
        (widget.state.repeatDays - widget.state.dayIndex + 1).clamp(0, 365);

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Priority Cycle Tracker',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.state.currentDayFullLabel.isEmpty
                          ? 'Your Day'
                          : widget.state.currentDayFullLabel,
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  widget.state.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 20,
                ),
                onPressed: widget.onToggleTheme,
                tooltip: widget.state.isDark ? 'Light theme' : 'Dark theme',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Days left + repeat input row
          Row(
            children: [
              _StatChip(
                label: 'Days left',
                value: '$daysLeft',
              ),
              const SizedBox(width: 10),
              Row(
                children: [
                  Text('Repeat:', style: tt.labelMedium),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 52,
                    height: 32,
                    child: TextField(
                      focusNode: _repeatFocus,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: cs.outline),
                        ),
                      ),
                      controller: _repeatCtrl,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        _repeatDebounce?.cancel();
                        _repeatDebounce = Timer(const Duration(seconds: 2), () {
                          final parsed = int.tryParse(v);
                          if (parsed != null) widget.onRepeatChanged(parsed);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('days', style: tt.labelMedium),
                ],
              ),
              const Spacer(),
            ],
          ),

          const SizedBox(height: 12),

          // Task + progress row
          Row(
            children: [
              _StatChip(
                label: 'Tasks',
                value: '${widget.state.currentTasks.length}',
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Progress',
                value: '${widget.stats.progress}%',
                highlight: true,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress summary + circle
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.stats.completedWeight} / ${widget.stats.totalWeight} pts',
                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.state.prioritiesConfirmed ? 'Confirmed ✓' : 'Pending',
                      style: tt.labelSmall?.copyWith(
                        color: widget.state.prioritiesConfirmed
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: widget.stats.progress / 100,
                      strokeWidth: 6,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                    ),
                    Text(
                      '${widget.stats.progress}%',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Note
          if (progressNote.isNotEmpty)
            Text(progressNote,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),

          // Flash message
          if (widget.flash.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(widget.flash,
                style:
                    tt.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w500)),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: highlight ? cs.onPrimaryContainer : cs.onSurface,
              )),
          Text(label,
              style: TextStyle(
                fontSize: 10,
                color: highlight ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              )),
        ],
      ),
    );
  }
}

// ── Add task bar ──────────────────────────────────────────────────────────────

class _AddTaskBar extends StatelessWidget {
  final TextEditingController controller;
  final String priority;
  final void Function(String) onPriorityChanged;
  final VoidCallback onAdd;

  const _AddTaskBar({
    required this.controller,
    required this.priority,
    required this.onPriorityChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Add a daily task…',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: cs.outline),
                ),
                filled: true,
                fillColor: cs.surface,
              ),
              onSubmitted: (_) => onAdd(),
              textInputAction: TextInputAction.done,
            ),
          ),
          const SizedBox(width: 8),
          // Priority picker
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline),
              borderRadius: BorderRadius.circular(10),
              color: cs.surface,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: priority,
                isDense: true,
                style: TextStyle(fontSize: 13, color: cs.onSurface),
                items: priorityOptions
                    .map((p) => DropdownMenuItem(
                          value: p['label'] as String,
                          child: Text(p['label'] as String),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onPriorityChanged(v);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              minimumSize: const Size(42, 42),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Today tab ─────────────────────────────────────────────────────────────────

class _TodayTab extends StatelessWidget {
  final AppState state;
  final ProgressStats stats;
  final void Function(String taskId) onToggle;
  final void Function(String templateId) onRemove;
  final void Function(String templateId, String priority) onPriorityChanged;

  const _TodayTab({
    required this.state,
    required this.stats,
    required this.onToggle,
    required this.onRemove,
    required this.onPriorityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (state.currentTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                state.templates.isNotEmpty
                    ? 'No tasks for today.'
                    : 'Start by adding a task above.',
                style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                state.templates.isNotEmpty
                    ? 'Extend the repeat window to keep templates active.'
                    : 'Create tasks, set priorities, and confirm to start your cycle.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: state.currentTasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final task = state.currentTasks[i];
        final share = stats.totalWeight > 0
            ? ((task.priorityWeight / stats.totalWeight) * 100).round()
            : 0;
        return _TaskCard(
          task: task,
          share: share,
          onToggle: () => onToggle(task.id),
          onRemove: () => onRemove(task.templateId),
          onPriorityChanged: (p) => onPriorityChanged(task.templateId, p),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final int share;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final void Function(String) onPriorityChanged;

  const _TaskCard({
    required this.task,
    required this.share,
    required this.onToggle,
    required this.onRemove,
    required this.onPriorityChanged,
  });

  Color _priorityColor(ColorScheme cs) {
    switch (task.priorityLabel) {
      case 'High':
        return cs.error;
      case 'No way I can miss':
        return cs.error;
      case 'Medium':
        return cs.primary;
      default:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pColor = _priorityColor(cs);

    return Container(
      decoration: BoxDecoration(
        color: task.done
            ? cs.surfaceContainerHighest.withOpacity(0.5)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.done ? cs.outline.withOpacity(0.3) : cs.outline.withOpacity(0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.done ? cs.primary : Colors.transparent,
                      border: Border.all(
                        color: task.done ? cs.primary : cs.outline,
                        width: 2,
                      ),
                    ),
                    child: task.done
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.text,
                            style: tt.bodyMedium?.copyWith(
                              decoration:
                                  task.done ? TextDecoration.lineThrough : null,
                              color: task.done ? cs.onSurfaceVariant : cs.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$share%',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Priority dropdown
                        SizedBox(
                          height: 28,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: pColor.withOpacity(0.4)),
                              borderRadius: BorderRadius.circular(6),
                              color: pColor.withOpacity(0.08),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: task.priorityLabel,
                                isDense: true,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: pColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                icon: Icon(Icons.expand_more,
                                    size: 14, color: pColor),
                                items: priorityOptions
                                    .map((p) => DropdownMenuItem(
                                          value: p['label'] as String,
                                          child: Text(p['label'] as String,
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) onPriorityChanged(v);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: pColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'w: ${task.priorityWeight}',
                            style: TextStyle(
                              fontSize: 10,
                              color: pColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Remove
              GestureDetector(
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── History tab ───────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final List<DayRecord> history;

  const _HistoryTab({required this.history});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                'No history yet.',
                style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(
                'Each day\'s progress will be archived here.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final r = history[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: cs.outline.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.fullLabel,
                        style: tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${r.completedTaskCount} of ${r.taskCount} tasks done',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: r.progress / 100,
                        minHeight: 4,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${r.progress}%',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                  Text(
                    '${r.completedWeight}/${r.totalWeight} pts',
                    style: tt.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
