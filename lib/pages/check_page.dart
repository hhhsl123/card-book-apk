import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data.dart';

class CheckPage extends StatefulWidget {
  const CheckPage({super.key});
  @override
  State<CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<CheckPage> {
  String? _batchId;
  final _targetCtrl = TextEditingController();
  List<CardItem>? _comboResult;

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));

  List<CardItem>? _findCombo(List<CardItem> cards, double target) {
    final sorted = List<CardItem>.from(cards)..sort((a, b) => b.face.compareTo(a.face));
    List<CardItem>? best;

    void bt(int start, double remaining, List<CardItem> chosen) {
      if ((remaining).abs() < 0.001) {
        if (best == null || chosen.length < best!.length) {
          best = List.from(chosen);
        }
        return;
      }
      if (remaining < -0.001) return;
      if (best != null && chosen.length >= best!.length) return;
      if (start >= sorted.length) return;

      for (int i = start; i < sorted.length; i++) {
        if (sorted[i].face > remaining + 0.001) continue;
        chosen.add(sorted[i]);
        bt(i + 1, remaining - sorted[i].face, chosen);
        chosen.removeLast();
      }
    }

    bt(0, target, []);
    return best;
  }

  void _doCombo() {
    final target = double.tryParse(_targetCtrl.text) ?? 0;
    if (target <= 0) { _msg('请输入目标金额'); return; }

    final prov = context.read<AppProvider>();
    final batch = prov.data.batches.where((b) => b.id == _batchId).firstOrNull;
    if (batch == null) return;

    final unsold = batch.cards.where((c) => !c.sold && !c.bad).toList();
    final result = _findCombo(unsold, target);
    setState(() => _comboResult = result);
    if (result == null) _msg('无法凑出该金额');
  }

  Future<void> _pickCards(List<CardItem> cards) async {
    final prov = context.read<AppProvider>();
    final text = cards.map((c) => c.secret.isNotEmpty ? '${c.label} ${c.secret}' : c.label).join('\n');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('提卡确认 (${cards.length}张)'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('将复制以下卡号卡密并标记为已卖\n卖出人: ${prov.myRole ?? "未知"}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认提卡')),
        ],
      ),
    );

    if (ok == true) {
      await Clipboard.setData(ClipboardData(text: text));
      await prov.pickCards(_batchId!, cards);
      setState(() => _comboResult = null);
      _msg('已复制并标记 ${cards.length} 张卡为已卖');
    }
  }

  String _fmtFace(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final batches = prov.data.batches;
    final batch = _batchId != null ? batches.where((b) => b.id == _batchId).firstOrNull : null;
    final unsold = batch?.cards.where((c) => !c.sold && !c.bad).toList() ?? [];
    final badCards = batch?.cards.where((c) => c.bad).toList() ?? [];

    final sortedBatches = List.of(batches)..sort((a, b) {
      final aHasUnsold = a.cards.any((c) => !c.sold && !c.bad);
      final bHasUnsold = b.cards.any((c) => !c.sold && !c.bad);
      if (aHasUnsold && !bHasUnsold) return -1;
      if (!aHasUnsold && bHasUnsold) return 1;
      return b.date.compareTo(a.date);
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: _batchId,
          decoration: const InputDecoration(labelText: '选择批次', border: OutlineInputBorder(), isDense: true),
          items: sortedBatches.map((b) {
            final remain = b.cards.where((c) => !c.sold && !c.bad).length;
            final allDone = remain == 0 && b.cards.isNotEmpty;
            return DropdownMenuItem(
              value: b.id,
              child: Text(
                '${b.name} (${allDone ? "已卖完" : "剩${remain}张"})',
                style: TextStyle(color: allDone ? Colors.grey : null),
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() { _batchId = v; _comboResult = null; }),
        ),

        if (batch != null) ...[
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('📅 ${batch.batchDate}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    const SizedBox(width: 12),
                    Text('💱 ${batch.rate}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    const SizedBox(width: 12),
                    Text('📦 ${batch.cards.length}张', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    '剩余 ${unsold.length} 张 · 总面值 ¥${_fmtFace(unsold.fold<double>(0, (s, c) => s + c.face))} · 成本 ¥${_fmtFace(unsold.fold<double>(0, (s, c) => s + c.face) * batch.rate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Combo section
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('组合凑面值', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _targetCtrl,
                      decoration: const InputDecoration(hintText: '目标金额，如 20', border: OutlineInputBorder(), isDense: true),
                      keyboardType: TextInputType.number,
                    )),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _doCombo, child: const Text('组合')),
                  ]),
                  if (_comboResult != null) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Text('${_comboResult!.length}张 = ¥${_fmtFace(_comboResult!.fold<double>(0, (s, c) => s + c.face))}',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      FilledButton.icon(
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('提卡'),
                        onPressed: () => _pickCards(_comboResult!),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    ...(_comboResult!).map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.label, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                            if (c.secret.isNotEmpty) Text(c.secret, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Theme.of(context).colorScheme.primary)),
                          ],
                        )),
                        Text('面值¥${_fmtFace(c.face)}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ]),
                    )),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Card list — show face value & rate, keep pick, remove copy
          ...unsold.map((c) => Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              title: Text(c.label, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c.secret.isNotEmpty) Text(c.secret, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Theme.of(context).colorScheme.primary)),
                  Text('面值 ¥${_fmtFace(c.face)}  汇率 ${batch.rate}  成本 ¥${_fmtFace(c.face * batch.rate)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.send, size: 18),
                tooltip: '提卡',
                onPressed: () => _pickCards([c]),
              ),
            ),
          )),

          // Bad cards
          if (badCards.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('坏卡 (${badCards.length}张)', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...badCards.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Expanded(child: Text(c.label, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                        Text('¥${_fmtFace(c.face)}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ]),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
