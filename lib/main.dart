import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:http/http.dart' as http;

import 'data.dart';
import 'excel_service.dart';
import 'extra.dart';

void main() => runApp(const AdminApp());

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FAWORI Admin',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kBg,
          colorScheme: const ColorScheme.dark(
              primary: kOrange, secondary: kTeal, surface: kCard),
        ),
        home: const Gate(),
      );
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  String? _token;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final t = await GH.getToken();
    if (mounted) setState(() { _token = t; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: kOrange)));
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _token == null ? TokenPage(onSaved: _check) : Home(token: _token!),
    );
  }
}

class TokenPage extends StatefulWidget {
  final VoidCallback onSaved;
  const TokenPage({super.key, required this.onSaved});
  @override
  State<TokenPage> createState() => _TokenPageState();
}

class _TokenPageState extends State<TokenPage> {
  final _c = TextEditingController();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: kCard, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kOrange.withAlpha(80))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('لوحة تحكم فاوري',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kOrange)),
              const SizedBox(height: 8),
              Text('تُفتح مرة واحدة فقط ثم يُحفظ التوكن',
                  style: TextStyle(color: Colors.grey.shade400)),
              const SizedBox(height: 20),
              TextField(
                controller: _c, obscureText: true, textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                    hintText: 'ghp_...', filled: true, fillColor: kBg,
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kOrange, foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () async {
                    if (_c.text.trim().isEmpty) return;
                    await GH.saveToken(_c.text.trim());
                    widget.onSaved();
                  },
                  child: const Text('دخول', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
        ),
      );
}

class Home extends StatefulWidget {
  final String token;
  const Home({super.key, required this.token});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _page = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: kCard,
              selectedIndex: _page,
              onDestinationSelected: (i) => setState(() => _page = i),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                    icon: Icon(Icons.people_alt_rounded), label: Text('المستخدمون')),
                NavigationRailDestination(
                    icon: Icon(Icons.receipt_long_rounded), label: Text('الفواتير')),
                NavigationRailDestination(
                    icon: Icon(Icons.redeem_rounded), label: Text('الهدايا')),
                NavigationRailDestination(
                    icon: Icon(Icons.code_rounded), label: Text('الأكواد')),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _page == 0
                  ? UsersPage(token: widget.token)
                  : _page == 1
                      ? InvoicesPage(token: widget.token)
                      : _page == 2
                          ? GiftsPage(token: widget.token)
                          : CodeFilesPage(token: widget.token),
            ),
          ],
        ),
      );
}

// ================= المستخدمون =================
class UsersPage extends StatefulWidget {
  final String token;
  const UsersPage({super.key, required this.token});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!Store.loaded) await Store.load();
    if (mounted) setState(() => _loading = false);
  }

  List<User> get _users => Store.users;

  String _roleLabel(String r) =>
      r == 'agent' ? 'وكيل' : r == 'tech' ? 'صباغ' : r == 'admin' ? 'مدير' : 'عميل';

  Future<void> _delete(User u) async {
    if (!await confirmDialog(context, 'حذف المستخدم "${u.name}"؟')) return;
    Store.users.remove(u);
    setState(() {});
    try {
      await Store.saveUsers(widget.token);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم الحذف والحفظ ✅')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _addPoints(User u) async {
    final c = TextEditingController();
    final n = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        title: Text('نقاط لـ ${u.name}'),
        content: TextField(controller: c, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'عدد النقاط')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kTeal, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, int.tryParse(c.text) ?? 0),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (n == null || n == 0) return;
    u.points += n;
    setState(() {});
    try {
      await Store.saveUsers(widget.token);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('أُضيفت $n نقطة لـ ${u.name} ✅')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _editBalances(User u) async {
    final pts = TextEditingController(text: '${u.points}');
    final stored = TextEditingController(text: '${u.stored}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        title: Text('تعديل رصيد ${u.name}'),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: pts, keyboardType: TextInputType.number,
                style: const TextStyle(color: kInk, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(labelText: 'النقاط')),
            const SizedBox(height: 10),
            TextField(controller: stored, keyboardType: TextInputType.number,
                style: const TextStyle(color: kInk, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(labelText: 'الرصيد المخزن')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ ورفع'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    u.points = int.tryParse(pts.text) ?? u.points;
    u.stored = int.tryParse(stored.text) ?? u.stored;
    setState(() {});
    try {
      await Store.saveUsers(widget.token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تعديل النقاط والرصيد ورفع التغييرات ✅')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('المستخدمون'),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () async {
                  setState(() => _loading = true);
                  await Store.load();
                  if (mounted) setState(() => _loading = false);
                }),
            IconButton(
                icon: const Icon(Icons.person_add_alt_1_rounded),
                onPressed: () async {
                  await showDialog(context: context,
                      builder: (_) => UserDialog(token: widget.token, users: _users));
                  setState(() {});
                }),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: kOrange))
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final u = _users[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: kCard, borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kLine)),
                    child: Row(children: [
                      CircleAvatar(
                          backgroundColor: kOrange.withAlpha(40),
                          child: Text(u.name.isNotEmpty ? u.name[0] : '؟',
                              style: const TextStyle(color: kOrange, fontWeight: FontWeight.w800))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text('${u.phone} • ${_roleLabel(u.role)}',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                            if (u.address.isNotEmpty)
                              Text(u.address,
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(children: [
                        Text(fmt(u.points),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kOrange)),
                        const Text('نقطة', style: TextStyle(color: Colors.grey, fontSize: 10)),
                      ]),
                      const SizedBox(width: 14),
                      Column(children: [
                        Text(fmt(u.stored),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTeal)),
                        const Text('رصيد مخزن', style: TextStyle(color: Colors.grey, fontSize: 10)),
                      ]),
                      const SizedBox(width: 10),
                      IconButton(tooltip: 'إضافة نقاط', icon: const Icon(Icons.add_circle_outline_rounded, color: kTeal, size: 20),
                          onPressed: () => _addPoints(u)),
                      IconButton(tooltip: 'تعديل البيانات', icon: const Icon(Icons.edit_rounded, color: kOrange, size: 18),
                          onPressed: () async {
                            await showDialog(context: context,
                                builder: (_) => UserDialog(token: widget.token, users: _users, user: u));
                            setState(() {});
                          }),
                      IconButton(tooltip: 'تعديل النقاط والرصيد', icon: const Icon(Icons.account_balance_wallet_outlined, color: kTeal, size: 20),
                          onPressed: () => _editBalances(u)),
                      IconButton(tooltip: 'حذف', icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                          onPressed: () => _delete(u)),
                    ]),
                  );
                },
              ),
      );
}

class UserDialog extends StatefulWidget {
  final String token;
  final List<User> users;
  final User? user;
  const UserDialog({super.key, required this.token, required this.users, this.user});
  @override
  State<UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<UserDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.user?.name ?? '');
  late final TextEditingController _phone = TextEditingController(text: widget.user?.phone ?? '');
  late final TextEditingController _pass = TextEditingController(text: widget.user?.password ?? '');
  late final TextEditingController _addr = TextEditingController(text: widget.user?.address ?? '');
  late String _role = widget.user?.role ?? 'customer';
  late String _housing = widget.user?.housing ?? '';
  late String _marital = widget.user?.marital ?? '';
  late String _car = widget.user?.car ?? '';
  bool _busy = false;

  String _displayLabel(String o) {
    switch (o) {
      case 'customer':
        return 'عميل';
      case 'agent':
        return 'وكيل';
      case 'tech':
        return 'صباغ';
      case 'admin':
        return 'مدير';
      default:
        return o;
    }
  }

  Widget _dd(String label, String value, List<String> opts, Function(String) set) =>
      DropdownButtonFormField<String>(
        value: value.isEmpty ? null : value,
        isExpanded: true,
        dropdownColor: kCard,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: opts
            .map((o) => DropdownMenuItem(
                value: o,
                child: Text(_displayLabel(o),
                    style: const TextStyle(fontWeight: FontWeight.w700))))
            .toList(),
        onChanged: (v) => setState(() => set(v ?? '')),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: kCard,
        title: Text(widget.user == null ? 'تسجيل مستخدم جديد' : 'تعديل مستخدم'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم الرباعي')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _phone, keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _pass,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'))),
              ]),
              const SizedBox(height: 8),
              _dd('نوع الحساب', _role, ['customer', 'agent', 'tech'], (v) => _role = v),
              const SizedBox(height: 8),
              TextField(controller: _addr,
                  decoration: const InputDecoration(labelText: 'العنوان (الشارع - نقطة دالة)')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _dd('البيت', _housing, ['ايجار', 'ملك'], (v) => _housing = v)),
                const SizedBox(width: 8),
                Expanded(child: _dd('الحالة الاجتماعية', _marital,
                    ['متزوج', 'اعزب', 'مطلق', 'ارمل'], (v) => _marital = v)),
              ]),
              const SizedBox(height: 8),
              _dd('يملك سيارة؟', _car, ['نعم', 'لا'], (v) => _car = v),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.black),
            onPressed: _busy ? null : _submit,
            child: Text(widget.user == null ? 'تسجيل الدخول للمستخدم' : 'حفظ التعديلات'),
          ),
        ],
      );

  void _submit() async {
    final missing = <String>[];
    if (_name.text.trim().isEmpty) missing.add('الاسم الرباعي');
    if (_phone.text.trim().isEmpty) missing.add('رقم الهاتف');
    if (_pass.text.isEmpty) missing.add('كلمة المرور');
    if (_addr.text.trim().isEmpty) missing.add('العنوان');
    if (_housing.isEmpty) missing.add('البيت (ملك/ايجار)');
    if (_marital.isEmpty) missing.add('الحالة الاجتماعية');
    if (_car.isEmpty) missing.add('تملك سيارة؟');
    if (missing.isNotEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: kCard,
          title: const Text('حقول ناقصة', style: TextStyle(color: Colors.red)),
          content: Text(missing.join('\n')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))
          ],
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      if (widget.user == null) {
        widget.users.add(User(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: _name.text.trim(), phone: _phone.text.trim(),
            password: _pass.text, role: _role, address: _addr.text.trim(),
            housing: _housing, marital: _marital, car: _car));
      } else {
        widget.user!
          ..name = _name.text.trim()
          ..phone = _phone.text.trim()
          ..password = _pass.text
          ..role = _role
          ..address = _addr.text.trim()
          ..housing = _housing
          ..marital = _marital
          ..car = _car;
      }
      await Store.saveUsers(widget.token);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم الحفظ ✅')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _busy = false);
      }
    }
  }
}

// ================= الفواتير =================
class _Draft {
  final TextEditingController name = TextEditingController();
  final TextEditingController price = TextEditingController();
  final TextEditingController qty = TextEditingController(text: '1');
}

class InvoicesPage extends StatefulWidget {
  final String token;
  const InvoicesPage({super.key, required this.token});
  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  bool _loading = true;
  ExcelData? _xl;
  bool _refreshing = false;
  final _invNo = TextEditingController();
  String _fetchedType = '';
  User? _selected;
  String _query = '';
  final List<_Draft> _items = [_Draft()];
  bool _busy = false;

  List<User> get _users => Store.users;
  List<Invoice> get _invs => Store.invoices;

  bool get _isReturn => _fetchedType.contains('مرتجع');

  double get _total => _items.fold<double>(
      0,
      (s, d) =>
          s +
          (double.tryParse(d.price.text) ?? 0) *
              (int.tryParse(d.qty.text) ?? 0));

  int get _tRound => _total.round();
  int get _autoPoints => _tRound ~/ kPointUnit;
  int get _autoStored => _tRound % kPointUnit;

  static const TextStyle _inkBold =
      TextStyle(color: kInk, fontWeight: FontWeight.w800, fontSize: 14);
  static const TextStyle _hintDark =
      TextStyle(color: Color(0xFF7A8699), fontWeight: FontWeight.w600);
  static const TextStyle _inputDark =
      TextStyle(color: kInk, fontWeight: FontWeight.w700);

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!Store.loaded) await Store.load();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final r = await http.get(Uri.parse(
          '$kSite/assets/assets/data/fawori.xlsx?t=${DateTime.now().millisecondsSinceEpoch}'));
      if (r.statusCode != 200) {
        throw Exception('الملف غير موجود — ارفعه أولاً بزر رفع اكسل');
      }
      final data = parseFaworiExcel(r.bodyBytes);
      if (mounted) {
        setState(() => _xl = data);
        _snack('تم التحديث ✅ ${data.invoices.length} فاتورة و ${data.materials.length} مادة فاوري');
      }
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _upload() async {
    final res = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
    if (res == null || res.files.isEmpty) return;
    final bytes = res.files.first.bytes;
    if (bytes == null) return;
    setState(() => _refreshing = true);
    try {
      await GH.putBinary('assets/data/fawori.xlsx', bytes, widget.token);
      final data = parseFaworiExcel(bytes);
      if (mounted) {
        setState(() => _xl = data);
        _snack('تم رفع الملف للمستودع وتحليله ✅');
      }
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _fetch() {
    if (_xl == null) {
      _snack('اضغط زر التحديث 🔄 أولاً لجلب ملف الاكسل');
      return;
    }
    final no = _invNo.text.trim();
    if (no.isEmpty) return;
    final match = _xl!.invoices.where((i) => i.no.trim() == no).toList();
    if (match.isEmpty) {
      _snack('لا توجد فاتورة بالرقم $no');
      return;
    }
    final f = match.first;
    final fawori = f.items.where((it) => _xl!.isFawori(it.code, it.name)).toList();
    setState(() {
      _fetchedType = f.type.isEmpty ? 'مبيع' : f.type;
      _items.clear();
      for (final it in fawori) {
        final d = _Draft();
        d.name.text = it.name;
        d.price.text = it.price == it.price.roundToDouble()
            ? it.price.toStringAsFixed(0)
            : it.price.toStringAsFixed(2);
        d.qty.text = '${it.qty}';
        _items.add(d);
      }
      if (_items.isEmpty) _items.add(_Draft());
    });
    _snack('تم جلب ${fawori.length} مادة فاوري (${_isReturn ? 'مرتجع — تُخصم النقاط' : 'مبيع — تُضاف النقاط'})');
  }

  Future<void> _deleteInv(Invoice inv) async {
    if (!await confirmDialog(context, 'حذف الفاتورة وعكس نقاطها ورصيدها من العميل؟')) return;
    final owner = _users.where((x) => x.id == inv.userId).toList();
    if (owner.isNotEmpty) {
      owner.first.points = (owner.first.points - inv.points).clamp(0, 1000000000);
      owner.first.stored = (owner.first.stored - inv.stored).clamp(0, 1000000000);
    }
    Store.invoices.remove(inv);
    setState(() {});
    try {
      await Store.saveUsers(widget.token);
      await Future.delayed(const Duration(milliseconds: 800));
      await Store.saveInvoices(widget.token);
      if (mounted) _snack('تم الحذف وعكس النقاط والرصيد ✅');
    } catch (e) {
      if (mounted) _snack('Error: $e');
    }
  }

  Future<void> _editInv(Invoice inv) async {
    final isRet = inv.type == 'return' || inv.points < 0;
    final tot = TextEditingController(text: inv.total.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        title: Text('تعديل فاتورة ${isRet ? 'مرتجع' : 'مبيع'}'),
        content: SizedBox(
          width: 320,
          child: TextField(controller: tot, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الإجمالي')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final int t = (double.tryParse(tot.text) ?? inv.total).round();
    final int newPts = t ~/ kPointUnit;
    final int newRem = t % kPointUnit;
    final int dP = newPts - inv.points.abs();
    final int dR = newRem - inv.stored.abs();
    final owner = _users.where((x) => x.id == inv.userId).toList();
    if (owner.isNotEmpty) {
      final o = owner.first;
      if (isRet) {
        o.points = (o.points - dP).clamp(0, 1000000000);
        o.stored = (o.stored - dR).clamp(0, 1000000000);
      } else {
        o.points += dP;
        o.stored += dR;
      }
    }
    inv.total = t.toDouble();
    inv.points = isRet ? -newPts : newPts;
    inv.stored = isRet ? -newRem : newRem;
    setState(() {});
    try {
      await Store.saveUsers(widget.token);
      await Future.delayed(const Duration(milliseconds: 800));
      await Store.saveInvoices(widget.token);
      if (mounted) _snack('تم تعديل الفاتورة وتحديث النقاط والرصيد ✅');
    } catch (e) {
      if (mounted) _snack('Error: $e');
    }
  }

  String _userName(String id) {
    final m = _users.where((u) => u.id == id);
    return m.isEmpty ? '—' : m.first.name;
  }

  Widget _sumRow(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(label, style: _inkBold),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('الفواتير والنقاط'),
          actions: [
            IconButton(
                tooltip: 'رفع ملف اكسل جديد',
                icon: const Icon(Icons.upload_file_rounded),
                onPressed: _refreshing ? null : _upload),
            IconButton(
                tooltip: 'تحديث الملف من المستودع',
                icon: _refreshing
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kTeal))
                    : const Icon(Icons.sync_rounded, color: kTeal),
                onPressed: _refreshing ? null : _refresh),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: kOrange))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _invoiceCard(),
                  const SizedBox(height: 24),
                  const Text('آخر الفواتير',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ...(_invs.reversed.toList()).map((inv) {
                    final neg = inv.points < 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_userName(inv.userId),
                                  style: const TextStyle(
                                      color: kInk,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                              const SizedBox(height: 2),
                              Text('${inv.date}  •  ${neg ? 'مرتجع' : 'مبيع'}  •  رقم ${inv.no.isEmpty ? '—' : inv.no}',
                                  style: TextStyle(
                                      color: Colors.grey.shade600, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(
                                  inv.items.map((e) => '${e.name} ×${e.qty}').join('، '),
                                  style: TextStyle(
                                      color: Colors.grey.shade700, fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(children: [
                          Text(fmt(inv.total),
                              style: const TextStyle(
                                  color: kInk,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: neg
                                    ? Colors.red.withAlpha(30)
                                    : kTeal.withAlpha(30),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(
                                neg ? '${fmt(inv.points)}' : '+${fmt(inv.points)}',
                                style: TextStyle(
                                    color: neg ? Colors.red : kTeal,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12)),
                          ),
                          const SizedBox(height: 4),
                          Text('مخزن: ${fmt(inv.stored)}',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 10)),
                        ]),
                        IconButton(
                            tooltip: 'تعديل',
                            icon: const Icon(Icons.edit_rounded,
                                color: kOrange, size: 18),
                            onPressed: () => _editInv(inv)),
                        IconButton(
                            tooltip: 'حذف',
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.red, size: 18),
                            onPressed: () => _deleteInv(inv)),
                      ]),
                    );
                  }),
                ],
              ),
      );

  Widget _invoiceCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network('$kSite/assets/assets/images/logo.png',
                  width: 74, height: 74, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.store_rounded, size: 50, color: kOrange)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('شركة فاوري',
                    style: TextStyle(color: kInk, fontSize: 20, fontWeight: FontWeight.w900)),
                const Text('Fawori Company',
                    style: TextStyle(color: Color(0xFF7A8699), fontSize: 11)),
                const SizedBox(height: 10),
                Text('فاتورة إلي: ${_selected?.name ?? '..........................'}',
                    style: _inkBold),
                const SizedBox(height: 4),
                Text('رقم الهاتف: ${_selected?.phone ?? '..........................'}',
                    style: _inkBold),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('فـــاتورة',
                  style: TextStyle(color: kInk, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('التاريخ: ${DateTime.now().toString().substring(0, 10)}',
                  style: const TextStyle(color: kInk, fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('رقم الفاتورة: ${_invNo.text.trim().isEmpty ? '————' : _invNo.text.trim()}',
                  style: const TextStyle(color: kInk, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _invNo,
                keyboardType: TextInputType.number,
                style: _inputDark,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'رقم الفاتورة من الاكسل...',
                    labelStyle: _hintDark,
                    hintStyle: _hintDark,
                    filled: true,
                    fillColor: Color(0xFFF4F6F8)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal, foregroundColor: Colors.black),
              onPressed: _fetch,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('جلب', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            if (_fetchedType.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: _isReturn ? Colors.red.withAlpha(30) : Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                    _isReturn ? 'مرتجع — تُخصم النقاط' : 'مبيع — تُضاف النقاط',
                    style: TextStyle(
                        color: _isReturn ? Colors.red : Colors.green.shade700,
                        fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          if (_selected == null) ...[
            TextField(
              onChanged: (v) => setState(() => _query = v),
              style: _inputDark,
              decoration: const InputDecoration(
                  labelText: 'ابحث باسم العميل أو رقمه...',
                  labelStyle: _hintDark,
                  hintStyle: _hintDark,
                  filled: true,
                  fillColor: Color(0xFFF4F6F8)),
            ),
            if (_query.trim().isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 170),
                color: const Color(0xFFF4F6F8),
                child: ListView(
                  shrinkWrap: true,
                  children: _users
                      .where((u) =>
                          u.name.contains(_query) || u.phone.contains(_query))
                      .map((u) => ListTile(
                            dense: true,
                            title: Text(u.name, style: const TextStyle(color: kInk, fontWeight: FontWeight.w700)),
                            subtitle: Text(u.phone, style: const TextStyle(fontSize: 11, color: Color(0xFF7A8699))),
                            onTap: () =>
                                setState(() { _selected = u; _query = ''; }),
                          ))
                      .toList(),
                ),
              ),
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _selected = null),
                child: const Text('تغيير العميل',
                    style: TextStyle(color: kInk, fontWeight: FontWeight.w800)),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            color: kOrange,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: const [
              SizedBox(width: 30, child: Center(child: Text('NO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 11)))),
              Expanded(child: Center(child: Text('اسم الصنف', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)))),
              SizedBox(width: 70, child: Center(child: Text('سعر القطعة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 10)))),
              SizedBox(width: 46, child: Center(child: Text('العدد', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 11)))),
              SizedBox(width: 70, child: Center(child: Text('المجموع', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 11)))),
            ]),
          ),
          ...List.generate(_items.length, (i) => _row(i, _items[i])),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _items.add(_Draft())),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('إضافة خانة',
                  style: TextStyle(color: kInk, fontWeight: FontWeight.w800)),
            ),
          ),
          const Divider(),
          _sumRow('التكلفة الإجمالية', fmt(_tRound), kInk),
          _sumRow(
              _isReturn ? 'نقاط تُخصم من الفاتورة' : 'نقاط من الفاتورة',
              _isReturn ? '-${fmt(_autoPoints)}' : '+${fmt(_autoPoints)}',
              kTeal),
          _sumRow('رصيد مخزن من الفاتورة', fmt(_autoStored), kInk),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _isReturn ? Colors.red : kOrange,
                  foregroundColor: _isReturn ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      _isReturn
                          ? 'حفظ المرتجع (خصم النقاط)'
                          : 'حفظ الفاتورة (إضافة النقاط)',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );

  Widget _row(int i, _Draft d) {
    final double price = double.tryParse(d.price.text) ?? 0;
    final int qty = int.tryParse(d.qty.text) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 30, child: Center(child: Text('${i + 1}', style: const TextStyle(color: kInk, fontSize: 12, fontWeight: FontWeight.w700)))),
        const SizedBox(width: 6),
        Expanded(
            child: TextField(
                controller: d.name,
                style: _inputDark,
                decoration: const InputDecoration(isDense: true))),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: TextField(
              controller: d.price,
              keyboardType: TextInputType.number,
              style: _inputDark,
              decoration: const InputDecoration(isDense: true),
              onChanged: (_) => setState(() {})),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 46,
          child: TextField(
              controller: d.qty,
              keyboardType: TextInputType.number,
              style: _inputDark,
              decoration: const InputDecoration(isDense: true),
              onChanged: (_) => setState(() {})),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: Center(
              child: Text(fmt(price * qty),
                  style: const TextStyle(color: kInk, fontWeight: FontWeight.w800, fontSize: 12))),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    if (_selected == null) {
      _snack('اختر العميل أولاً');
      return;
    }
    final items = _items
        .where((d) => d.name.text.trim().isNotEmpty)
        .map((d) => InvoiceItem(
            name: d.name.text.trim(),
            price: double.tryParse(d.price.text) ?? 0,
            qty: int.tryParse(d.qty.text) ?? 1))
        .toList();
    if (items.isEmpty) return;
    setState(() => _busy = true);
    try {
      final int pts = _autoPoints;
      final int rem = _autoStored;
      int signed;
      int signedStored;
      if (_isReturn) {
        signed = -pts;
        signedStored = -rem;
        _selected!.points = (_selected!.points - pts).clamp(0, 1000000000);
        _selected!.stored = (_selected!.stored - rem).clamp(0, 1000000000);
      } else {
        signed = pts;
        signedStored = rem;
        _selected!.points += pts;
        _selected!.stored += rem;
      }
      Store.invoices.add(Invoice(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          no: _invNo.text.trim(),
          userId: _selected!.id,
          date: DateTime.now().toString().substring(0, 10),
          type: _isReturn ? 'return' : 'sale',
          total: _total,
          points: signed,
          stored: signedStored,
          items: items));
      // المستخدمون أولاً ثم الفواتير مع فاصل زمني لمنع تعارض الـ commits
      await Store.saveUsers(widget.token);
      await Future.delayed(const Duration(milliseconds: 900));
      await Store.saveInvoices(widget.token);
      await Future.delayed(const Duration(milliseconds: 900));
      await Store.load();
      if (!mounted) return;
      _snack('تم الحفظ ونقل للجوال: الفاتورة رقم ${_invNo.text.trim()} | النقاط ${signed >= 0 ? '+' : ''}$signed | الرصيد المخزن $signedStored ✅');
      setState(() {
        _items.clear();
        _items.add(_Draft());
        _invNo.clear();
        _fetchedType = '';
        _selected = null;
        _busy = false;
      });
    } catch (e) {
      if (mounted) {
        _snack('Error: $e');
        setState(() => _busy = false);
      }
    }
  }
}

// ================= الأكواد (جوال + كمبيوتر) =================
class CodeFilesPage extends StatelessWidget {
  final String token;
  const CodeFilesPage({super.key, required this.token});

  static const List<String> mobileFiles = [
    'lib/main.dart',
    'lib/core/app_settings.dart',
    'lib/core/strings.dart',
    'lib/core/theme.dart',
    'lib/core/store_service.dart',
    'lib/core/gifts_service.dart',
    'lib/screens/login_screen.dart',
    'lib/screens/main_screen.dart',
    'lib/screens/home_screen.dart',
    'lib/screens/products_screen.dart',
    'lib/screens/settings_screen.dart',
    'lib/screens/simple_screens.dart',
    'lib/screens/about_screen.dart',
    'lib/widgets/bottom_nav.dart',
    'lib/widgets/gifts_view.dart',
    'lib/widgets/pressable.dart',
    'lib/widgets/fawori_logo.dart',
    'pubspec.yaml',
    'web/index.html',
  ];

  static const List<String> adminFiles = [
    'lib/main.dart',
    'lib/data.dart',
    'lib/excel_service.dart',
    'lib/extra.dart',
    'pubspec.yaml',
    'web/index.html',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الأكواد')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('📱 أكواد تطبيق الجوال (FAWORI)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kTeal)),
            const SizedBox(height: 10),
            ...mobileFiles.map((f) => _tile(context, f, kRepo)),
            const SizedBox(height: 24),
            const Text('🖥️ أكواد تطبيق الكمبيوتر (FAWORI-ADMIN)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kOrange)),
            const SizedBox(height: 10),
            ...adminFiles.map((f) => _tile(context, f, kAdminRepo)),
          ],
        ),
      );

  Widget _tile(BuildContext context, String path, String repo) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: kCard,
          leading: const Icon(Icons.description_outlined, color: kOrange),
          title: Text(path, textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 13)),
          trailing: const Icon(Icons.edit_rounded, color: kTeal, size: 18),
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CodeEditor(path: path, token: token, repo: repo))),
        ),
      );
}

class CodeEditor extends StatefulWidget {
  final String path;
  final String token;
  final String repo;
  const CodeEditor({super.key, required this.path, required this.token, required this.repo});
  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  final _c = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await GH.getContent(widget.path, widget.token, widget.repo);
      if (mounted) setState(() { _c.text = t; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _c.text));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم نسخ الكل ✅')));
    }
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d != null && d.text != null && d.text!.isNotEmpty) {
      setState(() => _c.text = d.text!);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم اللصق ✅')));
      }
    }
  }

  void _clearAll() {
    setState(() => _c.text = '');
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم مسح الكل')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await GH.put(widget.path, _c.text, widget.token, widget.repo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم الحفظ ✅ — سيُعاد البناء خلال دقائق')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _toolBtn(IconData ic, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kOrange.withAlpha(60)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ic, color: kOrange, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('${widget.repo == kAdminRepo ? '🖥️' : '📱'} ${widget.path}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 14)),
          actions: [
            _saving
                ? const Padding(padding: EdgeInsets.all(14),
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : IconButton(icon: const Icon(Icons.cloud_upload_outlined), onPressed: _save),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: kOrange))
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: _toolBtn(Icons.content_copy_rounded, 'نسخ الكل', _copyAll)),
                    const SizedBox(width: 8),
                    Expanded(child: _toolBtn(Icons.content_paste_rounded, 'لصق', _paste)),
                    const SizedBox(width: 8),
                    Expanded(child: _toolBtn(Icons.delete_sweep_rounded, 'مسح الكل', _clearAll)),
                  ]),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _c,
                        maxLines: null,
                        expands: true,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                            border: InputBorder.none, contentPadding: EdgeInsets.zero),
                      ),
                    ),
                  ),
                ]),
              ),
      );
}
