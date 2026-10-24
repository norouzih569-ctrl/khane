import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../forms.dart';
import '../widgets.dart';
import 'plans_extra.dart';

class PlansPage extends StatelessWidget {
  const PlansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'اقساط'),
              Tab(text: 'یادآورها'),
              Tab(text: 'تکراری'),
              Tab(text: 'اهداف'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _InstallmentsTab(),
                _RemindersTab(),
                RecurringTab(),
                GoalsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _dueColor(BuildContext context, DateTime due) {
  final n = daysUntil(due);
  if (n < 0) return kExpenseColor;
  if (n <= 3) return Colors.orange.shade800;
  return Theme.of(context).colorScheme.onSurfaceVariant;
}

// ---------------------------------------------------------------- اقساط

class _InstallmentsTab extends StatelessWidget {
  const _InstallmentsTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final list = app.installments;
    final active = list.where((i) => !i.finished).toList();
    final monthly = active.fold(0, (a, i) => a + i.amount);
    final remaining = active.fold(0, (a, i) => a + i.remainingAmount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (active.isNotEmpty)
          SectionCard(
            child: Column(
              children: [
                KeyValueRow('جمع اقساط ماهانه', fmtMoney(monthly), bold: true),
                KeyValueRow('کل بدهی باقی‌مانده', fmtMoney(remaining)),
              ],
            ),
          ),
        FilledButton.tonalIcon(
          onPressed: () => showInstallmentSheet(context),
          icon: const Icon(Icons.add),
          label: const Text('افزودن قسط'),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const EmptyHint('قسطی ثبت نشده', icon: Icons.credit_card),
        if (app.gridView)
          _InstallmentGrid(list)
        else
          for (final i in list) _InstallmentCard(i),
      ],
    );
  }
}

class _InstallmentCard extends StatelessWidget {
  final Installment inst;
  const _InstallmentCard(this.inst);

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final progress = inst.totalCount == 0 ? 0.0 : inst.paidCount / inst.totalCount;
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
                    inst.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Text(fmtMoney(inst.amount)),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Text(
              '${toFa(inst.paidCount)} قسط از ${toFa(inst.totalCount)} پرداخت شده'
              '${inst.finished ? '' : ' • باقی‌مانده ${fmtMoney(inst.remainingAmount)}'}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            if (inst.finished)
              const Row(
                children: [
                  Icon(Icons.check_circle, color: kIncomeColor, size: 18),
                  SizedBox(width: 6),
                  Text('تسویه شد', style: TextStyle(color: kIncomeColor)),
                ],
              )
            else
              Row(
                children: [
                  Icon(Icons.event, size: 18, color: _dueColor(context, inst.nextDue)),
                  const SizedBox(width: 6),
                  Text(
                    'سررسید: ${fmtDate(inst.nextDue)} (${relativeDays(inst.nextDue)})',
                    style: TextStyle(color: _dueColor(context, inst.nextDue)),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!inst.finished)
                  FilledButton.icon(
                    onPressed: () async {
                      final ok = await confirmDialog(
                        context,
                        'قسط ${toFa(inst.paidCount + 1)} به مبلغ ${fmtMoney(inst.amount)} پرداخت شد و به‌عنوان هزینه ثبت شود؟',
                        confirmText: 'ثبت پرداخت',
                      );
                      if (ok) await app.payInstallment(inst);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('پرداخت شد'),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'ویرایش',
                  onPressed: () => showInstallmentSheet(context, edit: inst),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'حذف',
                  onPressed: () async {
                    final ok = await confirmDialog(
                        context, 'قسط «${inst.title}» حذف شود؟');
                    if (ok) await app.deleteInstallment(inst.id!);
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

// -------------------------------------------------------------- یادآورها

class _RemindersTab extends StatelessWidget {
  const _RemindersTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final open = app.reminders.where((r) => !r.done).toList();
    final done = app.reminders.where((r) => r.done).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        FilledButton.tonalIcon(
          onPressed: () => showReminderSheet(context),
          icon: const Icon(Icons.add_alert_outlined),
          label: const Text('افزودن یادآور'),
        ),
        const SizedBox(height: 12),
        if (open.isEmpty && done.isEmpty)
          const EmptyHint(
            'یادآوری ثبت نشده.\nمثلاً قبض برق، اجاره خانه، بیمه، شهریه...',
            icon: Icons.notifications_none,
          ),
        if (app.gridView)
          _ReminderGrid(open)
        else
          for (final r in open) _ReminderCard(r),
        if (done.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('انجام‌شده‌ها', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (app.gridView)
            _ReminderGrid(done)
          else
            for (final r in done) _ReminderCard(r),
        ],
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final ReminderItem r;
  const _ReminderCard(this.r);

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final sub = <String>[
      fmtDate(r.due),
      if (!r.done) relativeDays(r.due),
      if (r.monthly) 'ماهانه',
      if (r.amount > 0) fmtMoney(r.amount),
    ].join(' • ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: r.done
            ? IconButton(
                tooltip: 'بازگرداندن',
                icon: const Icon(Icons.check_circle, color: kIncomeColor),
                onPressed: () => app.reopenReminder(r),
              )
            : IconButton(
                tooltip: 'انجام شد',
                icon: const Icon(Icons.radio_button_unchecked),
                onPressed: () => app.completeReminder(r),
              ),
        title: Text(
          r.title,
          style: TextStyle(
            decoration: r.done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          sub,
          style: TextStyle(color: r.done ? null : _dueColor(context, r.due)),
        ),
        onTap: () => showReminderSheet(context, edit: r),
        trailing: IconButton(
          tooltip: 'حذف',
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final ok = await confirmDialog(context, 'یادآور «${r.title}» حذف شود؟');
            if (ok) await app.deleteReminder(r.id!);
          },
        ),
      ),
    );
  }
}

// ======================================================================
// نمایش شبکه‌ای اقساط و یادآورها
// ======================================================================

const SliverGridDelegateWithFixedCrossAxisCount _planGridDelegate =
    SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 8,
  crossAxisSpacing: 8,
  mainAxisExtent: 148,
);

class _InstallmentGrid extends StatelessWidget {
  final List<Installment> list;
  const _InstallmentGrid(this.list);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: _planGridDelegate,
      itemCount: list.length,
      itemBuilder: (ctx, i) => _InstallmentGridCard(list[i]),
    );
  }
}

class _InstallmentGridCard extends StatelessWidget {
  final Installment inst;
  const _InstallmentGridCard(this.inst);

  @override
  Widget build(BuildContext context) {
    final progress =
        inst.totalCount == 0 ? 0.0 : inst.paidCount / inst.totalCount;
    final dueColor = _dueColor(context, inst.nextDue);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => _InstallmentSheet(inst: inst, parentContext: context),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                inst.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  fmtMoney(inst.amount),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const Spacer(),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 4),
              Text(
                '${toFa(inst.paidCount)} از ${toFa(inst.totalCount)} قسط',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 2),
              if (inst.finished)
                const Text(
                  'تسویه شد',
                  style: TextStyle(fontSize: 12, color: kIncomeColor),
                )
              else
                Text(
                  relativeDays(inst.nextDue),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: dueColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// جزئیات و عملیات یک قسط (در نمایش شبکه‌ای)
class _InstallmentSheet extends StatelessWidget {
  final Installment inst;
  final BuildContext parentContext;
  const _InstallmentSheet({required this.inst, required this.parentContext});

  @override
  Widget build(BuildContext context) {
    final app = parentContext.read<AppState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            inst.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          KeyValueRow('مبلغ هر قسط', fmtMoney(inst.amount)),
          KeyValueRow(
            'پرداخت‌شده',
            '${toFa(inst.paidCount)} از ${toFa(inst.totalCount)}',
          ),
          if (!inst.finished) ...[
            KeyValueRow('باقی‌مانده', fmtMoney(inst.remainingAmount)),
            KeyValueRow(
              'سررسید',
              '${fmtDate(inst.nextDue)} (${relativeDays(inst.nextDue)})',
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (!inst.finished)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final ok = await confirmDialog(
                        parentContext,
                        'قسط ${toFa(inst.paidCount + 1)} به مبلغ ${fmtMoney(inst.amount)} پرداخت شد و به‌عنوان هزینه ثبت شود؟',
                        confirmText: 'ثبت پرداخت',
                      );
                      if (ok) await app.payInstallment(inst);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('پرداخت شد'),
                  ),
                ),
              if (!inst.finished) const SizedBox(width: 8),
              IconButton(
                tooltip: 'ویرایش',
                onPressed: () {
                  Navigator.pop(context);
                  showInstallmentSheet(parentContext, edit: inst);
                },
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'حذف',
                onPressed: () async {
                  Navigator.pop(context);
                  final ok = await confirmDialog(
                    parentContext,
                    'قسط «${inst.title}» حذف شود؟',
                  );
                  if (ok) await app.deleteInstallment(inst.id!);
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

class _ReminderGrid extends StatelessWidget {
  final List<ReminderItem> list;
  const _ReminderGrid(this.list);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 132,
      ),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _ReminderGridCard(list[i]),
    );
  }
}

class _ReminderGridCard extends StatelessWidget {
  final ReminderItem r;
  const _ReminderGridCard(this.r);

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final dueColor = r.done ? null : _dueColor(context, r.due);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showReminderSheet(context, edit: r),
        onLongPress: () async {
          final ok = await confirmDialog(context, 'یادآور «${r.title}» حذف شود؟');
          if (ok) await app.deleteReminder(r.id!);
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () =>
                        r.done ? app.reopenReminder(r) : app.completeReminder(r),
                    child: Icon(
                      r.done
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: r.done ? kIncomeColor : null,
                    ),
                  ),
                  const Spacer(),
                  if (r.monthly)
                    const Icon(Icons.repeat, size: 16),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                r.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: r.done ? TextDecoration.lineThrough : null,
                ),
              ),
              const Spacer(),
              Text(
                r.done ? fmtDate(r.due) : relativeDays(r.due),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dueColor,
                ),
              ),
              if (r.amount > 0)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    fmtMoney(r.amount),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
