import 'package:flutter/services.dart';
import 'package:shamsi_date/shamsi_date.dart';

const List<String> kJalaliMonths = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

/// اعداد انگلیسی -> فارسی
String toFa(Object v) {
  const en = '0123456789';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in v.toString().split('')) {
    final i = en.indexOf(ch);
    b.write(i >= 0 ? fa[i] : ch);
  }
  return b.toString();
}

/// اعداد فارسی/عربی -> انگلیسی
String toEn(String s) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    var i = fa.indexOf(ch);
    if (i < 0) i = ar.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return b.toString();
}

String groupDigits(int n) {
  final neg = n < 0;
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return (neg ? '-' : '') + b.toString();
}

String fmtNum(int n) => toFa(groupDigits(n));
String fmtMoney(int n) => '${fmtNum(n)} تومان';

String _trim1(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return toFa(s.replaceAll('.', '٫'));
}

/// نمایش کوتاه مبلغ برای برچسب نمودار
String fmtCompact(int n) {
  final a = n.abs();
  if (a >= 1000000000) return '${_trim1(n / 1000000000)} میلیارد';
  if (a >= 1000000) return '${_trim1(n / 1000000)} میلیون';
  if (a >= 1000) return '${_trim1(n / 1000)} هزار';
  return toFa(n);
}

int parseMoney(String text) {
  final digits = toEn(text).replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.tryParse(digits.length > 13 ? digits.substring(0, 13) : digits) ??
      0;
}

String moneyText(int n) => n <= 0 ? '' : fmtNum(n);

class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final n = parseMoney(newValue.text);
    if (n == 0) return const TextEditingValue(text: '');
    final text = fmtNum(n);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// ---------- تاریخ شمسی ----------

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String fmtDate(DateTime d) {
  final j = Jalali.fromDateTime(d);
  return '${toFa(j.day)} ${kJalaliMonths[j.month - 1]} ${toFa(j.year)}';
}

String fmtMonthYear(int year, int month) =>
    '${kJalaliMonths[month - 1]} ${toFa(year)}';

Jalali addJalaliMonths(Jalali j, int n) {
  final total = j.year * 12 + (j.month - 1) + n;
  final y = total ~/ 12;
  final m = total % 12 + 1;
  final len = Jalali(y, m, 1).monthLength;
  return Jalali(y, m, j.day > len ? len : j.day);
}

DateTime addMonthsDt(DateTime d, int n) =>
    addJalaliMonths(Jalali.fromDateTime(d), n).toDateTime();

DateTime monthStart(int y, int m) => Jalali(y, m, 1).toDateTime();

DateTime nextMonthStart(int y, int m) =>
    addJalaliMonths(Jalali(y, m, 1), 1).toDateTime();

int monthLengthOf(int y, int m) => Jalali(y, m, 1).monthLength;

int daysUntil(DateTime d) =>
    dateOnly(d).difference(dateOnly(DateTime.now())).inDays;

String relativeDays(DateTime d) {
  final n = daysUntil(d);
  if (n == 0) return 'امروز';
  if (n == 1) return 'فردا';
  if (n == -1) return 'دیروز';
  if (n > 0) return '${toFa(n)} روز دیگر';
  return '${toFa(-n)} روز پیش';
}
