import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kOwner = 'AHMEDBRZAN';
const String kRepo = 'FAWORI';
const String kBranch = 'main';
const String kSite = 'https://ahmedbrzan.github.io/FAWORI';

const Color kOrange = Color(0xFFE8A33D);
const Color kTeal = Color(0xFF3EC6C0);
const Color kBg = Color(0xFF141419);
const Color kCard = Color(0xFF1B1B21);
const Color kLine = Color(0xFF2A2A33);

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
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء')),
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
  User({
    required this.id, required this.name, required this.phone,
    required this.password, required this.role,
    this.address = '', this.housing = '', this.marital = '', this.car = '',
    this.points = 0,
  });
  factory User.fromJson(Map<String, dynamic> j) => User(
      id: '${j['id'] ?? ''}', name: j['name'] ?? '', phone: '${j['phone'] ?? ''}',
      password: '${j['password'] ?? ''}', role: j['role'] ?? 'customer',
      address: j['address'] ?? '', housing: j['housing'] ?? '',
      marital: j['marital'] ?? '', car: j['car'] ?? '',
      points: (j['points'] as num?)?.toInt() ?? 0);
  Map<String, dynamic> toJson() => {
      'id': id, 'name': name, 'phone': phone, 'password': password,
      'role': role, 'address': address, 'housing': housing,
      'marital': marital, 'car': car, 'points': points};
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

  static Future<String> getContent(String path, String t) async {
    final r = await http.get(
        Uri.parse('https://api.github.com/repos/$kOwner/$kRepo/contents/$path?ref=$kBranch'),
        headers: headers(t));
    if (r.statusCode != 200) throw Exception('GET ${r.statusCode}');
    final b64 = (jsonDecode(r.body)['content'] as String).replaceAll('\n', '');
    return utf8.decode(base64Decode(b64));
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
