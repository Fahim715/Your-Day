// lib/home.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'logic.dart';
import 'models.dart';

Color _priorityFontColor(String label, bool isDark) {
  switch (label) {
    case 'No way I can miss':
      return const Color(0xFFD32F2F);
    case 'High':
      return isDark ? const Color(0xFFFBC02D) : const Color(0xFF6F4E37);
    case 'Medium':
      return const Color(0xFF1976D2);
    case 'Low':
      return isDark ? Colors.white : Colors.black;
    default:
      return isDark ? Colors.white : Colors.black;
  }
}

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
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image(image: bgImage, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          const Color(0xE61B2127),
                          const Color(0xCC161C22),
                          const Color(0xF210151A),
                        ]
                      : [
                          const Color(0xD9FFF9F3),
                          const Color(0xCCFFF5EA),
                          const Color(0xEAFFF7F0),
                        ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _Header(
                  state: s,
                  stats: stats,
                  isCycleDone: isCycleDone,
                  flash: _flash,
                  onToggleTheme: () => widget.onUpdate(toggleTheme),
                  onRepeatChanged: (v) {
                    widget.onUpdate((s) => setRepeatDays(s, v));
                    _showFlash('Repeat set to $v days.');
                  },
                  onResetProgress: () {
                    widget.onUpdate(resetProgress);
                    _showFlash('Progress reset. History cleared.');
                  },
                  onResetEverything: () {
                    widget.onUpdate(resetEverything);
                    _showFlash('Everything reset.');
                  },
                ),
                const SizedBox(height: 8),
                _AddTaskBar(
                  controller: _taskCtrl,
                  priority: _draftPriority,
                  onPriorityChanged: (v) => setState(() => _draftPriority = v),
                  onAdd: _addTask,
                ),
                const SizedBox(height: 10),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: isDark ? 0.62 : 0.86),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    labelColor: cs.onPrimaryContainer,
                    unselectedLabelColor: cs.onSurfaceVariant,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: cs.primaryContainer,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Today'),
                      Tab(text: 'History'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _TodayTab(
                        state: s,
                        stats: stats,
                        onToggle: (id) =>
                            widget.onUpdate((s) => toggleTask(s, id)),
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
        ],
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
  final void Function(int) onRepeatChanged;
  final VoidCallback onResetProgress;
  final VoidCallback onResetEverything;

  const _Header({
    required this.state,
    required this.stats,
    required this.isCycleDone,
    required this.flash,
    required this.onToggleTheme,
    required this.onRepeatChanged,
    required this.onResetProgress,
    required this.onResetEverything,
  });

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final noWayTasks = widget.state.currentTasks
        .where((t) => t.priorityLabel == 'No way I can miss')
        .toList();
    final allNoWayTasksCompleted = noWayTasks.every((t) => t.done);

    final progressNote = widget.isCycleDone
        ? 'Repeat cycle done. Extend the repeat window to continue.'
        : '';

    final repeatLabel = widget.state.repeatDays <= 0
        ? 'Repeat For?'
        : 'Day ${widget.state.dayIndex <= 0 ? 1 : widget.state.dayIndex}/${widget.state.repeatDays}';

    Future<void> showResetDialog() async {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Reset options'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onResetProgress();
                  },
                  child: const Text('Reset Your Progress'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    showDialog<void>(
                      context: this.context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Confirm Reset Everything'),
                          content: const Text(
                            'This will clear all tasks, history, and reset repeat days to 0. Continue?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                widget.onResetEverything();
                              },
                              child: const Text('Yes, Reset Everything'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Text('Reset Everything'),
                ),
              ],
            ),
          );
        },
      );
    }

    Future<void> showRepeatForDialog() async {
      final selectedDays = await showDialog<int>(
        context: context,
        builder: (_) => _RepeatDialog(
          initialValue:
              widget.state.repeatDays > 0 ? widget.state.repeatDays : null,
        ),
      );

      if (selectedDays != null) {
        widget.onRepeatChanged(selectedDays);
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: widget.state.isDark ? 0.64 : 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: widget.state.isDark ? 0.22 : 0.07,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: title + circular progress + theme toggle
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Stats row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatChip(
                          label: 'Tasks',
                          value: '${widget.state.currentTasks.length}',
                          highlight: true,
                        ),
                        FilledButton.tonalIcon(
                          onPressed: showRepeatForDialog,
                          icon: const Icon(Icons.event_repeat, size: 16),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(128, 34),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                          ),
                          label: Text(repeatLabel),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: showResetDialog,
                          icon: const Icon(Icons.restart_alt, size: 16),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(92, 34),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                          ),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Circular progress + theme toggle stacked
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      widget.state.isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      size: 22,
                    ),
                    onPressed: widget.onToggleTheme,
                    tooltip: widget.state.isDark ? 'Light theme' : 'Dark theme',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                          ),
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: widget.stats.progress / 100,
                          ),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => CircularProgressBar(
                            progress: value,
                            allNoWayTasksCompleted: allNoWayTasksCompleted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Note
          if (progressNote.isNotEmpty)
            Text(
              progressNote,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),

          // Flash message
          if (widget.flash.isNotEmpty) ...[
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.flash,
                style: tt.bodySmall?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

// ── Repeat dialog ─────────────────────────────────────────────────────────────

class _RepeatDialog extends StatefulWidget {
  final int? initialValue;
  const _RepeatDialog({this.initialValue});

  @override
  State<_RepeatDialog> createState() => _RepeatDialogState();
}

class _RepeatDialogState extends State<_RepeatDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initialValue != null ? widget.initialValue.toString() : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Repeat tasks for how many days?'),
      content: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Enter number of days'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final parsed = int.tryParse(_ctrl.text.trim());
            if (parsed == null || parsed <= 0 || parsed > 365) return;
            Navigator.of(context).pop(parsed);
          },
          child: const Text('Confirm'),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: highlight ? cs.onPrimaryContainer : cs.onSurface,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: highlight ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class CircularProgressBar extends StatelessWidget {
  final double progress;
  final bool allNoWayTasksCompleted;

  const CircularProgressBar({
    super.key,
    required this.progress,
    required this.allNoWayTasksCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const strokeWidth = 8.0;
    const radius = 48.0;
    final size = (radius * 2) + strokeWidth;
    final clamped = progress.clamp(0.0, 1.0);
    final progressPercent = (clamped * 100).round();

    Color lineColor;
    if (progressPercent >= 100) {
      lineColor = const Color(0xFFFFC107); // Golden
    } else {
      lineColor = allNoWayTasksCompleted
          ? (progressPercent >= 80
              ? const Color(0xFF1E8A4E) // Green
              : const Color(0xFF1976D2)) // Blue
          : const Color(0xFFD32F2F); // Red
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HorseshoeProgressPainter(
          progress: clamped,
          trackColor: cs.surfaceContainerHighest,
          startColor: lineColor,
          endColor: lineColor,
          strokeWidth: strokeWidth,
          radius: radius,
        ),
        child: Center(
          child: Text(
            '${(clamped * 100).round()}%',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _HorseshoeProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color startColor;
  final Color endColor;
  final double strokeWidth;
  final double radius;

  _HorseshoeProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.startColor,
    required this.endColor,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    const startAngle = (5 * math.pi) / 4; // bottom-left
    const sweepAngle = (3 * math.pi) / 2; // 270 deg

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    if (progress <= 0) return;

    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [startColor, endColor],
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final clamped = progress.clamp(0.0, 1.0);
    final progressSweep = sweepAngle * clamped;
    canvas.drawArc(rect, startAngle, progressSweep, false, progressPaint);

    final endAngle = startAngle + progressSweep;
    final endOffset = Offset(
      center.dx + radius * math.cos(endAngle),
      center.dy + radius * math.sin(endAngle),
    );
    final dotPaint = Paint()..color = endColor;
    canvas.drawCircle(endOffset, strokeWidth / 2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _HorseshoeProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNarrow = MediaQuery.sizeOf(context).width < 390;
    final addPriorityColor = _priorityFontColor(priority, isDark);
    final priorityBoxColor =
        isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLowest;

    final inputField = TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Add task',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        filled: true,
        fillColor: cs.surface,
      ),
      onSubmitted: (_) => onAdd(),
      textInputAction: TextInputAction.done,
    );

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(12),
            color: priorityBoxColor,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: priority,
              isDense: true,
              dropdownColor: priorityBoxColor,
              style: TextStyle(fontSize: 12.5, color: addPriorityColor),
              items: priorityOptions
                  .map(
                    (p) => DropdownMenuItem(
                      value: p['label'] as String,
                      child: Text(
                        p['label'] as String,
                        style: TextStyle(
                          color: _priorityFontColor(
                            p['label'] as String,
                            isDark,
                          ),
                        ),
                      ),
                    ),
                  )
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
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                inputField,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: controls),
              ],
            )
          : Row(
              children: [
                Expanded(child: inputField),
                const SizedBox(width: 8),
                controls,
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
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: cs.onSurfaceVariant,
              ),
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
                    : 'Create tasks, set priorities.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: state.currentTasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
    final isDark = cs.brightness == Brightness.dark;
    return _priorityFontColor(task.priorityLabel, isDark);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pColor = _priorityColor(cs);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityBaseBg =
        isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLowest;

    return Container(
      decoration: BoxDecoration(
        color: task.done
            ? cs.surfaceContainerHighest.withValues(alpha: 0.58)
            : cs.surfaceContainerLow.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: task.done
              ? cs.outlineVariant.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                              color: task.done
                                  ? cs.onSurfaceVariant
                                  : cs.onSurface,
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
                          height: 30,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: pColor.withValues(alpha: 0.4),
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Color.alphaBlend(
                                pColor.withValues(alpha: 0.12),
                                priorityBaseBg,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: task.priorityLabel,
                                isDense: true,
                                dropdownColor: priorityBaseBg,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: pColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                icon: Icon(
                                  Icons.expand_more,
                                  size: 14,
                                  color: pColor,
                                ),
                                items: priorityOptions
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p['label'] as String,
                                        child: Text(
                                          p['label'] as String,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _priorityFontColor(
                                              p['label'] as String,
                                              isDark,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
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
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Color.alphaBlend(
                              pColor.withValues(alpha: 0.15),
                              priorityBaseBg,
                            ),
                            borderRadius: BorderRadius.circular(6),
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
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: cs.onSurfaceVariant,
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = history[i];
        final hasMissedNoWay = r.tasks.any(
          (t) => t.priorityLabel == 'No way I can miss' && !t.done,
        );
        final allTasksCompleted =
            r.taskCount > 0 && r.completedTaskCount == r.taskCount;
        final allNoWayCompleted = !hasMissedNoWay;

        final percentColor = allTasksCompleted
            ? const Color(0xFFFFC107)
            : hasMissedNoWay
                ? const Color(0xFFD32F2F)
                : (allNoWayCompleted && r.progress >= 80)
                    ? const Color(0xFF1E8A4E)
                    : cs.primary;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.62),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.fullLabel,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hasMissedNoWay) ...[
                      const SizedBox(height: 4),
                      Text(
                        'You missed what shouldn\'t have.',
                        style: tt.bodySmall?.copyWith(
                          color: const Color(0xFFD32F2F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                      color: percentColor,
                      fontSize: 20,
                    ),
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
