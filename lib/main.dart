import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kOwner = 'AHMEDBRZAN';
const String kRepo = 'FAWORI';
const String kBranch = 'main';
const String kSite = 'https://ahmedbrzan.github.io/FAWORI';

const Color kOrange = Color(0xFFE8A33D);
const Color kTeal = Color(0xFF3EC6C0);
const Color kBg = Color(0xFF141419);
const Color kCard = Color(0xFF1B1B21);

// ================= النماذج =================
class User {
  String id, name, phone, password, role;
  int points;
  User({required this.id, required this.name, required this.phone,
      required this.password, required this.role, this.points = 0});
  factory User.fromJson(Map<String, dynamic> j) => User(
      id: '${j['id'] ?? ''}', name: j['name'] ?? '', phone: '${j['phone'] ?? ''}',
      password: '${j['password'] ?? ''}', role: j['role'] ?? 'customer',
      points: (j['points'] as num?)?.toInt() ?? 0);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone,
      'password': password, 'role': role, 'points': points};
}

class InvoiceItem {
  String name; double price;
  InvoiceItem({required this.name, required this.price});
  factory InvoiceItem.fromJson(Map<String, dynamic> j) =>
      InvoiceItem(name: j['name'] ?? '', price: (j['price'] as num?)?.toDouble() ?? 0);
  Map<String, dynamic> toJson() => {'name': name, 'price': price};
}

class Invoice {
  String id, userId, date; double total; int points; List<InvoiceItem> items;
  Invoice({required this.id, required this.userId, required this.date,
      required this.total, required this.points, required this.items});
  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
      id: '${j['id'] ?? ''}', userId: '${j['userId'] ?? ''}', date: j['date'] ?? '',
      total: (j['total'] as num?)?.toDouble() ?? 0,
      points: (j['points'] as num?)?.toInt() ?? 0,
      items: ((j['items'] as List<dynamic>?) ?? [])
          .map((e) => InvoiceItem.fromJson(e as Map<String, dynamic>)).toList());
  Map<String, dynamic> toJson() => {'id': id, 'userId': userId, 'date': date,
      'total': total, 'points': points, 'items': items.map((e) => e.toJson()).toList()};
}

class Gift {
  String id, name, desc, category, image; int points; double price;
  Gift({required this.id, required this.name, required this.desc,
      required this.category, required this.image, required this.points, required this.price});
  factory Gift.fromJson(Map<String, dynamic> j) => Gift(
      id: '${j['id'] ?? ''}', name: j['name'] ?? '', desc: j['desc'] ?? '',
      category: j['category'] ?? '', image: j['image'] ?? '',
      points: (j['points'] as num?)?.toInt() ?? 0,
      price: (j['price'] as num?)?.toDouble() ?? 0);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'desc': desc,
      'category': category, 'image': image, 'points': points, 'price': price};
}

// ================= GitHub =================
class GH {
  static Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString('token');
  static Future<void> saveToken(String t) async =>
      (await SharedPreferences.getInstance()).setString('token', t);
  static Map<String, String> headers(String t) =>
      {'Authorization': 'Bearer $t', 'Accept': 'application/vnd.github+json'};

  static Future<String?> getSha(String path, String t) async {
    final r = await http.get(
        Uri.parse('https://api.github.com/repos/$kOwner/$kRepo/contents/$path?ref=$kBranch'),
        headers: headers(t));
    if (r.statusCode != 200) return null;
    return jsonDecode(r.body)['sha'] as String?;
  }

  static Future<void> put(String path, String content, String t) async {
    final sha = await getSha(path, t);
    final r = await http.put(
        Uri.parse('https://api.github.com/repos/$kOwner/$kRepo/contents/$path'),
        headers: headers(t),
        body: jsonEncode({
          'message': 'Update $path (PC admin)',
          'content': base64Encode(utf8.encode(content)),
          if (sha != null) 'sha': sha,
          'branch': kBranch,
        }));
    if (r.statusCode != 200 && r.statusCode != 201) throw Exception('PUT ${r.statusCode}');
  }

  static Future<List<T>> _load<T>(String file, T Function(Map<String, dynamic>) f) async {
    try {
      final r = await http.get(Uri.parse('$kSite/assets/assets/data/$file'));
      if (r.statusCode != 200) return [];
      return (jsonDecode(r.body) as List<dynamic>)
          .map((e) => f(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<User>> users() => _load('users.json', User.fromJson);
  static Future<List<Invoice>> invoices() => _load('invoices.json', Invoice.fromJson);
  static Future<List<Gift>> gifts() => _load('gifts.json', Gift.fromJson);
}

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
      child: _token == null
          ? TokenPage(onSaved: _check)
          : Home(token: _token!),
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
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900, color: kOrange)),
              const SizedBox(height: 8),
              Text('تُفتح مرة واحدة فقط ثم يُحفظ التوكن',
                  style: TextStyle(color: Colors.grey.shade400)),
              const SizedBox(height: 20),
              TextField(
                controller: _c,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                    hintText: 'ghp_...', filled: true, fillColor: kBg,
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kOrange, foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: () async {
                    if (_c.text.trim().isEmpty) return;
                    await GH.saveToken(_c.text.trim());
                    widget.onSaved();
                  },
                  child: const Text('دخول',
                      style: TextStyle(fontWeight: FontWeight.w800)),
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
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _page == 0
                  ? UsersPage(token: widget.token)
                  : _page == 1
                      ? InvoicesPage(token: widget.token)
                      : GiftsPage(token: widget.token),
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
  late Future<List<User>> _f = GH.users();

  String _roleLabel(String r) =>
      r == 'agent' ? 'وكيل' : r == 'tech' ? 'فني' : r == 'admin' ? 'مدير' : 'عميل';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('المستخدمون'),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => setState(() => _f = GH.users())),
            IconButton(
                icon: const Icon(Icons.person_add_alt_1_rounded),
                onPressed: () async {
                  await showDialog(
                      context: context,
                      builder: (_) => AddUserDialog(token: widget.token));
                  setState(() => _f = GH.users());
                }),
          ],
        ),
        body: FutureBuilder<List<User>>(
          future: _f,
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                  child: CircularProgressIndicator(color: kOrange));
            }
            final users = snap.data ?? [];
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final u = users[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: kCard, borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2A2A33))),
                  child: Row(children: [
                    CircleAvatar(
                        backgroundColor: kOrange.withAlpha(40),
                        child: Text(u.name.isNotEmpty ? u.name[0] : '؟',
                            style: const TextStyle(
                                color: kOrange, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.name,
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('${u.phone}  •  ${_roleLabel(u.role)}',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('${u.points}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: kOrange)),
                    const SizedBox(width: 6),
                    const Text('نقطة', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 14),
                    IconButton(
                      tooltip: 'إضافة نقاط',
                      icon: const Icon(Icons.add_circle_outline_rounded, color: kTeal),
                      onPressed: () async {
                        await showDialog(
                            context: context,
                            builder: (_) => AddPointsDialog(
                                token: widget.token, users: users, user: u));
                        setState(() => _f = GH.users());
                      },
                    ),
                  ]),
                );
              },
            );
          },
        ),
      );
}

class AddUserDialog extends StatefulWidget {
  final String token;
  const AddUserDialog({super.key, required this.token});
  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  String _role = 'customer';
  bool _busy = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('إضافة مستخدم'),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'الاسم')),
            TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                keyboardType: TextInputType.phone),
            TextField(
                controller: _pass,
                decoration: const InputDecoration(labelText: 'كلمة المرور')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _role,
              items: const [
                DropdownMenuItem(value: 'customer', child: Text('عميل')),
                DropdownMenuItem(value: 'agent', child: Text('وكيل')),
                DropdownMenuItem(value: 'tech', child: Text('فني')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'customer'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kOrange, foregroundColor: Colors.black),
            onPressed: _busy
                ? null
                : () async {
                    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
                      return;
                    }
                    setState(() => _busy = true);
                    try {
                      final users = await GH.users();
                      users.add(User(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: _name.text.trim(),
                          phone: _phone.text.trim(),
                          password: _pass.text,
                          role: _role));
                      await GH.put('assets/data/users.json',
                          jsonEncode(users.map((u) => u.toJson()).toList()),
                          widget.token);
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('Error: $e')));
                        setState(() => _busy = false);
                      }
                    }
                  },
            child: const Text('حفظ'),
          ),
        ],
      );
}

class AddPointsDialog extends StatefulWidget {
  final String token;
  final List<User> users;
  final User user;
  const AddPointsDialog(
      {super.key, required this.token, required this.users, required this.user});
  @override
  State<AddPointsDialog> createState() => _AddPointsDialogState();
}

class _AddPointsDialogState extends State<AddPointsDialog> {
  final _c = TextEditingController();
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('نقاط لـ ${widget.user.name}'),
        content: TextField(
            controller: _c,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'عدد النقاط')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kTeal, foregroundColor: Colors.black),
            onPressed: () async {
              final n = int.tryParse(_c.text) ?? 0;
              if (n == 0) return;
              widget.user.points += n;
              try {
                await GH.put('assets/data/users.json',
                    jsonEncode(widget.users.map((u) => u.toJson()).toList()),
                    widget.token);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      );
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
  late Future<List<User>> _usersF = GH.users();
  late Future<List<Invoice>> _invF = GH.invoices();
  String? _userId;
  final List<_Draft> _items = [_Draft()];
  final _pts = TextEditingController();
  bool _busy = false;

  double get _total => _items.fold<double>(
      0, (s, d) => s + (double.tryParse(d.price.text) ?? 0));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الفواتير والنقاط')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: kCard, borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF2A2A33))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('فاتورة جديدة',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900, color: kOrange)),
                const SizedBox(height: 12),
                FutureBuilder<List<User>>(
                  future: _usersF,
                  builder: (_, snap) {
                    final users = snap.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: _userId,
                      isExpanded: true,
                      dropdownColor: kCard,
                      hint: const Text('اختر العميل'),
                      items: users
                          .map((u) => DropdownMenuItem(
                              value: u.id,
                              child: Text('${u.name} (${u.phone})')))
                          .toList(),
                      onChanged: (v) => setState(() => _userId = v),
                    );
                  },
                ),
                const SizedBox(height: 10),
                ..._items.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(
                            child: TextField(
                                controller: d.name,
                                decoration: const InputDecoration(
                                    labelText: 'المادة', isDense: true))),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 110,
                          child: TextField(
                              controller: d.price,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'السعر', isDense: true),
                              onChanged: (_) => setState(() {})),
                        ),
                        IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.red),
                            onPressed: _items.length > 1
                                ? () => setState(() => _items.remove(d))
                                : null),
                      ]),
                    )),
                TextButton.icon(
                    onPressed: () => setState(() => _items.add(_Draft())),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة مادة')),
                const SizedBox(height: 10),
                Row(children: [
                  Text('الإجمالي: ${_total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 20),
                  const Text('النقاط: ', style: TextStyle(color: kTeal)),
                  SizedBox(
                    width: 100,
                    child: TextField(
                        controller: _pts,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true)),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kOrange, foregroundColor: Colors.black),
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('حفظ الفاتورة'),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('آخر الفواتير',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            FutureBuilder<List<Invoice>>(
              future: _invF,
              builder: (_, snap) {
                final invs = (snap.data ?? []).reversed.toList();
                if (invs.isEmpty) {
                  return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                          child: Text('لا توجد فواتير',
                              style: TextStyle(color: Colors.grey))));
                }
                return Column(
                  children: invs
                      .map((inv) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: kCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: const Color(0xFF2A2A33))),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(inv.date,
                                        style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(
                                        inv.items.map((e) => e.name).join('، '),
                                        style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              Text('${inv.total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(width: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: kTeal.withAlpha(40),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text('+${inv.points}',
                                    style: const TextStyle(
                                        color: kTeal,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ]),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      );

  Future<void> _save() async {
    if (_userId == null) return;
    final items = _items
        .where((d) => d.name.text.trim().isNotEmpty)
        .map((d) => InvoiceItem(
            name: d.name.text.trim(),
            price: double.tryParse(d.price.text) ?? 0))
        .toList();
    if (items.isEmpty) return;
    setState(() => _busy = true);
    try {
      final users = await GH.users();
      final invs = await GH.invoices();
      final points = int.tryParse(_pts.text) ?? _total.round();
      invs.add(Invoice(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: _userId!,
          date: DateTime.now().toString().substring(0, 10),
          total: _total,
          points: points,
          items: items));
      final u = users.where((x) => x.id == _userId).toList();
      if (u.isNotEmpty) u.first.points += points;
      await GH.put('assets/data/invoices.json',
          jsonEncode(invs.map((e) => e.toJson()).toList()), widget.token);
      await GH.put('assets/data/users.json',
          jsonEncode(users.map((e) => e.toJson()).toList()), widget.token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم الحفظ — سيصل التحديث للجوال خلال دقائق ✅')));
      setState(() {
        _items.clear();
        _items.add(_Draft());
        _pts.clear();
        _busy = false;
        _invF = GH.invoices();
        _usersF = GH.users();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _busy = false);
      }
    }
  }
}

// ================= الهدايا =================
class GiftsPage extends StatefulWidget {
  final String token;
  const GiftsPage({super.key, required this.token});
  @override
  State<GiftsPage> createState() => _GiftsPageState();
}

class _GiftsPageState extends State<GiftsPage> {
  late Future<List<Gift>> _f = GH.gifts();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('الهدايا'),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => setState(() => _f = GH.gifts())),
            IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AddGiftPage(token: widget.token)));
                  setState(() => _f = GH.gifts());
                }),
          ],
        ),
        body: FutureBuilder<List<Gift>>(
          future: _f,
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                  child: CircularProgressIndicator(color: kOrange));
            }
            final gifts = snap.data ?? [];
            if (gifts.isEmpty) {
              return const Center(
                  child: Text('لا توجد هدايا',
                      style: TextStyle(color: Colors.grey)));
            }
            return GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8),
              itemCount: gifts.length,
              itemBuilder: (_, i) {
                final g = gifts[i];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: kCard, borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2A2A33))),
                  child: Column(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network('$kSite/assets/${g.image}',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.redeem_rounded,
                                size: 50,
                                color: kOrange)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(g.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('${g.points} نقطة',
                        style: const TextStyle(
                            color: kOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ]),
                );
              },
            );
          },
        ),
      );
}

class AddGiftPage extends StatefulWidget {
  final String token;
  const AddGiftPage({super.key, required this.token});
  @override
  State<AddGiftPage> createState() => _AddGiftPageState();
}

class _AddGiftPageState extends State<AddGiftPage> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _cat = TextEditingController();
  final _pts = TextEditingController();
  Uint8List? _bytes;
  bool _busy = false;

  Future<void> _pick() async {
    final f = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (!mounted) return;
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('إضافة هدية'),
          actions: [
            _busy
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : IconButton(
                    icon: const Icon(Icons.check_rounded),
                    onPressed: () async {
                      if (_name.text.trim().isEmpty) return;
                      setState(() => _busy = true);
                      try {
                        String image = 'assets/images/as1.PNG';
                        if (_bytes != null) {
                          final path =
                              'assets/images/gift_${DateTime.now().millisecondsSinceEpoch}.png';
                          final r = await http.put(
                              Uri.parse(
                                  'https://api.github.com/repos/$kOwner/$kRepo/contents/$path'),
                              headers: GH.headers(widget.token),
                              body: jsonEncode({
                                'message': 'Add gift image (PC)',
                                'content': base64Encode(_bytes!),
                                'branch': kBranch,
                              }));
                          if (r.statusCode != 200 && r.statusCode != 201) {
                            throw Exception('Upload ${r.statusCode}');
                          }
                          image = path;
                        }
                        final gifts = await GH.gifts();
                        gifts.add(Gift(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            name: _name.text.trim(),
                            desc: _desc.text.trim(),
                            category: _cat.text.trim(),
                            image: image,
                            points: int.tryParse(_pts.text) ?? 0,
                            price: 0));
                        await GH.put('assets/data/gifts.json',
                            jsonEncode(gifts.map((g) => g.toJson()).toList()),
                            widget.token);
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Error: $e')));
                          setState(() => _busy = false);
                        }
                      }
                    }),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            InkWell(
              onTap: _pick,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                    color: kCard, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kOrange.withAlpha(60))),
                child: _bytes == null
                    ? const Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add_photo_alternate_rounded,
                              size: 44, color: kOrange),
                          SizedBox(height: 8),
                          Text('إرفاق صورة الهدية'),
                        ]))
                    : Center(child: Image.memory(_bytes!, fit: BoxFit.contain)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم الهدية')),
            const SizedBox(height: 10),
            TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'الوصف')),
            const SizedBox(height: 10),
            TextField(
                controller: _cat,
                decoration: const InputDecoration(labelText: 'القسم')),
            const SizedBox(height: 10),
            TextField(
                controller: _pts,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'النقاط المطلوبة')),
          ],
        ),
      );
}
