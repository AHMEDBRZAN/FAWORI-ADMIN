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
  XlInvoice({required this.no, required this.date, required this.type, required this.items});
}

class ExcelData {
  final Map<String, String> materials;
  final List<XlInvoice> invoices;
  ExcelData(this.materials, this.invoices);

  bool isFawori(String code, String name) {
    if (materials.containsKey(code)) return true;
    if (name.isEmpty) return false;
    return materials.values.any((m) =>
        m.isNotEmpty && (m == name || name.contains(m) || m.contains(name)));
  }
}

String _str(dynamic v) => v?.toString().trim() ?? '';

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  final s = v.toString().replaceAll(',', '').trim();
  return double.tryParse(s) ?? 0;
}

ExcelData parseFaworiExcel(List<int> bytes) {
  final book = xl.Excel.decodeBytes(bytes);
  final materials = <String, String>{};
  final invoices = <XlInvoice>[];

  for (final entry in book.tables.entries) {
    final sheetName = entry.key;
    final rows = entry.value.rows;

    int headerRow = -1, codeIdx = -1, nameIdx = -1, qtyIdx = -1,
        priceIdx = -1, totalIdx = -1, noIdx = -1, dateIdx = -1, typeIdx = -1;

    for (var r = 0; r < rows.length && headerRow < 0; r++) {
      for (final c in rows[r]) {
        if (_str(c?.value).contains('رمز')) { headerRow = r; break; }
      }
    }

    if (headerRow >= 0) {
      final h = rows[headerRow];
      for (var i = 0; i < h.length; i++) {
        final s = _str(h[i]?.value);
        if (s.contains('رمز')) codeIdx = i;
        else if (s.contains('المادة') || s.contains('الصنف')) nameIdx = i;
        else if (s.contains('الكمية') || s.contains('العدد')) qtyIdx = i;
        else if (s.contains('الافرادي')) priceIdx = i;
        else if (s.contains('الاجمالي') || s.contains('المجموع')) totalIdx = i;
        else if (s.contains('رقم')) noIdx = i;
        else if (s.contains('التاريخ')) dateIdx = i;
        else if (s.contains('النوع')) typeIdx = i;
      }
    }

    String g(List<xl.Data?> row, int i) =>
        i >= 0 && i < row.length ? _str(row[i]?.value) : '';
    double gn(List<xl.Data?> row, int i) =>
        i >= 0 && i < row.length ? _num(row[i]?.value) : 0;

    if (sheetName.contains('مواد')) {
      if (headerRow < 0) {
        for (var r = 0; r < rows.length; r++) {
          final code = g(rows[r], 0);
          final nm = g(rows[r], 1);
          if (code.isNotEmpty && nm.isNotEmpty) materials[code] = nm;
        }
      } else {
        for (var r = headerRow + 1; r < rows.length; r++) {
          final code = g(rows[r], codeIdx);
          final nm = g(rows[r], nameIdx);
          if (code.isNotEmpty && nm.isNotEmpty) materials[code] = nm;
        }
      }
    } else if (sheetName.contains('فات')) {
      XlInvoice? cur;
      for (var r = (headerRow < 0 ? 0 : headerRow + 1); r < rows.length; r++) {
        final row = rows[r];
        final no = g(row, noIdx);
        if (no.isNotEmpty) {
          cur = XlInvoice(no: no, date: g(row, dateIdx), type: g(row, typeIdx), items: []);
          invoices.add(cur);
          continue;
        }
        final code = g(row, codeIdx);
        if (code.isNotEmpty && cur != null) {
          cur.items.add(XlItem(
            code: code,
            name: g(row, nameIdx),
            qty: gn(row, qtyIdx).toInt(),
            price: gn(row, priceIdx),
            total: gn(row, totalIdx),
          ));
        }
      }
    }
  }
  return ExcelData(materials, invoices);
}
