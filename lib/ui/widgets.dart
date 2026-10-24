import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

const Color kIncomeColor = Color(0xFF2E7D32);
const Color kExpenseColor = Color(0xFFC62828);

class SectionCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;

  const SectionCard({super.key, this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

class CatAvatar extends StatelessWidget {
  final Category? cat;
  final double radius;
  const CatAvatar(this.cat, {super.key, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final color = cat == null ? Colors.grey : Color(cat!.color);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(
        cat == null ? Icons.help_outline : iconOf(cat!.icon),
        color: color,
        size: radius * 1.05,
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyHint(this.text, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).disabledColor),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// ردیف «عنوان ... مقدار»
class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const KeyValueRow(this.label, this.value,
      {super.key, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, String message,
    {String confirmText = 'حذف'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// انتخاب تاریخ شمسی (روز / ماه / سال)
Future<DateTime?> pickJalaliDate(BuildContext context, DateTime initial) async {
  final j0 = Jalali.fromDateTime(initial);
  final nowYear = Jalali.now().year;
  var y = j0.year;
  var m = j0.month;
  var d = j0.day;
  final years = <int>{
    for (var i = nowYear - 5; i <= nowYear + 10; i++) i,
    y,
  }.toList()
    ..sort();

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final len = Jalali(y, m, 1).monthLength;
        if (d > len) d = len;
        return AlertDialog(
          title: const Text('انتخاب تاریخ'),
          content: Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: d,
                  items: [
                    for (var i = 1; i <= len; i++)
                      DropdownMenuItem(value: i, child: Text(toFa(i))),
                  ],
                  onChanged: (v) => setS(() => d = v ?? d),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: m,
                  items: [
                    for (var i = 1; i <= 12; i++)
                      DropdownMenuItem(
                          value: i, child: Text(kJalaliMonths[i - 1])),
                  ],
                  onChanged: (v) => setS(() => m = v ?? m),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: y,
                  items: [
                    for (final i in years)
                      DropdownMenuItem(value: i, child: Text(toFa(i))),
                  ],
                  onChanged: (v) => setS(() => y = v ?? y),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, Jalali(y, m, d).toDateTime()),
              child: const Text('تایید'),
            ),
          ],
        );
      },
    ),
  );
}

/// فیلد تاریخ که با لمس، انتخابگر شمسی را باز می‌کند
class DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await pickJalaliDate(context, value);
        if (d != null) onChanged(dateOnly(d));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_month_outlined),
        ),
        child: Text('${fmtDate(value)}  (${relativeDays(value)})'),
      ),
    );
  }
}

class MonthSwitcher extends StatelessWidget implements PreferredSizeWidget {
  const MonthSwitcher({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'ماه قبل',
            onPressed: () => app.shiftMonth(-1),
            icon: const Icon(Icons.chevron_right),
          ),
          TextButton(
            onPressed: app.isCurrentMonth ? null : app.goToToday,
            child: Text(
              fmtMonthYear(app.year, app.month),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          IconButton(
            tooltip: 'ماه بعد',
            onPressed: () => app.shiftMonth(1),
            icon: const Icon(Icons.chevron_left),
          ),
        ],
      ),
    );
  }
}

/// ردیف یک تراکنش
class TransactionTile extends StatelessWidget {
  final TransactionItem tx;
  final VoidCallback? onTap;
  const TransactionTile(this.tx, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final cat = app.categoryById(tx.categoryId);
    final color = tx.isIncome ? kIncomeColor : kExpenseColor;
    final hasNecessity = !tx.isIncome &&
        tx.necessity > 0 &&
        tx.necessity < kNecessityLabels.length;
    final sub = [
      fmtDate(tx.date),
      if (hasNecessity) kNecessityLabels[tx.necessity],
      if (tx.note.isNotEmpty) tx.note,
    ].join(' • ');
    return ListTile(
      onTap: onTap,
      leading: CatAvatar(cat),
      title: Text(cat?.name ?? 'بدون دسته'),
      subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '${tx.isIncome ? '+' : '−'}${fmtNum(tx.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// نوار پیشرفت با رنگ هشداردهنده
class BudgetBar extends StatelessWidget {
  final int spent;
  final int budget;
  const BudgetBar({super.key, required this.spent, required this.budget});

  @override
  Widget build(BuildContext context) {
    final ratio = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);
    final color = budgetColor(spent, budget);
    return LinearProgressIndicator(
      value: ratio,
      minHeight: 8,
      borderRadius: BorderRadius.circular(4),
      color: color,
      backgroundColor: color.withValues(alpha: 0.15),
    );
  }
}

/// رنگ وضعیت مصرف بودجه: سبز، نارنجی (بالای ۹۰٪)، قرمز (عبور از سقف)
Color budgetColor(int spent, int budget) {
  if (budget <= 0) return kIncomeColor;
  if (spent > budget) return kExpenseColor;
  return spent >= budget * 0.9 ? Colors.orange : kIncomeColor;
}

class DonutSlice {
  final double value;
  final Color color;
  const DonutSlice(this.value, this.color);
}

/// نمودار دایره‌ای (حلقه‌ای) با متن وسط
class DonutChart extends StatelessWidget {
  final List<DonutSlice> slices;
  final String centerLabel;
  final String centerValue;
  final double size;
  const DonutChart({
    super.key,
    required this.slices,
    required this.centerLabel,
    required this.centerValue,
    this.size = 190,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(slices),
          ),
          SizedBox(
            width: size - 70,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  Text(
                    centerValue,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  _DonutPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return;
    const stroke = 26.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final gap = slices.length > 1 ? 0.03 : 0.0;
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = 2 * math.pi * s.value / total;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = s.color;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(sweep - gap, 0.001),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.slices != slices;
}
