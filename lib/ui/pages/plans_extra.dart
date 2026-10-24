import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../forms.dart';
import '../widgets.dart';

// ======================================================================
// تب «اهداف» (پس‌انداز)
// ======================================================================

class GoalsTab extends StatelessWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final goals = app.goals;
    final saved = goals.fold(0, (a, g) => a + g.saved);
    final target = goals.fold(0, (a, g) => a + g.target);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (goals.isNotEmpty)
          SectionCard(
            child: Column(
              children: [
                KeyValueRow(
                  'جمع پس‌انداز اهداف',
                  fmtMoney(saved),
                  bold: true,
                  valueColor: kIncomeColor,
                ),
                KeyValueRow('جمع مبلغ هدف‌ها', fmtMoney(target)),
              ],
            ),
          ),
        FilledButton.tonalIcon(
          onPressed: () => showGoalSheet(context),
          icon: const Icon(Icons.add),
          label: const Text('افزودن هدف'),
        ),
        const SizedBox(height: 12),
        if (goals.isEmpty)
          const EmptyHint(
            'هدفی ثبت نشده.\nمثلاً خرید یخچال، سفر تابستان یا پیش‌پرداخت خانه',
            icon: Icons.savings,
          )
        else if (app.gridView)
          _GoalGrid(goals)
        else
          for (final g in goals) _GoalCard(g),
        if (goals.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'مبلغ پس‌اندازشده‌ی اهداف از «مانده ماه» کم نمی‌شود؛ جدا از تراکنش‌هاست.',
              style: TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}

String? _monthlyNeed(Goal g) {
  if (g.reached || g.due == null) return null;
  final days = daysUntil(g.due!);
  if (days <= 0) return 'موعد هدف گذشته است';
  final months = math.max(1, (days / 30).ceil());
  return 'ماهانه حدود ${fmtMoney((g.remaining / months).ceil())} لازم است';
}

double _goalProgress(Goal g) =>
    g.target <= 0 ? 0.0 : (g.saved / g.target).clamp(0.0, 1.0);

class _GoalCard extends StatelessWidget {
  final Goal goal;
  const _GoalCard(this.goal);

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final g = goal;
    final p = _goalProgress(g);
    final need = _monthlyNeed(g);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    g.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  '${toFa((p * 100).round())}٪',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: p,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: g.reached ? kIncomeColor : null,
            ),
            const SizedBox(height: 6),
            Text(
              '${fmtMoney(g.saved)} از ${fmtMoney(g.target)}',
              style: const TextStyle(fontSize: 12),
            ),
            if (g.reached)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: kIncomeColor, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'به هدف رسیدید',
                      style: TextStyle(color: kIncomeColor),
                    ),
                  ],
                ),
              )
            else ...[
              const SizedBox(height: 4),
              Text(
                'باقی‌مانده ${fmtMoney(g.remaining)}',
                style: const TextStyle(fontSize: 12),
              ),
              if (g.due != null)
                Text(
                  'تا ${fmtDate(g.due!)} (${relativeDays(g.due!)})',
                  style: const TextStyle(fontSize: 12),
                ),
              if (need != null)
                Text(
                  need,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () => showGoalAmountDialog(context, g, add: true),
                  icon: const Icon(Icons.add),
                  label: const Text('افزودن'),
                ),
                if (g.saved > 0) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () =>
                        showGoalAmountDialog(context, g, add: false),
                    child: const Text('برداشت'),
                  ),
                ],
                const Spacer(),
                IconButton(
                  tooltip: 'ویرایش',
                  onPressed: () => showGoalSheet(context, edit: g),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'حذف',
                  onPressed: () async {
                    final ok = await confirmDialog(
                      context,
                      'هدف «${g.title}» حذف شود؟',
                    );
                    if (ok) await app.deleteGoal(g.id!);
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalGrid extends StatelessWidget {
  final List<Goal> goals;
  const _GoalGrid(this.goals);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 168,
      ),
      itemCount: goals.length,
      itemBuilder: (ctx, i) => _GoalGridCard(goals[i]),
    );
  }
}

class _GoalGridCard extends StatelessWidget {
  final Goal goal;
  const _GoalGridCard(this.goal);

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final p = _goalProgress(g);
    final color = g.reached ? kIncomeColor : Theme.of(context).colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => _GoalSheet(goal: g, parentContext: context),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: p,
                        strokeWidth: 5,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.15),
                      ),
                    ),
                    Text(
                      '${toFa((p * 100).round())}٪',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                g.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${fmtNum(g.saved)} از ${fmtNum(g.target)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                g.reached
                    ? 'رسیدید'
                    : (g.due != null
                        ? relativeDays(g.due!)
                        : 'باقی: ${fmtCompact(g.remaining)}'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: g.reached ? kIncomeColor : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// جزئیات و عملیات یک هدف (در نمایش شبکه‌ای)
class _GoalSheet extends StatelessWidget {
  final Goal goal;
  final BuildContext parentContext;
  const _GoalSheet({required this.goal, required this.parentContext});

  @override
  Widget build(BuildContext context) {
    final app = parentContext.read<AppState>();
    final g = goal;
    final need = _monthlyNeed(g);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            g.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          KeyValueRow('پس‌انداز فعلی', fmtMoney(g.saved)),
          KeyValueRow('مبلغ هدف', fmtMoney(g.target)),
          if (!g.reached) KeyValueRow('باقی‌مانده', fmtMoney(g.remaining)),
          if (g.due != null)
            KeyValueRow('تاریخ هدف', '${fmtDate(g.due!)} (${relativeDays(g.due!)})'),
          if (need != null) KeyValueRow('پیشنهاد', need),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  showGoalAmountDialog(parentContext, g, add: true);
                },
                icon: const Icon(Icons.add),
                label: const Text('افزودن'),
              ),
              if (g.saved > 0)
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showGoalAmountDialog(parentContext, g, add: false);
                  },
                  child: const Text('برداشت'),
                ),
              IconButton(
                tooltip: 'ویرایش',
                onPressed: () {
                  Navigator.pop(context);
                  showGoalSheet(parentContext, edit: g);
                },
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'حذف',
                onPressed: () async {
                  Navigator.pop(context);
                  final ok = await confirmDialog(
                    parentContext,
                    'هدف «${g.title}» حذف شود؟',
                  );
                  if (ok) await app.deleteGoal(g.id!);
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// تب «تکراری» (تراکنش‌های ماهانه‌ی خودکار)
// ======================================================================

class RecurringTab extends StatelessWidget {
  const RecurringTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final list = app.recurrings;
    final inc = list
        .where((r) => r.active && r.isIncome)
        .fold(0, (a, r) => a + r.amount);
    final exp = list
        .where((r) => r.active && !r.isIncome)
        .fold(0, (a, r) => a + r.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (list.isNotEmpty)
          SectionCard(
            child: Column(
              children: [
                KeyValueRow(
                  'درآمد تکراری ماهانه',
                  fmtMoney(inc),
                  valueColor: kIncomeColor,
                ),
                KeyValueRow(
                  'هزینه تکراری ماهانه',
                  fmtMoney(exp),
                  valueColor: kExpenseColor,
                ),
              ],
            ),
          ),
        FilledButton.tonalIcon(
          onPressed: () => showRecurringSheet(context),
          icon: const Icon(Icons.autorenew),
          label: const Text('افزودن تراکنش تکراری'),
        ),
        const SizedBox(height: 8),
        const Text(
          'مثل حقوق یا اجاره: هر ماه در تاریخ خودش خودکار به تراکنش‌ها اضافه می‌شود.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const EmptyHint(
            'تراکنش تکراری ثبت نشده',
            icon: Icons.autorenew,
          )
        else if (app.gridView)
          _RecurringGrid(list)
        else
          for (final r in list) _RecurringCard(r),
      ],
    );
  }
}

String _recurringTitle(AppState app, RecurringItem r) {
  final cat = app.categoryById(r.categoryId);
  return cat?.name ?? 'بدون دسته';
}

Future<void> _confirmDeleteRecurring(
  BuildContext context,
  AppState app,
  RecurringItem r,
) async {
  final ok = await confirmDialog(
    context,
    'این تراکنش تکراری حذف شود؟ تراکنش‌هایی که قبلاً ثبت شده‌اند می‌مانند.',
  );
  if (ok) await app.deleteRecurring(r.id!);
}

class _RecurringCard extends StatelessWidget {
  final RecurringItem item;
  const _RecurringCard(this.item);

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final r = item;
    final cat = app.categoryById(r.categoryId);
    final color = r.isIncome ? kIncomeColor : kExpenseColor;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            onTap: () => showRecurringSheet(context, edit: r),
            leading: CatAvatar(cat),
            title: Text(
              r.note.isEmpty
                  ? _recurringTitle(app, r)
                  : '${_recurringTitle(app, r)} — ${r.note}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              r.active
                  ? 'هر ماه روز ${toFa(r.day)} • بعدی: ${fmtDate(r.nextDate)}'
                  : 'متوقف شده',
            ),
            trailing: Text(
              '${r.isIncome ? '+' : '−'}${fmtNum(r.amount)}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              children: [
                Switch(
                  value: r.active,
                  onChanged: (_) => app.toggleRecurring(r),
                ),
                Text(r.active ? 'فعال' : 'متوقف'),
                const Spacer(),
                IconButton(
                  tooltip: 'حذف',
                  onPressed: () => _confirmDeleteRecurring(context, app, r),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecurringGrid extends StatelessWidget {
  final List<RecurringItem> list;
  const _RecurringGrid(this.list);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 156,
      ),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _RecurringGridCard(list[i]),
    );
  }
}

class _RecurringGridCard extends StatelessWidget {
  final RecurringItem item;
  const _RecurringGridCard(this.item);

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final r = item;
    final cat = app.categoryById(r.categoryId);
    final color = r.isIncome ? kIncomeColor : kExpenseColor;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showRecurringSheet(context, edit: r),
        onLongPress: () => _confirmDeleteRecurring(context, app, r),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CatAvatar(cat, radius: 16),
                  const Spacer(),
                  Switch(
                    value: r.active,
                    onChanged: (_) => app.toggleRecurring(r),
                  ),
                ],
              ),
              Text(
                _recurringTitle(app, r),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${r.isIncome ? '+' : '−'}${fmtNum(r.amount)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                r.active
                    ? 'روز ${toFa(r.day)} هر ماه'
                    : 'متوقف شده',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
