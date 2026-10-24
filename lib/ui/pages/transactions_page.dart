import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../forms.dart';
import '../widgets.dart';

class _DayGroup {
  final DateTime day;
  final List<TransactionItem> items = [];
  _DayGroup(this.day);
}

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  int _filter = 0; // 0 همه، 1 درآمد، 2 هزینه

  // جستجو (در همه‌ی ماه‌ها)
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  List<TransactionItem> _results = [];
  bool _searching = false;
  int _searchSeq = 0;

  bool get _inSearch => _query.trim().isNotEmpty;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final q = _query.trim();
    final seq = ++_searchSeq;
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    final app = context.read<AppState>();
    setState(() => _searching = true);
    final r = await app.searchTransactions(q);
    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _results = r;
      _searching = false;
    });
  }

  Future<void> _open(TransactionItem t) async {
    await openTransactionForm(context, edit: t);
    if (_inSearch && mounted) await _runSearch();
  }

  Future<void> _delete(AppState app, TransactionItem t) async {
    if (_inSearch) {
      setState(() => _results.removeWhere((x) => x.id == t.id));
    }
    await app.deleteTransaction(t.id!);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final source = _inSearch ? _results : app.txs;
    final list = source.where((t) {
      if (_filter == 1) return t.isIncome;
      if (_filter == 2) return !t.isIncome;
      return true;
    }).toList();

    // گروه‌بندی بر اساس روز (لیست از قبل به ترتیب تاریخ نزولی است)
    final groups = <_DayGroup>[];
    for (final t in list) {
      final day = dateOnly(t.date);
      if (groups.isEmpty || groups.last.day != day) groups.add(_DayGroup(day));
      groups.last.items.add(t);
    }

    Widget body;
    if (list.isEmpty) {
      if (_inSearch) {
        body = _searching
            ? const Center(child: CircularProgressIndicator())
            : const EmptyHint('نتیجه‌ای پیدا نشد', icon: Icons.search_off);
      } else {
        body = const EmptyHint('تراکنشی برای این ماه ثبت نشده');
      }
    } else {
      body = app.gridView
          ? _buildGrid(context, app, groups)
          : _buildCards(context, app, groups);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onChanged: (v) {
              _query = v;
              _runSearch();
            },
            decoration: InputDecoration(
              hintText: 'جستجو در همه ماه‌ها (توضیح، دسته یا مبلغ)',
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchCtrl.clear();
                        _query = '';
                        _runSearch();
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              for (final e in const [
                (0, 'همه'),
                (1, 'درآمد'),
                (2, 'هزینه'),
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(e.$2),
                    selected: _filter == e.$1,
                    onSelected: (_) => setState(() => _filter = e.$1),
                  ),
                ),
              const Spacer(),
              if (_inSearch && !_searching)
                Text(
                  '${toFa(list.length)} نتیجه',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _dayHeader(BuildContext context, DateTime day) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          fmtDate(day),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

  // ------------------------------------------------------------ نمایش کارتی
  Widget _buildCards(
    BuildContext context,
    AppState app,
    List<_DayGroup> groups,
  ) {
    final children = <Widget>[];
    for (final g in groups) {
      children.add(_dayHeader(context, g.day));
      for (final t in g.items) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Dismissible(
                key: ValueKey('tx${t.id}'),
                background: _dismissBg(AlignmentDirectional.centerStart),
                secondaryBackground: _dismissBg(AlignmentDirectional.centerEnd),
                confirmDismiss: (_) =>
                    confirmDialog(context, 'این تراکنش حذف شود؟'),
                onDismissed: (_) => _delete(app, t),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: TransactionTile(t, onTap: () => _open(t)),
                ),
              ),
            ),
          ),
        );
      }
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: children,
    );
  }

  Widget _dismissBg(AlignmentGeometry alignment) => Container(
        color: kExpenseColor,
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      );

  // ---------------------------------------------------------- نمایش شبکه‌ای
  Widget _buildGrid(
    BuildContext context,
    AppState app,
    List<_DayGroup> groups,
  ) {
    final slivers = <Widget>[];
    for (final g in groups) {
      slivers.add(SliverToBoxAdapter(child: _dayHeader(context, g.day)));
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 112,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final t = g.items[i];
                return _TxGridCard(
                  tx: t,
                  onTap: () => _open(t),
                  onLongPress: () async {
                    final ok =
                        await confirmDialog(context, 'این تراکنش حذف شود؟');
                    if (ok) await _delete(app, t);
                  },
                );
              },
              childCount: g.items.length,
            ),
          ),
        ),
      );
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 96)));
    return CustomScrollView(slivers: slivers);
  }
}

class _TxGridCard extends StatelessWidget {
  final TransactionItem tx;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _TxGridCard({
    required this.tx,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final cat = app.categoryById(tx.categoryId);
    final color = tx.isIncome ? kIncomeColor : kExpenseColor;
    final hasNecessity = !tx.isIncome &&
        tx.necessity > 0 &&
        tx.necessity < kNecessityLabels.length;
    final sub = [
      if (hasNecessity) kNecessityLabels[tx.necessity],
      if (tx.note.isNotEmpty) tx.note,
    ].join(' • ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CatAvatar(cat, radius: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cat?.name ?? 'بدون دسته',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${tx.isIncome ? '+' : '−'}${fmtNum(tx.amount)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub.isEmpty ? 'تومان' : sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
