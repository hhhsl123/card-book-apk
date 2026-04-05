import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data.dart';

class BatchPage extends StatefulWidget {
  const BatchPage({super.key});
  @override
  State<BatchPage> createState() => _BatchPageState();
}

class _BatchPageState extends State<BatchPage> {
  final _nameCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _faceCtrl = TextEditingController();
  final _cardsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateTime.now().toIso8601String().substring(0, 10);
  }

  String _genId() => '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${(DateTime.now().microsecond).toRadixString(36)}';

  void _createBatch() {
    final name = _nameCtrl.text.trim();
    final rate = double.tryParse(_rateCtrl.text) ?? 0;
    final date = _dateCtrl.text.trim();
    final globalFace = double.tryParse(_faceCtrl.text) ?? 0;
    final raw = _cardsCtrl.text.trim();

    if (name.isEmpty) { _msg('请输入批次名称'); return; }
    if (rate <= 0) { _msg('请输入进货汇率'); return; }
    if (raw.isEmpty) { _msg('请添加卡片'); return; }

    final cards = <CardItem>[];
    for (final line in raw.split('\n')) {
      final l = line.trim();
      if (l.isEmpty) continue;
      final parts = l.split(RegExp(r'\s+'));
      String label = '', secret = '';
      double face = globalFace;

      if (globalFace > 0) {
        label = parts[0];
        if (parts.length >= 2) secret = parts.sublist(1).join(' ');
      } else {
        if (parts.length >= 3 && double.tryParse(parts.last) != null) {
          face = double.tryParse(parts.last) ?? 0;
          secret = parts[parts.length - 2];
          label = parts.sublist(0, parts.length - 2).join(' ');
        } else if (parts.length == 2 && double.tryParse(parts[1]) != null) {
          label = parts[0];
          face = double.tryParse(parts[1]) ?? 0;
        } else {
          label = parts.join(' ');
        }
      }

      cards.add(CardItem(id: _genId(), label: label, secret: secret, face: face));
    }

    final totalFace = cards.fold<double>(0, (s, c) => s + c.face);
    final batch = Batch(
      id: _genId(),
      name: name,
      rate: rate,
      batchDate: date,
      cost: totalFace * rate,
      cards: cards,
    );

    context.read<AppProvider>().addBatch(batch);
    _nameCtrl.clear();
    _rateCtrl.clear();
    _faceCtrl.clear();
    _cardsCtrl.clear();
    _msg('✅ 创建成功，${cards.length} 张卡');
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Create form
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('新建批次', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '批次名称', border: OutlineInputBorder(), isDense: true))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _rateCtrl, decoration: const InputDecoration(labelText: '进货汇率', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                TextField(controller: _dateCtrl, decoration: const InputDecoration(labelText: '进货日期', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 12),
                TextField(controller: _faceCtrl, decoration: const InputDecoration(labelText: '统一面值（选填）', border: OutlineInputBorder(), isDense: true, hintText: '留空则从每行解析'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: _cardsCtrl, decoration: const InputDecoration(labelText: '卡片（每行一张）', border: OutlineInputBorder(), isDense: true, hintText: '卡号 卡密 面值\n或 卡号 面值'), maxLines: 6),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: _createBatch, child: const Text('创建批次'))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('所有批次', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...prov.data.batches.reversed.map((b) {
          final total = b.cards.length;
          final sold = b.cards.where((c) => c.sold && !c.bad).length;
          final bad = b.cards.where((c) => c.bad).length;
          final remain = total - sold - bad;
          final pct = total > 0 ? sold / total : 0.0;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () {
                      showDialog(context: context, builder: (ctx) => AlertDialog(
                        title: const Text('删除批次？'),
                        content: Text('确定删除 ${b.name}？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                          TextButton(onPressed: () { prov.deleteBatch(b.id); Navigator.pop(ctx); }, child: const Text('删除', style: TextStyle(color: Colors.red))),
                        ],
                      ));
                    }),
                  ]),
                  Text('📅 ${b.batchDate}  💱 ${b.rate}  📦 $total张', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: pct, minHeight: 5, borderRadius: BorderRadius.circular(3)),
                  const SizedBox(height: 4),
                  Text('已卖$sold  剩$remain${bad > 0 ? "  坏$bad" : ""}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
