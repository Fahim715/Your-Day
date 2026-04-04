// lib/home.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

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
      resizeToAvoidBottomInset: false,
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
              onResetProgress: () {
                widget.onUpdate(resetProgress);
                _showFlash('Progress reset. History cleared.');
              },
              onResetEverything: () {
                widget.onUpdate(resetEverything);
                _showFlash('Everything reset.');
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
  final VoidCallback onResetProgress;
  final VoidCallback onResetEverything;

  const _Header({
    required this.state,
    required this.stats,
    required this.isCycleDone,
    required this.flash,
    required this.onToggleTheme,
    required this.onConfirm,
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

    final progressNote = widget.isCycleDone
      ? 'Repeat cycle done. Extend the repeat window to continue.'
      : widget.state.prioritiesConfirmed
        ? 'Weighted progress active.'
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
          initialValue: widget.state.repeatDays > 0 ? widget.state.repeatDays : null,
        ),
      );

      if (selectedDays != null) {
        widget.onRepeatChanged(selectedDays);
      }
    }

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    // Stats row
                    Row(
                      children: [
                        _StatChip(
                          label: 'Tasks',
                          value: '${widget.state.currentTasks.length}',
                          highlight: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: showRepeatForDialog,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(112, 30),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(repeatLabel),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: showResetDialog,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(66, 30),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Reset'),
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
                      widget.state.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      size: 20,
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
                            color: cs.surface.withOpacity(0.75),
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
                          builder: (context, value, _) =>
                              CircularProgressBar(progress: value),
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
            Text(progressNote,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),

          // Flash message
          if (widget.flash.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(widget.flash,
                style:
                    tt.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w500)),
          ],

          const SizedBox(height: 6),
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
        decoration: const InputDecoration(
          hintText: 'Enter number of days',
        ),
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

class _GradientCirclePainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final List<Color> colors;

  _GradientCirclePainter({
    required this.progress,
    required this.trackColor,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: colors,
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, trackPaint);

    final clamped = progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * clamped, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _GradientCirclePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.colors != colors;
  }
}

class CircularProgressBar extends StatelessWidget {
  final double progress;

  const CircularProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    const strokeWidth = 8.0;
    const radius = 48.0;
    final size = (radius * 2) + strokeWidth;
    final clamped = progress.clamp(0.0, 1.0);
    final reachedTarget = clamped >= 0.8;

    final startColor = reachedTarget
        ? const Color(0xFF7CD992)
        : const Color(0xFFFF6B8A);
    final endColor = reachedTarget
        ? const Color(0xFF1FA34A)
        : const Color(0xFFE8344E);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HorseshoeProgressPainter(
          progress: clamped,
          trackColor: const Color(0xFFE0E0E0),
          startColor: startColor,
          endColor: endColor,
          strokeWidth: strokeWidth,
          radius: radius,
        ),
        child: Center(
          child: Text(
            '${(clamped * 100).round()}%',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A4A4A),
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
    return Container(
      color: cs.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Add task',
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