import 'dart:convert';

import 'package:flutter/material.dart';

import 'data.dart';
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
  List<User> _users = [];
  bool _loading = true;

  Future<void> _load() async {
    final u = await GH.users();
    if (mounted) setState(() { _users = u; _loading = false; });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _roleLabel(String r) =>
      r == 'agent' ? 'وكيل' : r == 'tech' ? 'فني' : r == 'admin' ? 'مدير' : 'عميل';

  Future<void> _saveUsers(List<User> list) async {
    await GH.put('assets/data/users.json',
        jsonEncode(list.map((u) => u.toJson()).toList()), widget.token);
  }

  Future<void> _delete(User u) async {
    if (!await confirmDialog(context, 'حذف المستخدم "${u.name}"؟')) return;
    try {
      final list = _users.where((x) => x.id != u.id).toList();
      await _saveUsers(list);
      setState(() => _users = list);
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
    try {
      u.points += n;
      await _saveUsers(_users);
      setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('المستخدمون'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh_rounded),
                onPressed: () => setState(() { _loading = true; _load(); })),
            IconButton(
                icon: const Icon(Icons.person_add_alt_1_rounded),
                onPressed: () async {
                  await showDialog(context: context,
                      builder: (_) => UserDialog(token: widget.token, users: _users));
                  setState(() { _loading = true; _load(); });
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
                      Text(fmt(u.points),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kOrange)),
                      const SizedBox(width: 4),
                      const Text('نقطة', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(width: 10),
                      IconButton(tooltip: 'نقاط', icon: const Icon(Icons.add_circle_outline_rounded, color: kTeal, size: 20),
                          onPressed: () => _addPoints(u)),
                      IconButton(tooltip: 'تعديل', icon: const Icon(Icons.edit_rounded, color: kOrange, size: 18),
                          onPressed: () async {
                            await showDialog(context: context,
                                builder: (_) => UserDialog(token: widget.token, users: _users, user: u));
                            setState(() { _loading = true; _load(); });
                          }),
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

  Widget _dd(String label, String value, List<String> opts, Function(String) set) =>
      DropdownButtonFormField<String>(
        value: value.isEmpty ? null : value,
        isExpanded: true,
        dropdownColor: kCard,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
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
      await GH.put('assets/data/users.json',
          jsonEncode(widget.users.map((u) => u.toJson()).toList()), widget.token);
      if (mounted) Navigator.pop(context);
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
}

class InvoicesPage extends StatefulWidget {
  final String token;
  const InvoicesPage({super.key, required this.token});
  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  List<User> _users = [];
  List<Invoice> _invs = [];
  bool _loading = true;
  String _query = '';
  User? _selected;
  final List<_Draft> _items = [_Draft()];
  final _pts = TextEditingController();
  bool _busy = false;

  Future<void> _load() async {
    final users = await GH.users();
    final invoices = await GH.invoices();
    if (mounted) setState(() {
      _users = users;
      _invs = invoices;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  double get _total =>
      _items.fold<double>(0, (s, d) => s + (double.tryParse(d.price.text) ?? 0));

  String _userName(String id) {
    final m = _users.where((u) => u.id == id);
    return m.isEmpty ? '—' : m.first.name;
  }

  Future<void> _deleteInv(Invoice inv) async {
    if (!await confirmDialog(context, 'حذف هذه الفاتورة؟')) return;
    try {
      final list = _invs.where((x) => x.id != inv.id).toList();
      await GH.put('assets/data/invoices.json',
          jsonEncode(list.map((e) => e.toJson()).toList()), widget.token);
      setState(() => _invs = list);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الفواتير والنقاط')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: kOrange))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: kCard, borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kLine)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('فاتورة جديدة',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kOrange)),
                      const SizedBox(height: 10),
                      if (_selected == null) ...[
                        TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: const InputDecoration(
                              labelText: 'ابحث باسم العميل أو رقمه...', isDense: true),
                        ),
                        if (_query.trim().isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 160),
                            child: ListView(
                              children: _users
                                  .where((u) =>
                                      u.name.contains(_query) || u.phone.contains(_query))
                                  .map((u) => ListTile(
                                        dense: true,
                                        title: Text(u.name),
                                        subtitle: Text(u.phone,
                                            style: const TextStyle(fontSize: 11)),
                                        onTap: () =>
                                            setState(() { _selected = u; _query = ''; }),
                                      ))
                                  .toList(),
                            ),
                          ),
                      ] else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: kTeal.withAlpha(30),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(_selected!.name,
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(width: 6),
                            Text('(${fmt(_selected!.points)} نقطة)',
                                style: const TextStyle(fontSize: 12, color: kTeal)),
                            const SizedBox(width: 8),
                            InkWell(
                                onTap: () => setState(() => _selected = null),
                                child: const Icon(Icons.close_rounded, size: 16)),
                          ]),
                        ),
                      const SizedBox(height: 12),
                      Row(children: const [
                        Expanded(child: Text('المادة', style: TextStyle(fontWeight: FontWeight.w800))),
                        SizedBox(width: 100, child: Text('السعر', style: TextStyle(fontWeight: FontWeight.w800))),
                        SizedBox(width: 40),
                      ]),
                      const Divider(),
                      ..._items.map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              Expanded(child: TextField(
                                  controller: d.name,
                                  decoration: const InputDecoration(isDense: true))),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                    controller: d.price,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(isDense: true),
                                    onChanged: (_) => setState(() {})),
                              ),
                              SizedBox(
                                width: 40,
                                child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.delete_outline_rounded,
                                        color: Colors.red, size: 18),
                                    onPressed: _items.length > 1
                                        ? () => setState(() => _items.remove(d))
                                        : null),
                              ),
                            ]),
                          )),
                      TextButton.icon(
                          onPressed: () => setState(() => _items.add(_Draft())),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('إضافة مادة')),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: kBg, borderRadius: BorderRadius.circular(12)),
                        child: Column(children: [
                          Row(children: [
                            const Text('الإجمالي'),
                            const Spacer(),
                            Text(fmt(_total),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          ]),
                          const Divider(),
                          Row(children: [
                            const Text('نقاط هذه الفاتورة'),
                            const Spacer(),
                            SizedBox(
                              width: 90,
                              child: TextField(
                                  controller: _pts,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      isDense: true,
                                      hintText: '${_total.round()}'),
                                  onChanged: (_) => setState(() {})),
                            ),
                          ]),
                          const Divider(),
                          Row(children: [
                            const Text('رصيد العميل بعد الحفظ'),
                            const Spacer(),
                            Text(
                                fmt((_selected?.points ?? 0) +
                                    (int.tryParse(_pts.text) ?? _total.round())),
                                style: const TextStyle(color: kTeal, fontWeight: FontWeight.w900)),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: kOrange, foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: _busy ? null : _save,
                          child: _busy
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('حفظ الفاتورة', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  const Text('آخر الفواتير',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ...(_invs.reversed.toList()).map((inv) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: kCard, borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kLine)),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${_userName(inv.userId)}  •  ${inv.date}',
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(inv.items.map((e) => e.name).join('، '),
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          Text(fmt(inv.total),
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: kTeal.withAlpha(40),
                                borderRadius: BorderRadius.circular(10)),
                            child: Text('+${fmt(inv.points)}',
                                style: const TextStyle(color: kTeal, fontWeight: FontWeight.w800)),
                          ),
                          IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.red, size: 18),
                              onPressed: () => _deleteInv(inv)),
                        ]),
                      )),
                ],
              ),
      );

  Future<void> _save() async {
    if (_selected == null) return;
    final items = _items
        .where((d) => d.name.text.trim().isNotEmpty)
        .map((d) => InvoiceItem(
            name: d.name.text.trim(), price: double.tryParse(d.price.text) ?? 0))
        .toList();
    if (items.isEmpty) return;
    setState(() => _busy = true);
    try {
      final points = int.tryParse(_pts.text) ?? _total.round();
      _invs.add(Invoice(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: _selected!.id,
          date: DateTime.now().toString().substring(0, 10),
          total: _total,
          points: points,
          items: items));
      _selected!.points += points;
      await GH.put('assets/data/invoices.json',
          jsonEncode(_invs.map((e) => e.toJson()).toList()), widget.token);
      await GH.put('assets/data/users.json',
          jsonEncode(_users.map((e) => e.toJson()).toList()), widget.token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحفظ — سيصل التحديث للجوال خلال دقائق ✅')));
      setState(() {
        _items.clear();
        _items.add(_Draft());
        _pts.clear();
        _selected = null;
        _busy = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _busy = false);
      }
    }
  }
}
