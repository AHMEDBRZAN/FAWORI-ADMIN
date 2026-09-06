import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'data.dart';

// ================= الهدايا =================
class GiftsPage extends StatefulWidget {
  final String token;
  const GiftsPage({super.key, required this.token});
  @override
  State<GiftsPage> createState() => _GiftsPageState();
}

class _GiftsPageState extends State<GiftsPage> {
  List<Gift> _gifts = [];
  bool _loading = true;

  Future<void> _load() async {
    final g = await GH.gifts();
    if (mounted) setState(() { _gifts = g; _loading = false; });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _delete(Gift g) async {
    if (!await confirmDialog(context, 'حذف الهدية "${g.name}"؟')) return;
    final list = _gifts.where((x) => x.id != g.id).toList();
    try {
      await GH.put('assets/data/gifts.json',
          jsonEncode(list.map((e) => e.toJson()).toList()), widget.token);
      setState(() => _gifts = list);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('الهدايا'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => setState(() { _loading = true; _load(); })),
            IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => GiftEditor(token: widget.token)));
                  setState(() { _loading = true; _load(); });
                }),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: kOrange))
            : _gifts.isEmpty
                ? const Center(child: Text('لا توجد هدايا', style: TextStyle(color: Colors.grey)))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10,
                        childAspectRatio: 0.72),
                    itemCount: _gifts.length,
                    itemBuilder: (_, i) {
                      final g = _gifts[i];
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: kCard, borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kLine)),
                        child: Column(children: [
                          Expanded(
                            child: Stack(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network('$kSite/assets/${g.image}',
                                    width: double.infinity, fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.redeem_rounded, size: 36, color: kOrange)),
                              ),
                              Positioned(
                                top: 0, left: 0,
                                child: Row(children: [
                                  _mini(Icons.edit_rounded, () async {
                                    await Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => GiftEditor(token: widget.token, gift: g)));
                                    setState(() { _loading = true; _load(); });
                                  }),
                                  _mini(Icons.delete_outline_rounded, () => _delete(g), red: true),
                                ]),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 4),
                          Text(g.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${fmt(g.points)} نقطة',
                              style: const TextStyle(color: kOrange, fontSize: 11, fontWeight: FontWeight.w800)),
                        ]),
                      );
                    },
                  ),
      );

  Widget _mini(IconData ic, VoidCallback onTap, {bool red = false}) => InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
          child: Icon(ic, size: 14, color: red ? Colors.red.shade300 : kTeal),
        ),
      );
}

class GiftEditor extends StatefulWidget {
  final String token;
  final Gift? gift;
  const GiftEditor({super.key, required this.token, this.gift});
  @override
  State<GiftEditor> createState() => _GiftEditorState();
}

class _GiftEditorState extends State<GiftEditor> {
  late final TextEditingController _name = TextEditingController(text: widget.gift?.name ?? '');
  late final TextEditingController _desc = TextEditingController(text: widget.gift?.desc ?? '');
  late final TextEditingController _cat = TextEditingController(text: widget.gift?.category ?? '');
  late final TextEditingController _pts =
      TextEditingController(text: widget.gift != null ? '${widget.gift!.points}' : '');
  Uint8List? _bytes;
  bool _busy = false;

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (f == null) return;
    final b = await f.readAsBytes();
    if (!mounted) return;
    setState(() => _bytes = b);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.gift == null ? 'إضافة هدية' : 'تعديل هدية'),
          actions: [
            _busy
                ? const Padding(padding: EdgeInsets.all(14),
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : IconButton(icon: const Icon(Icons.check_rounded), onPressed: _save),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            InkWell(
              onTap: _pick,
              child: Container(
                height: 170,
                decoration: BoxDecoration(
                    color: kCard, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kOrange.withAlpha(60))),
                child: _bytes != null
                    ? Center(child: Image.memory(_bytes!, fit: BoxFit.contain))
                    : widget.gift != null
                        ? Center(
                            child: Image.network('$kSite/assets/${widget.gift!.image}',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.image_rounded, size: 40, color: Colors.grey)))
                        : const Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.add_photo_alternate_rounded, size: 40, color: kOrange),
                                SizedBox(height: 6),
                                Text('إرفاق صورة الهدية'),
                              ])),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الهدية')),
            const SizedBox(height: 10),
            TextField(controller: _desc, decoration: const InputDecoration(labelText: 'الوصف')),
            const SizedBox(height: 10),
            TextField(controller: _cat, decoration: const InputDecoration(labelText: 'القسم')),
            const SizedBox(height: 10),
            TextField(controller: _pts, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'النقاط المطلوبة')),
          ],
        ),
      );

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final gifts = await GH.gifts();
      String image = widget.gift?.image ?? 'assets/images/as1.PNG';
      if (_bytes != null) {
        final path = 'assets/images/gift_${DateTime.now().millisecondsSinceEpoch}.png';
        await GH.put(path, base64Encode(_bytes!), widget.token);
        image = path;
      }
      if (widget.gift == null) {
        gifts.add(Gift(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: _name.text.trim(), desc: _desc.text.trim(),
            category: _cat.text.trim(), image: image,
            points: int.tryParse(_pts.text) ?? 0, price: 0));
      } else {
        final i = gifts.indexWhere((g) => g.id == widget.gift!.id);
        if (i >= 0) {
          gifts[i] = Gift(
              id: widget.gift!.id, name: _name.text.trim(), desc: _desc.text.trim(),
              category: _cat.text.trim(), image: image,
              points: int.tryParse(_pts.text) ?? widget.gift!.points, price: widget.gift!.price);
        }
      }
      await GH.put('assets/data/gifts.json',
          jsonEncode(gifts.map((g) => g.toJson()).toList()), widget.token);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _busy = false);
      }
    }
  }
}

// ================= محرر الأكواد =================
const List<String> codeFiles = [
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

class CodeFilesPage extends StatelessWidget {
  final String token;
  const CodeFilesPage({super.key, required this.token});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('أكواد تطبيق الجوال')),
        body: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: codeFiles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: kCard,
            leading: const Icon(Icons.description_outlined, color: kOrange),
            title: Text(codeFiles[i], textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 13)),
            trailing: const Icon(Icons.edit_rounded, color: kTeal, size: 18),
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => CodeEditor(path: codeFiles[i], token: token))),
          ),
        ),
      );
}

class CodeEditor extends StatefulWidget {
  final String path;
  final String token;
  const CodeEditor({super.key, required this.path, required this.token});
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

  Future<void> _load() async {
    try {
      final t = await GH.getContent(widget.path, widget.token);
      if (mounted) setState(() { _c.text = t; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await GH.put(widget.path, _c.text, widget.token);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحفظ — سيُعاد بناء الجوال خلال دقائق ✅')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.path, textDirection: TextDirection.ltr,
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
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(children: [
                    Expanded(child: _tool(Icons.content_copy_rounded, 'نسخ', () async {
                      await Clipboard.setData(ClipboardData(text: _c.text));
                    })),
                    const SizedBox(width: 8),
                    Expanded(child: _tool(Icons.delete_sweep_rounded, 'مسح الكل',
                        () => setState(() => _c.text = ''))),
                    const SizedBox(width: 8),
                    Expanded(child: _tool(Icons.content_paste_rounded, 'لصق', () async {
                      final d = await Clipboard.getData(Clipboard.kTextPlain);
                      if (d != null && d.text != null && d.text!.isNotEmpty) {
                        setState(() => _c.text = d.text!);
                      }
                    })),
                  ]),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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
                ),
              ]),
      );

  Widget _tool(IconData ic, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
              color: kCard, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kOrange.withAlpha(60))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ic, color: kOrange, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
