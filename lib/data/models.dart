import 'package:flutter/material.dart';

/// آیکون‌های قابل انتخاب برای دسته‌ها (به‌صورت اندیس ذخیره می‌شود)
const List<IconData> kIcons = [
  Icons.set_meal, // 0
  Icons.rice_bowl, // 1
  Icons.bakery_dining, // 2
  Icons.local_grocery_store, // 3
  Icons.medical_services, // 4
  Icons.credit_card, // 5
  Icons.receipt_long, // 6
  Icons.home, // 7
  Icons.directions_car, // 8
  Icons.flight, // 9
  Icons.movie, // 10
  Icons.checkroom, // 11
  Icons.school, // 12
  Icons.more_horiz, // 13
  Icons.payments, // 14
  Icons.work, // 15
  Icons.savings, // 16
  Icons.card_giftcard, // 17
  Icons.child_care, // 18
  Icons.pets, // 19
  Icons.phone_android, // 20
  Icons.local_gas_station, // 21
  Icons.cleaning_services, // 22
  Icons.fitness_center, // 23
  Icons.coffee, // 24
  Icons.restaurant, // 25
  Icons.shopping_cart, // 26
  Icons.water_drop, // 27
  Icons.bolt, // 28
  Icons.build, // 29
];

const List<int> kColors = [
  0xFFE53935,
  0xFFFB8C00,
  0xFFFDD835,
  0xFF43A047,
  0xFF00897B,
  0xFF039BE5,
  0xFF3949AB,
  0xFF8E24AA,
  0xFFD81B60,
  0xFF6D4C41,
  0xFF546E7A,
];

IconData iconOf(int i) => (i >= 0 && i < kIcons.length) ? kIcons[i] : Icons.category;

class Category {
  final int? id;
  final String name;
  final int icon;
  final int color;
  final bool isIncome;

  /// سقف ماهانه (تومان)؛ ۰ یعنی بدون سقف
  final int budget;

  const Category({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.isIncome,
    this.budget = 0,
  });

  Category copyWith({int? budget}) => Category(
        id: id,
        name: name,
        icon: icon,
        color: color,
        isIncome: isIncome,
        budget: budget ?? this.budget,
      );

  Map<String, Object?> toMap() => {
        'name': name,
        'icon': icon,
        'color': color,
        'is_income': isIncome ? 1 : 0,
        'budget': budget,
      };

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int,
        name: m['name'] as String,
        icon: m['icon'] as int,
        color: m['color'] as int,
        isIncome: (m['is_income'] as int) == 1,
        budget: m['budget'] as int,
      );
}

class TransactionItem {
  final int? id;
  final bool isIncome;
  final int amount;
  final int? categoryId;
  final String note;
  final DateTime date;

  /// فقط برای هزینه‌ها: 0 تعیین‌نشده، 1 ضروری، 2 غیرضروری
  final int necessity;

  const TransactionItem({
    this.id,
    required this.isIncome,
    required this.amount,
    this.categoryId,
    this.note = '',
    required this.date,
    this.necessity = 0,
  });

  Map<String, Object?> toMap() => {
        'is_income': isIncome ? 1 : 0,
        'amount': amount,
        'category_id': categoryId,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'necessity': necessity,
      };

  factory TransactionItem.fromMap(Map<String, Object?> m) => TransactionItem(
        id: m['id'] as int,
        isIncome: (m['is_income'] as int) == 1,
        amount: m['amount'] as int,
        categoryId: m['category_id'] as int?,
        note: (m['note'] as String?) ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        necessity: (m['necessity'] as int?) ?? 0,
      );
}

class Installment {
  final int? id;
  final String title;
  final int amount; // مبلغ هر قسط
  final int totalCount;
  final int paidCount;
  final DateTime nextDue;
  final int remindDays; // چند روز قبل از سررسید یادآوری شود

  const Installment({
    this.id,
    required this.title,
    required this.amount,
    required this.totalCount,
    this.paidCount = 0,
    required this.nextDue,
    this.remindDays = 2,
  });

  bool get finished => paidCount >= totalCount;
  int get remainingCount => totalCount - paidCount;
  int get remainingAmount => remainingCount * amount;

  Installment copyWith({int? paidCount, DateTime? nextDue}) => Installment(
        id: id,
        title: title,
        amount: amount,
        totalCount: totalCount,
        paidCount: paidCount ?? this.paidCount,
        nextDue: nextDue ?? this.nextDue,
        remindDays: remindDays,
      );

  Map<String, Object?> toMap() => {
        'title': title,
        'amount': amount,
        'total_count': totalCount,
        'paid_count': paidCount,
        'next_due': nextDue.millisecondsSinceEpoch,
        'remind_days': remindDays,
      };

  factory Installment.fromMap(Map<String, Object?> m) => Installment(
        id: m['id'] as int,
        title: m['title'] as String,
        amount: m['amount'] as int,
        totalCount: m['total_count'] as int,
        paidCount: m['paid_count'] as int,
        nextDue: DateTime.fromMillisecondsSinceEpoch(m['next_due'] as int),
        remindDays: m['remind_days'] as int,
      );
}

class ReminderItem {
  final int? id;
  final String title;
  final int amount; // اختیاری؛ ۰ یعنی بدون مبلغ
  final DateTime due;
  final bool monthly;
  final bool done;
  final int remindDays;

  const ReminderItem({
    this.id,
    required this.title,
    this.amount = 0,
    required this.due,
    this.monthly = false,
    this.done = false,
    this.remindDays = 1,
  });

  ReminderItem copyWith({DateTime? due, bool? done}) => ReminderItem(
        id: id,
        title: title,
        amount: amount,
        due: due ?? this.due,
        monthly: monthly,
        done: done ?? this.done,
        remindDays: remindDays,
      );

  Map<String, Object?> toMap() => {
        'title': title,
        'amount': amount,
        'due': due.millisecondsSinceEpoch,
        'monthly': monthly ? 1 : 0,
        'done': done ? 1 : 0,
        'remind_days': remindDays,
      };

  factory ReminderItem.fromMap(Map<String, Object?> m) => ReminderItem(
        id: m['id'] as int,
        title: m['title'] as String,
        amount: m['amount'] as int,
        due: DateTime.fromMillisecondsSinceEpoch(m['due'] as int),
        monthly: (m['monthly'] as int) == 1,
        done: (m['done'] as int) == 1,
        remindDays: m['remind_days'] as int,
      );
}

class MonthTotals {
  final int year;
  final int month;
  final int income;
  final int expense;
  const MonthTotals(this.year, this.month, this.income, this.expense);
}

/// مورد پیش‌رو (قسط یا یادآور) برای نمایش در صفحه اصلی
class UpcomingItem {
  final String title;
  final int amount;
  final DateTime due;
  final bool isInstallment;
  const UpcomingItem(this.title, this.amount, this.due, this.isInstallment);
}

/// جمع مبالغ یک لیست تراکنش به تفکیک دسته؛ کلید -1 یعنی بدون دسته
Map<int, int> sumByCategoryOf(List<TransactionItem> list,
    {required bool income}) {
  final m = <int, int>{};
  for (final t in list) {
    if (t.isIncome != income) continue;
    final k = t.categoryId ?? -1;
    m[k] = (m[k] ?? 0) + t.amount;
  }
  return m;
}

const List<String> kNecessityLabels = ['تعیین‌نشده', 'ضروری', 'غیرضروری'];

/// جمع هزینه‌ها به تفکیک نوع: [تعیین‌نشده، ضروری، غیرضروری]
List<int> necessityTotalsOf(List<TransactionItem> list) {
  final r = [0, 0, 0];
  for (final t in list) {
    if (t.isIncome) continue;
    final k = (t.necessity >= 0 && t.necessity <= 2) ? t.necessity : 0;
    r[k] += t.amount;
  }
  return r;
}

/// هدف پس‌انداز (مثلاً خرید یخچال)
class Goal {
  final int? id;
  final String title;
  final int target;
  final int saved;
  final DateTime? due;

  const Goal({
    this.id,
    required this.title,
    required this.target,
    this.saved = 0,
    this.due,
  });

  bool get reached => saved >= target;
  int get remaining => target > saved ? target - saved : 0;

  Goal copyWith({int? saved}) => Goal(
        id: id,
        title: title,
        target: target,
        saved: saved ?? this.saved,
        due: due,
      );

  Map<String, Object?> toMap() => {
        'title': title,
        'target': target,
        'saved': saved,
        'due': due?.millisecondsSinceEpoch,
      };

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: m['id'] as int,
        title: m['title'] as String,
        target: m['target'] as int,
        saved: m['saved'] as int,
        due: m['due'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['due'] as int),
      );
}

/// تراکنش تکراری ماهانه (حقوق، اجاره و ...)
class RecurringItem {
  final int? id;
  final bool isIncome;
  final int amount;
  final int? categoryId;
  final String note;
  final int day; // روز ماه شمسی (۱ تا ۳۱)
  final DateTime nextDate;
  final int necessity;
  final bool active;

  const RecurringItem({
    this.id,
    required this.isIncome,
    required this.amount,
    this.categoryId,
    this.note = '',
    required this.day,
    required this.nextDate,
    this.necessity = 0,
    this.active = true,
  });

  RecurringItem copyWith({DateTime? nextDate, bool? active}) => RecurringItem(
        id: id,
        isIncome: isIncome,
        amount: amount,
        categoryId: categoryId,
        note: note,
        day: day,
        nextDate: nextDate ?? this.nextDate,
        necessity: necessity,
        active: active ?? this.active,
      );

  Map<String, Object?> toMap() => {
        'is_income': isIncome ? 1 : 0,
        'amount': amount,
        'category_id': categoryId,
        'note': note,
        'day': day,
        'next_date': nextDate.millisecondsSinceEpoch,
        'necessity': necessity,
        'active': active ? 1 : 0,
      };

  factory RecurringItem.fromMap(Map<String, Object?> m) => RecurringItem(
        id: m['id'] as int,
        isIncome: (m['is_income'] as int) == 1,
        amount: m['amount'] as int,
        categoryId: m['category_id'] as int?,
        note: (m['note'] as String?) ?? '',
        day: m['day'] as int,
        nextDate: DateTime.fromMillisecondsSinceEpoch(m['next_date'] as int),
        necessity: (m['necessity'] as int?) ?? 0,
        active: (m['active'] as int) == 1,
      );
}
