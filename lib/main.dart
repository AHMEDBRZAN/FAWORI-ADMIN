import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';
import 'excel_service.dart';
import 'extra.dart';

const int _BIG = 1000000000;
int _clamp(int v) => v.clamp(0, _BIG);

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
                NavigationRailDestination(
                    icon: Icon(Icons.history_rounded), label: Text('فواتير سابقة')),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _page == 0
                  ? UsersPage(token: widget.token)
                  : _page == 1
                      ? InvoicesPage(
                          token: widget.token,
                          onArchive: () => setState(() => _page = 4))
                      : _page == 2
                          ? GiftsPage(token: widget.token)
                          : _page == 3
                              ? CodeFilesPage(token: widget.token)
                              : ArchivePage(token: widget.token),
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
    u.points = _clamp(u.points + n);
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
    u.points = _clamp(int.tryParse(pts.text) ?? u.points);
    u.stored = _clamp(int.tryParse(stored.text) ?? u.stored);
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

/// حذف فاتورة مع عكس نقاطها ورصيدها من العميل ورفع الملفين
Future<bool> deleteInvoiceReverse(
    BuildContext context, String token, Invoice inv) async {
  if (!await confirmDialog(context, 'حذف الفاتورة وعكس نقاطها ورصيدها من العميل؟')) {
    return false;
  }
  final u = Store.users.where((x) => x.id == inv.userId).toList();
  if (u.isNotEmpty) {
    u.first.points = _clamp(u.first.points - inv.points);
    u.first.stored = _clamp(u.first.stored - inv.stored);
  }
  Store.invoices.remove(inv);
  try {
    await Store.saveUsers(token);
    await Future.delayed(const Duration(milliseconds: 900));
    await Store.saveInvoices(token);
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    return false;
  }
}

class InvoicesPage extends StatefulWidget {
  final String token;
  final VoidCallback? onArchive;
  const InvoicesPage({super.key, required this.token, this.onArchive});
  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  /// المخزن المحلي لملف الاكسل (ذاكرة + حفظ دائم في المتصفح)
  static ExcelData? _cached;
  static const String _b64Key = 'fawori_xlsx_b64_v1';

  bool _loading = true;
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
    // تحميل المخزن المحلي فقط — بدون أي جلب من الإنترنت
    if (_cached == null) await _loadLocalCache();
    if (mounted) setState(() => _loading = false);
  }

  /// حفظ bytes الملف محلياً في المتصفح ليبقى بعد الإغلاق
  Future<void> _persistBytes(List<int> bytes) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_b64Key, base64Encode(bytes));
    } catch (_) {
      // إذا تجاوز حجم التخزين الحد يبقى في الذاكرة فقط
    }
  }

  /// استرجاع الملف من التخزين المحلي بدون إنترنت
  Future<bool> _loadLocalCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final b64 = p.getString(_b64Key);
      if (b64 == null || b64.isEmpty) return false;
      final bytes = base64Decode(b64);
      _cached = parseFaworiExcel(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 🔄 تحديث: جلب من المستودع + استبدال المخزن المحلي + حفظه محلياً
  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final r = await http
          .get(Uri.parse(
              '$kSite/assets/assets/data/fawori.xlsx?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final data = parseFaworiExcel(r.bodyBytes);
      _cached = data;
      await _persistBytes(r.bodyBytes);
      if (!mounted) return;
      setState(() => _refreshing = false);
      _snack('تم الجلب من المستودع واستبدال المخزن المحلي ✅ ${data.invoices.length} فاتورة و ${data.materials.length} مادة فاوري');
    } catch (e) {
      if (!mounted) return;
      setState(() => _refreshing = false);
      _snack('فشل الجلب من المستودع: $e — المخزن المحلي السابق بدون تغيير');
    }
  }

  /// 📤 رفع ونشر: رفع الملف للمستودع + تخزينه محلياً
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
      _cached = data;
      await _persistBytes(bytes);
      if (mounted) {
        setState(() => _refreshing = false);
        _snack('تم رفع الملف للمستودع ونشره + تخزينه محلياً ✅');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _refreshing = false);
        _snack('Error: $e');
      }
    }
  }

  /// 📂 قراءة محلية: قراءة ملف من الجهاز بدون نشر — الأسرع للعمل اليومي
  Future<void> _loadLocalFile() async {
    final res = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
    if (res == null || res.files.isEmpty) return;
    final bytes = res.files.first.bytes;
    if (bytes == null) return;
    setState(() => _refreshing = true);
    try {
      final data = parseFaworiExcel(bytes);
      _cached = data;
      await _persistBytes(bytes);
      if (mounted) {
        setState(() => _refreshing = false);
        _snack('تم قراءة الملف محلياً بدون نشر ✅ ${data.invoices.length} فاتورة و ${data.materials.length} مادة فاوري');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _refreshing = false);
        _snack('تعذرت قراءة الملف: $e');
      }
    }
  }

  /// جلب فاتورة بالرقم من المخزن المحلي فقط — بدون إنترنت
  void _fetch() {
    final data = _cached;
    if (data == null) {
      _snack('لا يوجد ملف مخزن — اضغط 🔄 تحديث أو 📂 قراءة محلية');
      return;
    }
    final no = _invNo.text.trim();
    if (no.isEmpty) {
      _snack('اكتب رقم الفاتورة أولاً');
      return;
    }
    final match = data.invoices.where((i) => i.no.trim() == no).toList();
    if (match.isEmpty) {
      _snack('لا توجد فاتورة بالرقم $no داخل الملف المخزن');
      return;
    }
    final f = match.first;
    final fawori = f.items.where((it) => data.isFawori(it.code, it.name)).toList();
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
    _snack('تم جلب ${fawori.length} مادة فاوري من المخزن ✅');
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
                tooltip: 'تحديث: جلب من المستودع واستبدال المخزن المحلي',
                icon: _refreshing
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kTeal))
                    : const Icon(Icons.sync_rounded, color: kTeal),
                onPressed: _refreshing ? null : _refresh),
            IconButton(
                tooltip: 'رفع ملف ونشره للمستودع + تخزين محلي',
                icon: const Icon(Icons.upload_file_rounded),
                onPressed: _refreshing ? null : _upload),
            IconButton(
                tooltip: 'قراءة ملف محلي بدون نشر (أسرع)',
                icon: const Icon(Icons.folder_open_rounded, color: kOrange),
                onPressed: _refreshing ? null : _loadLocalFile),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: kOrange))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // حالة المخزن المحلي
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: _cached == null ? Colors.red.withAlpha(20) : kTeal.withAlpha(20),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          _cached == null
                              ? Icons.cloud_off_rounded
                              : Icons.cloud_done_rounded,
                          size: 16,
                          color: _cached == null ? Colors.red : kTeal),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                            _cached == null
                                ? 'لا يوجد ملف مخزن — اضغط 🔄 تحديث أو 📂 قراءة محلية'
                                : 'الملف المخزن محلياً جاهز: ${_cached!.invoices.length} فاتورة و ${_cached!.materials.length} مادة فاوري',
                            style: TextStyle(
                                color: _cached == null ? Colors.red : kTeal,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  _invoiceCard(),
                  const SizedBox(height: 24),
                  Row(children: [
                    const Text('آخر الفواتير (آخر 5)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (widget.onArchive != null)
                      TextButton.icon(
                          onPressed: widget.onArchive,
                          icon: const Icon(Icons.history_rounded, size: 18),
                          label: const Text('كل الفواتير السابقة')),
                  ]),
                  const SizedBox(height: 10),
                  ...(_invs.reversed.take(5).toList()).map((inv) => _invTile(inv)),
                ],
              ),
      );

  Widget _invTile(Invoice inv) {
    final neg = inv.points < 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_userName(inv.userId),
                  style: const TextStyle(
                      color: kInk, fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 2),
              Text('${inv.date}  •  ${neg ? 'مرتجع' : 'مبيع'}  •  رقم ${inv.no.isEmpty ? '—' : inv.no}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
              const SizedBox(height: 4),
              Text(inv.items.map((e) => '${e.name} ×${e.qty}').join('، '),
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            ],
          ),
        ),
        Column(children: [
          Text(fmt(inv.total),
              style: const TextStyle(
                  color: kInk, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: neg ? Colors.red.withAlpha(30) : kTeal.withAlpha(30),
                borderRadius: BorderRadius.circular(8)),
            child: Text(neg ? '${fmt(inv.points)}' : '+${fmt(inv.points)}',
                style: TextStyle(
                    color: neg ? Colors.red : kTeal,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ),
          const SizedBox(height: 4),
          Text('مخزن: ${fmt(inv.stored)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
        ]),
        IconButton(
            tooltip: 'تعديل شامل',
            icon: const Icon(Icons.edit_rounded, color: kOrange, size: 18),
            onPressed: () async {
              final r = await Navigator.push<bool>(context,
                  MaterialPageRoute(
                      builder: (_) =>
                          InvoiceEditor(token: widget.token, invoice: inv)));
              if (r == true) setState(() {});
            }),
        IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
            onPressed: () async {
              final ok = await deleteInvoiceReverse(context, widget.token, inv);
              if (ok) setState(() {});
            }),
      ]),
    );
  }

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
        _selected!.points = _clamp(_selected!.points - pts);
        _selected!.stored = _clamp(_selected!.stored - rem);
      } else {
        signed = pts;
        signedStored = rem;
        _selected!.points = _clamp(_selected!.points + pts);
        _selected!.stored = _clamp(_selected!.stored + rem);
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
      await Store.saveUsers(widget.token);
      await Future.delayed(const Duration(milliseconds: 900));
      await Store.saveInvoices(widget.token);
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

// ================= محرر الفاتورة الشامل (حساب مباشر) =================
class InvoiceEditor extends StatefulWidget {
  final String token;
  final Invoice invoice;
  const InvoiceEditor({super.key, required this.token, required this.invoice});
  @override
  State<InvoiceEditor> createState() => _InvoiceEditorState();
}

class _InvoiceEditorState extends State<InvoiceEditor> {
  late String _userId = widget.invoice.userId;
  late final TextEditingController _no =
      TextEditingController(text: widget.invoice.no);
  late final TextEditingController _date =
      TextEditingController(text: widget.invoice.date);
  late String _type = widget.invoice.type;
  late final List<_Draft> _items = widget.invoice.items
      .map((it) => _Draft()
        ..name.text = it.name
        ..price.text = it.price == it.price.roundToDouble()
            ? it.price.toStringAsFixed(0)
            : it.price.toStringAsFixed(2)
        ..qty.text = '${it.qty}')
      .toList();
  String _query = '';
  bool _busy = false;

  static const TextStyle _inkBold =
      TextStyle(color: kInk, fontWeight: FontWeight.w800, fontSize: 14);
  static const TextStyle _hintDark =
      TextStyle(color: Color(0xFF7A8699), fontWeight: FontWeight.w600);
  static const TextStyle _inputDark =
      TextStyle(color: kInk, fontWeight: FontWeight.w700);

  bool get _isReturn => _type == 'return';

  double get _total => _items.fold<double>(
      0,
      (s, d) =>
          s +
          (double.tryParse(d.price.text) ?? 0) *
              (int.tryParse(d.qty.text) ?? 0));

  int get _tRound => _total.round();
  int get _livePts => _tRound ~/ kPointUnit;
  int get _liveRem => _tRound % kPointUnit;

  User? get _user {
    final m = Store.users.where((u) => u.id == _userId).toList();
    return m.isEmpty ? null : m.first;
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _liveRow(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(label, style: _inkBold),
          const Spacer(),
          Text(value,
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
      );

  Future<void> _save() async {
    final u = _user;
    if (u == null) {
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
    if (items.isEmpty) {
      _snack('أضف مادة واحدة على الأقل');
      return;
    }
    setState(() => _busy = true);
    try {
      final int pts = _livePts;
      final int rem = _liveRem;
      final int signed = _isReturn ? -pts : pts;
      final int signedStored = _isReturn ? -rem : rem;
      final old = widget.invoice;
      final oldU = Store.users.where((x) => x.id == old.userId).toList();
      if (oldU.isNotEmpty) {
        oldU.first.points = _clamp(oldU.first.points - old.points);
        oldU.first.stored = _clamp(oldU.first.stored - old.stored);
      }
      u.points = _clamp(u.points + signed);
      u.stored = _clamp(u.stored + signedStored);
      final neu = Invoice(
          id: old.id,
          no: _no.text.trim(),
          userId: _userId,
          date: _date.text.trim(),
          type: _type,
          total: _total,
          points: signed,
          stored: signedStored,
          items: items);
      final idx = Store.invoices.indexWhere((x) => x.id == old.id);
      if (idx >= 0) {
        Store.invoices[idx] = neu;
      } else {
        Store.invoices.add(neu);
      }
      await Store.saveUsers(widget.token);
      await Future.delayed(const Duration(milliseconds: 900));
      await Store.saveInvoices(widget.token);
      if (!mounted) return;
      _snack('تم حفظ التعديلات: النقاط ${signed >= 0 ? '+' : ''}$signed والرصيد المخزن $signedStored ✅');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _snack('Error: $e');
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('تعديل شامل للفاتورة'),
          actions: [
            _busy
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : IconButton(
                    icon: const Icon(Icons.cloud_upload_outlined),
                    onPressed: _save),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _no,
                      style: _inputDark,
                      decoration: const InputDecoration(
                          labelText: 'رقم الفاتورة',
                          labelStyle: _hintDark,
                          filled: true,
                          fillColor: Color(0xFFF4F6F8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _date,
                      style: _inputDark,
                      decoration: const InputDecoration(
                          labelText: 'التاريخ (YYYY-MM-DD)',
                          labelStyle: _hintDark,
                          filled: true,
                          fillColor: Color(0xFFF4F6F8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _type,
                      dropdownColor: const Color(0xFFF4F6F8),
                      decoration: const InputDecoration(
                          labelText: 'النوع',
                          labelStyle: _hintDark,
                          filled: true,
                          fillColor: Color(0xFFF4F6F8)),
                      items: const [
                        DropdownMenuItem(value: 'sale', child: Text('مبيع')),
                        DropdownMenuItem(value: 'return', child: Text('مرتجع مبيع')),
                      ],
                      onChanged: (v) => setState(() => _type = v ?? 'sale'),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                if (_user == null)
                  const Text('اختر العميل بالأسفل',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700))
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: kTeal.withAlpha(30),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('العميل: ${_user!.name} (${_user!.phone})',
                          style: const TextStyle(
                              color: kInk, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: _inputDark,
                  decoration: const InputDecoration(
                      labelText: 'تغيير العميل: ابحث بالاسم أو الرقم...',
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
                      children: Store.users
                          .where((u) =>
                              u.name.contains(_query) || u.phone.contains(_query))
                          .map((u) => ListTile(
                                dense: true,
                                title: Text(u.name,
                                    style: const TextStyle(
                                        color: kInk, fontWeight: FontWeight.w700)),
                                subtitle: Text(u.phone,
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xFF7A8699))),
                                onTap: () =>
                                    setState(() { _userId = u.id; _query = ''; }),
                              ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 14),
                Container(
                  color: kOrange,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: const [
                    SizedBox(width: 30, child: Center(child: Text('NO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 11)))),
                    Expanded(child: Center(child: Text('اسم الصنف', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)))),
                    SizedBox(width: 70, child: Center(child: Text('سعر القطعة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 10)))),
                    SizedBox(width: 46, child: Center(child: Text('العدد', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 11)))),
                    SizedBox(width: 70, child: Center(child: Text('المجموع', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 11)))),
                    SizedBox(width: 34),
                  ]),
                ),
                ...List.generate(_items.length, (i) => _editRow(i, _items[i])),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _items.add(_Draft())),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('إضافة مادة',
                        style: TextStyle(color: kInk, fontWeight: FontWeight.w800)),
                  ),
                ),
                const Divider(),
                _liveRow('التكلفة الإجمالية', fmt(_tRound), kInk),
                _liveRow(
                    'نقاط الفاتورة (مباشرة من الإجمالي)',
                    '${_isReturn ? '-' : '+'}${fmt(_livePts)}',
                    kTeal),
                _liveRow('رصيد مخزن من الفاتورة (مباشر)', fmt(_liveRem), kInk),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _isReturn ? Colors.red : kOrange,
                        foregroundColor: _isReturn ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: _busy ? null : _save,
                    child: Text(
                        _isReturn
                            ? 'حفظ المرتجع (خصم النقاط)'
                            : 'حفظ التعديلات (إضافة النقاط)',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      );

  Widget _editRow(int i, _Draft d) {
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
        SizedBox(
          width: 34,
          child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 18),
              onPressed: _items.length > 1
                  ? () => setState(() => _items.remove(d))
                  : null),
        ),
      ]),
    );
  }
}

// ================= فواتير سابقة (الأرشيف) =================
class ArchivePage extends StatefulWidget {
  final String token;
  const ArchivePage({super.key, required this.token});
  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  final _q = TextEditingController();
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

  String _userName(String id) {
    final m = Store.users.where((u) => u.id == id);
    return m.isEmpty ? '—' : m.first.name;
  }

  String _userPhone(String id) {
    final m = Store.users.where((u) => u.id == id);
    return m.isEmpty ? '' : m.first.phone;
  }

  List<Invoice> get _filtered {
    final q = _q.text.trim();
    final all = Store.invoices.reversed.toList();
    if (q.isEmpty) return all;
    return all
        .where((i) =>
            _userName(i.userId).contains(q) ||
            _userPhone(i.userId).contains(q) ||
            i.no.contains(q) ||
            i.date.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('فواتير سابقة')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: kOrange))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                    controller: _q,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: kInk, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                        labelText: 'بحث ذكي: اسم العميل / رقم الهاتف / رقم الفاتورة / التاريخ',
                        labelStyle: TextStyle(color: Color(0xFF7A8699)),
                        hintStyle: TextStyle(color: Color(0xFF7A8699)),
                        prefixIcon: Icon(Icons.search_rounded, color: kTeal),
                        filled: true,
                        fillColor: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text('${_filtered.length} فاتورة',
                      style: const TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ..._filtered.map((inv) {
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
                              Text(
                                  '${inv.date}  •  ${neg ? 'مرتجع' : 'مبيع'}  •  رقم ${inv.no.isEmpty ? '—' : inv.no}  •  ${_userPhone(inv.userId)}',
                                  style: TextStyle(
                                      color: Colors.grey.shade600, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(
                                  inv.items
                                      .map((e) => '${e.name} ×${e.qty}')
                                      .join('، '),
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
                            tooltip: 'تعديل شامل',
                            icon: const Icon(Icons.edit_rounded,
                                color: kOrange, size: 18),
                            onPressed: () async {
                              final r = await Navigator.push<bool>(context,
                                  MaterialPageRoute(
                                      builder: (_) => InvoiceEditor(
                                          token: widget.token, invoice: inv)));
                              if (r == true) setState(() {});
                            }),
                        IconButton(
                            tooltip: 'حذف',
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.red, size: 18),
                            onPressed: () async {
                              final ok = await deleteInvoiceReverse(
                                  context, widget.token, inv);
                              if (ok) setState(() {});
                            }),
                      ]),
                    );
                  }),
                ],
              ),
      );
}

// ================= الأكواد (جوال + كمبيوتر) =================
class CodeFilesPage extends StatefulWidget {
  final String token;
  const CodeFilesPage({super.key, required this.token});
  @override
  State<CodeFilesPage> createState() => _CodeFilesPageState();
}

class _CodeFilesPageState extends State<CodeFilesPage> {
  List<String>? _mobile;
  List<String>? _admin;
  bool _loading = true;

  static const List<String> _fallbackMobile = [
    'lib/main.dart',
    'lib/core/app_settings.dart',
    'lib/core/strings.dart',
    'lib/core/theme.dart',
    'lib/core/store_service.dart',
    'lib/core/gifts_service.dart',
    'lib/core/locked_dialog.dart',
    'lib/data/sample_data.dart',
    'lib/screens/login_screen.dart',
    'lib/screens/main_screen.dart',
    'lib/screens/home_screen.dart',
    'lib/screens/products_screen.dart',
    'lib/screens/settings_screen.dart',
    'lib/screens/profile_screen.dart',
    'lib/screens/simple_screens.dart',
    'lib/screens/about_screen.dart',
    'lib/widgets/bottom_nav.dart',
    'lib/widgets/gifts_view.dart',
    'lib/widgets/pressable.dart',
    'lib/widgets/fawori_logo.dart',
    'pubspec.yaml',
    'web/index.html',
  ];

  static const List<String> _fallbackAdmin = [
    'lib/main.dart',
    'lib/data.dart',
    'lib/excel_service.dart',
    'lib/extra.dart',
    'pubspec.yaml',
    'web/index.html',
  ];

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<List<String>> _fetchTree(String repo) async {
    final r = await http.get(
        Uri.parse(
            'https://api.github.com/repos/$kOwner/$repo/git/trees/$kBranch?recursive=1'),
        headers: GH.headers(widget.token));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final List<dynamic> tree = jsonDecode(r.body)['tree'] as List<dynamic>;
    final files = tree
        .where((e) => e['type'] == 'blob')
        .map((e) => e['path'] as String)
        .where((p) =>
            p.startsWith('lib/') ||
            p.startsWith('web/') ||
            p.startsWith('.github/') ||
            p == 'pubspec.yaml')
        .toList()
      ..sort();
    if (files.isEmpty) throw Exception('empty');
    return files;
  }

  Future<void> _loadLists() async {
    List<String> m = _fallbackMobile;
    List<String> a = _fallbackAdmin;
    try {
      m = await _fetchTree(kRepo);
    } catch (_) {}
    try {
      a = await _fetchTree(kAdminRepo);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _mobile = m;
        _admin = a;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('الأكواد'),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  setState(() => _loading = true);
                  _loadLists();
                }),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: kOrange))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('📱 أكواد تطبيق الجوال (FAWORI)',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900, color: kTeal)),
                  const SizedBox(height: 10),
                  ...(_mobile ?? _fallbackMobile)
                      .map((f) => _tile(context, f, kRepo)),
                  const SizedBox(height: 24),
                  const Text('🖥️ أكواد تطبيق الكمبيوتر (FAWORI-ADMIN)',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900, color: kOrange)),
                  const SizedBox(height: 10),
                  ...(_admin ?? _fallbackAdmin)
                      .map((f) => _tile(context, f, kAdminRepo)),
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
              builder: (_) => CodeEditor(path: path, token: widget.token, repo: repo))),
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
