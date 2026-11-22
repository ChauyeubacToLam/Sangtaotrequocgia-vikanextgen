import 'package:flutter/material.dart';

import '../../services/workout_reminders.dart';
import '../tk/tk.dart';

Future<WorkoutSchedule?> showWorkoutScheduleSheet(
  BuildContext context,
  WorkoutSchedule initial,
) {
  return showModalBottomSheet<WorkoutSchedule>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Tk.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ScheduleSheet(initial: initial),
  );
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.initial});

  final WorkoutSchedule initial;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late final Set<int> _days = {...widget.initial.days};
  late int _minute = widget.initial.minute;
  late bool _remindersOn = widget.initial.remindersOn;
  bool _saving = false;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _minute ~/ 60, minute: _minute % 60),
      helpText: 'Giờ tập',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null) {
      setState(() => _minute = picked.hour * 60 + picked.minute);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final schedule = WorkoutSchedule(
      days: _days.toList()..sort(),
      minute: _minute,
      remindersOn: _remindersOn,
    );
    await WorkoutReminders.save(schedule);
    if (mounted) Navigator.of(context).pop(schedule);
  }

  Future<void> _sendTest() async {
    final ok = await WorkoutReminders.sendTest();
    if (!mounted || ok) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
            'Vika chưa được phép gửi thông báo. Bật trong Cài đặt > Ứng dụng > Vika > Thông báo.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final before = WorkoutReminders.formatMinute(
        (_minute - WorkoutReminders.leadMinutes).clamp(0, 1439));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                    color: Tk.line, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Lịch tập & nhắc nhở',
                style: Tk.text(24, weight: FontWeight.w900)),
            const SizedBox(height: 18),
            Text('NGÀY TẬP', style: Tk.eyebrow()),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _DayChip(
                      label: WorkoutReminders.dayShort[i],
                      selected: _days.contains(i),
                      onTap: () => setState(() =>
                          _days.contains(i) ? _days.remove(i) : _days.add(i)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Text('GIỜ TẬP', style: Tk.eyebrow()),
            const SizedBox(height: 10),
            TkCard(
              onTap: _pickTime,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      color: Tk.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(WorkoutReminders.formatMinute(_minute),
                      style: Tk.text(28, weight: FontWeight.w900)),
                  const Spacer(),
                  Text('Đổi giờ',
                      style: Tk.text(15,
                          weight: FontWeight.w800, color: Tk.primary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TkCard(
              onTap: () => setState(() => _remindersOn = !_remindersOn),
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tự động nhắc lịch tập',
                            style: Tk.text(16, weight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          '07:00 đầu ngày, 12:00 buổi trưa, $before (trước 2 tiếng) và đúng ${WorkoutReminders.formatMinute(_minute)}',
                          style: Tk.text(13,
                              weight: FontWeight.w600,
                              color: Tk.inkSoft,
                              height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  IgnorePointer(
                    child: Switch.adaptive(
                      value: _remindersOn,
                      activeTrackColor: Tk.green,
                      onChanged: (_) {},
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _sendTest,
                icon: const Icon(Icons.notifications_active_rounded,
                    color: Tk.primary, size: 20),
                label: Text('Gửi thử một thông báo',
                    style: Tk.text(14.5,
                        weight: FontWeight.w800, color: Tk.primary)),
              ),
            ),
            const SizedBox(height: 8),
            TkButton(
              label: _days.isEmpty ? 'Chọn ít nhất 1 ngày' : 'Lưu lịch tập',
              busy: _saving,
              onTap: _days.isEmpty || _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Tk.primary : Tk.surface,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: selected ? Tk.primary : Tk.line, width: 2),
            boxShadow: [
              BoxShadow(
                  color: selected ? Tk.primaryLip : Tk.line,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Text(
            label,
            style: Tk.text(14,
                weight: FontWeight.w900,
                color: selected ? Colors.white : Tk.inkSoft),
          ),
        ),
      ),
    );
  }
}
