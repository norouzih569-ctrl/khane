import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/format.dart';

/// دروازه‌ی قفل: روی کل برنامه می‌نشیند. وقتی برنامه به پس‌زمینه می‌رود و بیش از
/// ۳۰ ثانیه بعد برمی‌گردد (و قفل فعال است)، صفحه‌ی رمز را روی همه‌چیز نشان می‌دهد.
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final app = context.read<AppState>();
    if (state == AppLifecycleState.paused) {
      FocusManager.instance.primaryFocus?.unfocus();
      app.onBackground();
    } else if (state == AppLifecycleState.resumed) {
      app.onResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = context.select<AppState, bool>((a) => a.locked);
    return Stack(
      children: [
        widget.child,
        if (locked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}

// ======================================================================
// صفحه‌ی قفل
// ======================================================================

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _entry = '';
  String? _error;
  int _attempts = 0;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _digit(String d) {
    if (_cooldown > 0 || _entry.length >= 4) return;
    setState(() {
      _entry += d;
      _error = null;
    });
    if (_entry.length == 4) _check();
  }

  void _back() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  void _check() {
    final app = context.read<AppState>();
    if (app.verifyPin(_entry)) {
      app.unlock();
      return;
    }
    _attempts++;
    setState(() {
      _entry = '';
      _error = 'رمز اشتباه است';
    });
    if (_attempts >= 5) {
      _attempts = 0;
      _startCooldown();
    }
  }

  void _startCooldown() {
    setState(() => _cooldown = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) {
          _cooldown = 0;
          _error = null;
          t.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: scheme.primary),
                const SizedBox(height: 12),
                const Text(
                  'خرج خانه',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _cooldown > 0
                      ? 'چند بار رمز اشتباه وارد شد؛ ${toFa(_cooldown)} ثانیه صبر کنید'
                      : (_error ?? 'رمز ۴ رقمی را وارد کنید'),
                  style: TextStyle(
                    color: (_error != null || _cooldown > 0)
                        ? scheme.error
                        : Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 24),
                PinPad(
                  entry: _entry,
                  onDigit: _digit,
                  onBackspace: _back,
                  enabled: _cooldown == 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// صفحه‌کلید عددی رمز
// ======================================================================

class PinPad extends StatelessWidget {
  final String entry;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;
  const PinPad({
    super.key,
    required this.entry,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < entry.length ? scheme.primary : Colors.transparent,
                  border: Border.all(color: scheme.primary, width: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final k in row) _key(context, k)],
          ),
      ],
    );
  }

  Widget _key(BuildContext context, String k) {
    if (k.isEmpty) return const SizedBox(width: 80, height: 80);
    final isBack = k == '<';
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? () => isBack ? onBackspace() : onDigit(k) : null,
            child: Center(
              child: isBack
                  ? const Icon(Icons.backspace_outlined)
                  : Text(toFa(k), style: const TextStyle(fontSize: 24)),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// فعال‌سازی / تغییر / برداشتن رمز
// ======================================================================

enum PinMode { enable, change, disable }

class PinSetupPage extends StatefulWidget {
  final PinMode mode;
  const PinSetupPage({super.key, required this.mode});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  late int _step; // 0 تایید رمز فعلی، 1 رمز جدید، 2 تکرار رمز جدید
  String _entry = '';
  String? _first;
  String? _error;

  @override
  void initState() {
    super.initState();
    _step = widget.mode == PinMode.enable ? 1 : 0;
  }

  String get _title {
    switch (_step) {
      case 0:
        return 'رمز فعلی را وارد کنید';
      case 1:
        return 'یک رمز ۴ رقمی انتخاب کنید';
      default:
        return 'رمز را دوباره وارد کنید';
    }
  }

  String get _pageTitle {
    switch (widget.mode) {
      case PinMode.enable:
        return 'فعال‌سازی قفل برنامه';
      case PinMode.change:
        return 'تغییر رمز';
      case PinMode.disable:
        return 'برداشتن قفل';
    }
  }

  void _digit(String d) {
    if (_entry.length >= 4) return;
    setState(() {
      _entry += d;
      _error = null;
    });
    if (_entry.length == 4) {
      Future<void>.delayed(const Duration(milliseconds: 150), _submit);
    }
  }

  void _back() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _submit() async {
    if (!mounted || _entry.length != 4) return;
    final app = context.read<AppState>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final e = _entry;

    if (_step == 0) {
      if (!app.verifyPin(e)) {
        setState(() {
          _entry = '';
          _error = 'رمز اشتباه است';
        });
        return;
      }
      if (widget.mode == PinMode.disable) {
        await app.clearPin();
        nav.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('قفل برنامه برداشته شد')),
        );
        return;
      }
      setState(() {
        _step = 1;
        _entry = '';
      });
    } else if (_step == 1) {
      setState(() {
        _first = e;
        _step = 2;
        _entry = '';
      });
    } else {
      if (e != _first) {
        setState(() {
          _entry = '';
          _first = null;
          _step = 1;
          _error = 'دو رمز یکسان نبود؛ دوباره رمز جدید را وارد کنید';
        });
        return;
      }
      final saved = await app.setPin(e);
      if (!saved) {
        // ذخیره‌ی رمز ممکن نشد؛ قفلی فعال نشده است
        if (!mounted) return;
        setState(() {
          _entry = '';
          _first = null;
          _step = 1;
          _error = 'ذخیره‌ی رمز ممکن نشد؛ دوباره تلاش کنید';
        });
        return;
      }
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.mode == PinMode.enable
                ? 'قفل برنامه فعال شد'
                : 'رمز تغییر کرد',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_pageTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? ' ',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error),
                ),
                const SizedBox(height: 16),
                PinPad(entry: _entry, onDigit: _digit, onBackspace: _back),
                if (widget.mode != PinMode.disable && _step == 1) ...[
                  const SizedBox(height: 24),
                  Text(
                    'اگر رمز را فراموش کنید، تنها راه ورود، پاک کردن اطلاعات برنامه است. '
                    'پس رمز را جایی یادداشت کنید.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
