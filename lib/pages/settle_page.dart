import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class SettlePage extends StatefulWidget {
  const SettlePage({super.key});
  @override
  State<SettlePage> createState() => _SettlePageState();
}

class _SettlePageState extends State<SettlePage> {
  String? _batchId;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final batches = prov.data.batches;
    final batch = _batchId != null ? batches.where((b) => b.id == _batchId).firstOrNull : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: _batchId,
          decoration: const InputDecoration(labelText: '选择批次', border: OutlineInputBorder(), isDense: true),
          items: batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
          onChanged: (v) => setState(() => _batchId = v),
        ),

        if (batch != null) ...[
          const SizedBox(height: 16),
          _buildSettle(context, prov, batch),
        ],
      ],
    );
  }

  Widget _buildSettle(BuildContext context, AppProvider prov, batch) {
    final total = batch.cards.length;
    final soldCards = batch.cards.where((c) => c.sold && !c.bad).toList();
    final badCards = batch.cards.where((c) => c.bad).toList();
    final unsold = batch.cards.where((c) => !c.sold && !c.bad).toList();
    final totalRevenue = soldCards.fold<double>(0, (s, c) => s + c.soldPrice);
    final totalFace = batch.cards.fold<double>(0, (s, c) => s + c.face);
    final badFace = badCards.fold<double>(0, (s, c) => s + c.face);
    final profit = totalRevenue - batch.cost;

    // Per person stats
    final persons = prov.data.persons;
    final personStats = <String, Map<String, dynamic>>{};
    for (final p in persons) {
      final pCards = soldCards.where((c) => c.soldBy == p).toList();
      final pRev = pCards.fold<double>(0, (s, c) => s + c.soldPrice);
      personStats[p] = {'count': pCards.length, 'revenue': pRev};
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📊 批次总览', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            _row('批次名称', batch.name),
            _row('总卡数', '$total 张'),
            _row('已卖 / 剩余 / 坏卡', '${soldCards.length} / ${unsold.length} / ${badCards.length}'),
            _row('总面值', '¥${totalFace.toStringAsFixed(2)}'),
            _row('进货成本', '¥${batch.cost.toStringAsFixed(2)}'),
            _row('总收入', '¥${totalRevenue.toStringAsFixed(2)}'),
            if (badCards.isNotEmpty) _row('坏卡损失', '¥${badFace.toStringAsFixed(2)}', color: Colors.red),
            const Divider(),
            _row('利润', '¥${profit.toStringAsFixed(2)}', color: profit >= 0 ? Colors.green : Colors.red, bold: true),

            const SizedBox(height: 16),
            const Text('👥 各人统计', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            ...persons.map((p) {
              final stats = personStats[p]!;
              return _row(p, '${stats['count']}张  ¥${(stats['revenue'] as double).toStringAsFixed(2)}');
            }),

            if (persons.length >= 2) ...[
              const SizedBox(height: 16),
              const Text('💰 结算', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              Builder(builder: (_) {
                final share = profit / persons.length;
                final lines = <Widget>[];
                for (final p in persons) {
                  final pRev = (personStats[p]!['revenue'] as double);
                  final diff = pRev - share - (batch.cost / persons.length);
                  if (diff > 0.01) {
                    lines.add(Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('$p 需转出 ¥${diff.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    ));
                  } else if (diff < -0.01) {
                    lines.add(Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('$p 应收 ¥${(-diff).toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ));
                  } else {
                    lines.add(Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('$p 已结清', style: const TextStyle(color: Colors.grey)),
                    ));
                  }
                }
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : null)),
        ],
      ),
    );
  }
}
