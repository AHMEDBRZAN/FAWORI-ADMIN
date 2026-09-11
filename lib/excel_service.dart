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
  final Map<String, String> materials; // الرمز -> اسم المادة
  final Map<String, double> prices; // الرمز -> سعر المبيع
  final Map<String, String> barcodes; // الباركود -> الرمز
  final List<XlInvoice> invoices;
  ExcelData(this.materials, this.prices, this.barcodes, this.invoices);

  bool isFawori(String code, String name) {
    if (code.isNotEmpty && materials.containsKey(code)) return true;
    if (name.isEmpty) return false;
    return materials.values
        .any((m) => m.isNotEmpty && (m == name || name.contains(m) || m.contains(name)));
  }
}

String _str(dynamic v) => v?.toString().trim() ?? '';

String _cleanBarcode(String s) =>
    s.replaceAll(';', '').replaceAll(' ', '').trim();

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  final s = v.toString().replaceAll(',', '').trim();
  return double.tryParse(s) ?? 0;
}

ExcelData parseFaworiExcel(List<int> bytes) {
  final book = xl.Excel.decodeBytes(bytes);
  final materials = <String, String>{};
  final prices = <String, double>{};
  final barcodes = <String, String>{};
  final invoices = <XlInvoice>[];

  for (final table in book.tables.values) {
    final rows = table.rows;
    int mode = 0; // 1 = فواتير ، 2 = مواد
    int noIdx = -1,
        dateIdx = -1,
        typeIdx = -1,
        codeIdx = -1,
        nameIdx = -1,
        qtyIdx = -1,
        priceIdx = -1,
        totalIdx = -1,
        saleIdx = -1,
        barcodeIdx = -1;

    for (var r = 0; r < rows.length; r++) {
      final texts = rows[r].map((c) => _str(c?.value)).toList();
      final joined = texts.join('|');

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
          else if (qtyIdx < 0 && s.contains('الكمية')) qtyIdx = i;
          else if (priceIdx < 0 && s.contains('الافرادي')) priceIdx = i;
          else if (totalIdx < 0 && s.contains('الاجمالي')) totalIdx = i;
        }
        continue;
      }

      if (joined.contains('اسم المادة') && joined.contains('الرمز')) {
        mode = 2;
        codeIdx = -1; nameIdx = -1; saleIdx = -1; barcodeIdx = -1;
        for (var i = 0; i < texts.length; i++) {
          final s = texts[i];
          if (codeIdx < 0 && s.contains('الرمز')) codeIdx = i;
          else if (nameIdx < 0 && s.contains('اسم المادة')) nameIdx = i;
          else if (saleIdx < 0 && s.contains('سعر المبيع')) saleIdx = i;
          else if (barcodeIdx < 0 && s.contains('الباركود')) barcodeIdx = i;
        }
        continue;
      }

      String g(int i) =>
          i >= 0 && i < rows[r].length ? _str(rows[r][i]?.value) : '';
      double gn(int i) =>
          i >= 0 && i < rows[r].length ? _num(rows[r][i]?.value) : 0;

      if (mode == 1) {
        final no = g(noIdx);
        if (no.isNotEmpty) {
          invoices.add(
              XlInvoice(no: no, date: g(dateIdx), type: g(typeIdx), items: []));
          continue;
        }
        final code = g(codeIdx);
        if (code.isNotEmpty && invoices.isNotEmpty) {
          invoices.last.items.add(XlItem(
              code: code,
              name: g(nameIdx),
              qty: gn(qtyIdx).toInt(),
              price: gn(priceIdx),
              total: gn(totalIdx)));
        }
      } else if (mode == 2) {
        final code = g(codeIdx);
        final name = g(nameIdx);
        if (code.isNotEmpty && name.isNotEmpty) {
          materials[code] = name;
          prices[code] = gn(saleIdx);
          final b = _cleanBarcode(g(barcodeIdx));
          if (b.isNotEmpty) barcodes[b] = code;
        }
      }
    }
  }
  return ExcelData(materials, prices, barcodes, invoices);
}
