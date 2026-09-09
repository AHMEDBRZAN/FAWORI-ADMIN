import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kOwner = 'AHMEDBRZAN';
const String kRepo = 'FAWORI';
const String kAdminRepo = 'FAWORI-ADMIN';
const String kBranch = 'main';
const String kSite = 'https://ahmedbrzan.github.io/FAWORI';

const int kPointUnit = 125000;

const Color kOrange = Color(0xFFE8A33D);
const Color kTeal = Color(0xFF3EC6C0);
const Color kBg = Color(0xFF141419);
const Color kCard = Color(0xFF1B1B21);
const Color kLine = Color(0xFF2A2A33);
const Color kInk = Color(0xFF23405C);

String fmt(num n) {
  final s = n.toStringAsFixed(0);
  final out = StringBuffer();
  var c = 0;
  for (var i = s.length - 1; i >= 0; i--) {
    out.write(s[i]);
    c++;
    if (c % 3 == 0 && i != 0) out.write(',');
  }
  return out.toString().split('').reversed.join();
}

Future<bool> confirmDialog(BuildContext context, String msg) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: kCard,
      title: const Text('تأكيد'),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  return r ?? false;
}

class User {
  String id, name, phone, password, role, address, housing, marital, car;
  int points;
  int stored;
  User({required this.id, required this.name, required this.phone,
      required this.password, required this.role, this.address = '',
      this.housing = '', this.marital = '', this.car = '',
      this.points = 0, this.stored = 0});
  factory User.fromJson(Map<String, dynamic> j) => User(
      id: '${j['id'] ?? ''}', name: j['name'] ?? '', phone: '${j['phone'] ?? ''}',
      password: '${j['password'] ?? ''}', role: j['role'] ?? 'customer',
      address: j['address'] ?? '', housing: j['housing'] ?? '',
      marital: j['marital'] ?? '', car: j['car'] ?? '',
      points: (j['points'] as num?)?.toInt() ?? 0,
      stored: (j['stored'] as num?)?.toInt() ?? 0);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone,
      'password': password, 'role': role, 'address': address, 'housing': housing,
      'marital': marital, 'car': car, 'points': points, 'stored': stored};
}

class InvoiceItem {
  String name; double price; int qty;
  InvoiceItem({required this.name, required this.price, this.qty = 1});
  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
      name: j['name'] ?? '', price: (j['price'] as num?)?.toDouble() ?? 0,
      qty: (j['qty'] as num?)?.toInt() ?? 1);
  Map<String, dynamic> toJson() => {'name': name, 'price': price, 'qty': qty};
}

class Invoice {
  String id, userId, date, type;
  double total;
  int points;
  int stored;
  List<InvoiceItem> items;
  Invoice({required this.id, required this.userId, required this.date,
      required this.total, required this.points, required this.items,
      this.type = 'sale', this.stored = 0});
  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
      id: '${j['id'] ?? ''}', userId: '${j['userId'] ?? ''}', date: j['date'] ?? '',
      type: j['type'] ?? 'sale', total: (j['total'] as num?)?.toDouble() ?? 0,
      points: (j['points'] as num?)?.toInt() ?? 0,
      stored: (j['stored'] as num?)?.toInt() ?? 0,
      items: ((j['items'] as List<dynamic>?) ?? [])
          .map((e) => InvoiceItem.fromJson(e as Map<String, dynamic>)).toList());
  Map<String, dynamic> toJson() => {'id': id, 'userId': userId, 'date': date,
      'type': type, 'total': total, 'points': points, 'stored': stored,
      'items': items.map((e) => e.toJson()).toList()};
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

class GH {
  static Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString('token');
  static Future<void> saveToken(String t) async =>
      (await SharedPreferences.getInstance()).setString('token', t);
  static Map<String, String> headers(String t) =>
      {'Authorization': 'Bearer $t', 'Accept': 'application/vnd.github+json'};

  static Future<String?> getSha(String path, String t, [String repo = kRepo]) async {
    final r = await http.get(
        Uri.parse('https://api.github.com/repos/$kOwner/$repo/contents/$path?ref=$kBranch'),
        headers: headers(t));
    if (r.statusCode != 200) return null;
    return jsonDecode(r.body)['sha'] as String?;
  }

  static Future<void> putBinary(String path, List<int> bytes, String t,
      [String repo = kRepo]) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final sha = await getSha(path, t, repo);
      final r = await http.put(
          Uri.parse('https://api.github.com/repos/$kOwner/$repo/contents/$path'),
          headers: headers(t),
          body: jsonEncode({
            'message': 'Update $path (PC admin)',
            'content': base64Encode(bytes),
            if (sha != null) 'sha': sha,
            'branch': kBranch,
          }));
      if (r.statusCode == 200 || r.statusCode == 201) return;
      if (r.statusCode == 409 && attempt < 2) {
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        continue;
      }
      throw Exception('PUT ${r.statusCode}');
    }
  }

  static Future<void> put(String path, String content, String t,
          [String repo = kRepo]) =>
      putBinary(path, utf8.encode(content), t, repo);

  static Future<String> getContent(String path, String t,
      [String repo = kRepo]) async {
    final r = await http.get(
        Uri.parse('https://api.github.com/repos/$kOwner/$repo/contents/$path?ref=$kBranch'),
        headers: headers(t));
    if (r.statusCode != 200) throw Exception('GET ${r.statusCode}');
    final b64 = (jsonDecode(r.body)['content'] as String).replaceAll('\n', '');
    return utf8.decode(base64Decode(b64));
  }

  static Future<List<T>> _load<T>(
      String file, T Function(Map<String, dynamic>) f) async {
    try {
      final r = await http.get(Uri.parse(
          '$kSite/assets/assets/data/$file?t=${DateTime.now().millisecondsSinceEpoch}'));
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

/// مخزن موحّد داخل الجلسة — تحميل تسلسلي آمن الأنواع
class Store {
  static List<User> users = [];
  static List<Invoice> invoices = [];
  static bool loaded = false;

  static Future<void> load() async {
    users = await GH.users();
    invoices = await GH.invoices();
    loaded = true;
  }

  static Future<void> saveUsers(String token) => GH.put('assets/data/users.json',
      jsonEncode(users.map((u) => u.toJson()).toList()), token);

  static Future<void> saveInvoices(String token) => GH.put(
      'assets/data/invoices.json',
      jsonEncode(invoices.map((e) => e.toJson()).toList()),
      token);
}
