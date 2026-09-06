import 'package:excel/excel.dart' as xl;

class XlItem {
  final String code, name;
  final int qty;
  final double price, total;
  XlItem(
      {required this.code,
      required this.name,
      required this.qty,
      required this.price,
      required this.total});
}

class XlInvoice {
  final String no, date, type;
  final List<XlItem> items;
  XlInvoice(
      {required this.no,
      required this.date,
      required this.type,
      required this.items});
}

class ExcelData {
  final Map<String, String> materials;
  final List<XlInvoice> invoices;
  ExcelData(this.materials, this.invoices);

  bool isFawori(String code, String name) {
    if (code.isNotEmpty && materials.containsKey(code)) return true;
    if (name.isEmpty) return false;
    return materials.values.any((m) =>
        m.isNotEmpty && (m == name || name.contains(m) || m.contains(name)));
  }
}

String _str(dynamic v) => v?.toString().trim() ?? '';

/// توحيد صيغة الارقام: 21471.0 أو " 21,471 " أو 21471 كلها تصبح "21471"
String _normNo(dynamic v) {
  if (v == null) return '';
  if (v is num) return v.toInt().toString();
  final s = v.toString().trim();
  if (s.isEmpty) return '';
  final d = double.tryParse(s.replaceAll(',', ''));
  if (d != null) return d.toInt().toString();
  return s;
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  final s = v.toString().replaceAll(',', '').trim();
  return double.tryParse(s) ?? 0;
}

ExcelData parseFaworiExcel(List<int> bytes) {
  final book = xl.Excel.decodeBytes(bytes);
  final materials = <String, String>{};
  final invoices = <XlInvoice>[];

  // قراءة عميقة: مسح كل الاوراق وكل الاسطر مع تبديل الوضع تلقائياً
  for (final table in book.tables.values) {
    final rows = table.rows;
    int mode = 0; // 0 = لا شيء ، 1 = فواتير ، 2 = مواد
    int noIdx = -1, dateIdx = -1, typeIdx = -1, codeIdx = -1, nameIdx = -1,
        qtyIdx = -1, priceIdx = -1, totalIdx = -1;
    XlInvoice? cur;

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final texts = row.map((c) => _str(c?.value)).toList();
      final joined = texts.join('|');

      // رأس جدول الفواتير
      if (joined.contains('رقم الفاتورة')) {
        mode = 1;
        noIdx = -1; dateIdx = -1; typeIdx = -1; codeIdx = -1;
        nameIdx = -1; qtyIdx = -1; priceIdx = -1; totalIdx = -1;
        for (var i = 0; i < texts.length; i++) {
          final s = texts[i];
          if (noIdx < 0 && s.contains('رقم الفاتورة')) noIdx = i;
          else if (dateIdx < 0 && s.contains('التاريخ')) dateIdx = i;
          else if (typeIdx < 0 && s.contains('النوع')) typeIdx = i;
          else if (codeIdx < 0 && s.contains('رمز')) codeIdx = i;
          else if (nameIdx < 0 && s.contains('المادة')) nameIdx = i;
          else if (qtyIdx < 0 && (s.contains('الكمية') || s.contains('العدد'))) qtyIdx = i;
          else if (priceIdx < 0 && s.contains('الافرادي')) priceIdx = i;
          else if (totalIdx < 0 && s.contains('الاجمالي')) totalIdx = i;
        }
        continue;
      }

      // رأس جدول المواد
      if (joined.contains('اسم المادة') && joined.contains('الرمز')) {
        mode = 2;
        codeIdx = -1; nameIdx = -1;
        for (var i = 0; i < texts.length; i++) {
          final s = texts[i];
          if (codeIdx < 0 && s.contains('الرمز')) codeIdx = i;
          if (nameIdx < 0 && s.contains('اسم المادة')) nameIdx = i;
        }
        continue;
      }

      String g(int i) => i >= 0 && i < row.length ? _str(row[i]?.value) : '';
      dynamic raw(int i) => i >= 0 && i < row.length ? row[i]?.value : null;

      if (mode == 1) {
        final no = _normNo(raw(noIdx));
        if (no.isNotEmpty) {
          cur = XlInvoice(no: no, date: g(dateIdx), type: g(typeIdx), items: []);
          invoices.add(cur);
          continue;
        }
        final code = _normNo(raw(codeIdx));
        if (code.isNotEmpty && cur != null) {
          cur.items.add(XlItem(
            code: code,
            name: g(nameIdx),
            qty: _num(raw(qtyIdx)).toInt(),
            price: _num(raw(priceIdx)),
            total: _num(raw(totalIdx)),
          ));
        }
      } else if (mode == 2) {
        final code = _normNo(raw(codeIdx));
        final nm = g(nameIdx);
        if (code.isNotEmpty && nm.isNotEmpty) materials[code] = nm;
      }
    }
  }
  return ExcelData(materials, invoices);
}
