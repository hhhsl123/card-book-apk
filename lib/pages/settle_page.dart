import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data.dart';

class SettlePage extends StatefulWidget {
  const SettlePage({super.key});
  @override
  State<SettlePage> createState() => _SettlePageState();
}

class _SettlePageState extends State<SettlePage> {
  String? _batchId;
  String? _payer;
  final _paidCtrl = TextEditingController();

  String _fmtFace(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final batches = prov.data.batches;
    final batch = _batchId != null ? batches.where((b) => b.id == _batchId).firstOrNull : null;
    final persons = prov.data.persons;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: _batchId,
          decoration: const InputDecoration(labelText: '选择批次', border: OutlineInputBorder(), isDense: true),
          items: batches.reversed.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
          onChanged: (v) => setState(() { _batchId = v; _payer = null; _paidCtrl.clear(); }),
        ),

        if (batch != null) ...[
          const SizedBox(height: 16),
          _buildBatchSummary(batch),
          const SizedBox(height: 16),
          ...persons.map((p) => _buildPersonDetail(batch, p)),
          const SizedBox(height: 16),
          _buildSettleCalc(batch, persons),
        ],
      ],
    );
  }

  Widget _buildBatchSummary(Batch batch) {
    final total = batch.cards.length;
    final soldCards = batch.cards.where((c) => c.sold && !c.bad).toList();
    final badCards = batch.cards.where((c) => c.bad).toList();
    final unsoldCards = batch.cards.where((c) => !c.sold && !c.bad).toList();
    final totalFace = batch.cards.fold<double>(0, (s, c) => s + c.face);
    final totalCost = totalFace * batch.rate;
    final soldFace = soldCards.fold<double>(0, (s, c) => s + c.face);
    final badFace = badCards.fold<double>(0, (s, c) => s + c.face);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('批次总览', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            _row('批次', batch.name),
            _row('日期 / 汇率', '${batch.batchDate} / ${batch.rate}'),
            _row('总卡数', '$total 张'),
            _row('已卖 / 剩余 / 坏卡', '${soldCards.length} / ${unsoldCards.length} / ${badCards.length}'),
            _row('总面值', '¥${_fmtFace(totalFace)}'),
            _row('总成本 (面值×汇率)', '¥${_fmtFace(totalCost)}'),
            _row('已售总面值', '¥${_fmtFace(soldFace)}'),
            if (badCards.isNotEmpty) _row('坏卡面值', '¥${_fmtFace(badFace)}', color: Colors.red),
            const Divider(),
            _row('总收入 (已售面值)', '¥${_fmtFace(soldFace)}', bold: true),
            _row('总利润', '¥${_fmtFace(soldFace - totalCost)}', color: (soldFace - totalCost) >= 0 ? Colors.green : Colors.red, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonDetail(Batch batch, String person) {
    final pCards = batch.cards.where((c) => c.sold && !c.bad && c.soldBy == person).toList();
    final pFace = pCards.fold<double>(0, (s, c) => s + c.face);
    final pCost = pFace * batch.rate;
    final pProfit = pFace - pCost;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(person, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const Spacer(),
              Text('${pCards.length}张 · 面值¥${_fmtFace(pFace)} · 利润¥${_fmtFace(pProfit)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]),
            if (pCards.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: pCards.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(children: [
                      Expanded(child: Text(c.label, style: const TextStyle(fontFamily: 'monospace', fontSize: 11), overflow: TextOverflow.ellipsis)),
                      Text('面值¥${_fmtFace(c.face)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ]),
                  )).toList(),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('暂无售出记录', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettleCalc(Batch batch, List<String> persons) {
    final soldCards = batch.cards.where((c) => c.sold && !c.bad).toList();
    final totalFace = batch.cards.fold<double>(0, (s, c) => s + c.face);
    final totalCost = totalFace * batch.rate;
    final totalRevenue = soldCards.fold<double>(0, (s, c) => s + c.face);

    final personRevenue = <String, double>{};
    for (final p in persons) {
      personRevenue[p] = batch.cards
          .where((c) => c.sold && !c.bad && c.soldBy == p)
          .fold<double>(0, (s, c) => s + c.face);
    }

    final paid = double.tryParse(_paidCtrl.text) ?? 0;

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('结算计算器', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),

            const Text('谁付的货款？', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: persons.map((p) => ChoiceChip(
                label: Text(p),
                selected: _payer == p,
                onSelected: (sel) => setState(() => _payer = sel ? p : null),
              )).toList(),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _paidCtrl,
              decoration: InputDecoration(
                labelText: '实际付款金额',
                hintText: '建议值: ${_fmtFace(totalCost)}',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            if (paid > 0) ...[
              _row('实际付款', '¥${_fmtFace(paid)}'),
              _row('总售出收入', '¥${_fmtFace(totalRevenue)}'),
              _row('总利润', '¥${_fmtFace(totalRevenue - paid)}',
                color: (totalRevenue - paid) >= 0 ? Colors.green : Colors.red, bold: true),
            ],

            if (_payer != null && paid > 0 && persons.length >= 2) ...[
              const Divider(),
              const Text('结算结果', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),

              Builder(builder: (_) {
                final profit = totalRevenue - paid;
                final profitShare = profit / persons.length;
                final costShare = paid / persons.length;

                final results = <Widget>[];
                for (final p in persons) {
                  final rev = personRevenue[p] ?? 0;
                  if (p == _payer) {
                    // Payer: paid the full cost, collected their revenue
                    // Should end up with: profitShare
                    // Currently has: rev - paid (revenue minus what they paid)
                    // Others should transfer: profitShare - (rev - paid)
                    results.add(_row('$p (付款人)', '收入¥${_fmtFace(rev)}，付款¥${_fmtFace(paid)}'));
                  } else {
                    // Non-payer should transfer to payer
                    final shouldTransfer = rev - profitShare;
                    if (shouldTransfer > 0.01) {
                      results.add(Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$p 收入¥${_fmtFace(rev)}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                              Text('$p 应分利润¥${_fmtFace(profitShare)}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                              const SizedBox(height: 4),
                              Text('$p 应转给 $_payer：¥${_fmtFace(shouldTransfer)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
                            ],
                          ),
                        ),
                      ));
                    } else if (shouldTransfer < -0.01) {
                      results.add(Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$p 收入¥${_fmtFace(rev)}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                              Text('$p 应分利润¥${_fmtFace(profitShare)}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                              const SizedBox(height: 4),
                              Text('$_payer 应转给 $p：¥${_fmtFace(-shouldTransfer)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                            ],
                          ),
                        ),
                      ));
                    } else {
                      results.add(_row(p, '已结清', color: Colors.grey));
                    }
                  }
                }
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: results);
              }),

              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '计算逻辑：\n'
                  '总利润 = 总售出收入 - 实际付款\n'
                  '每人应分利润 = 总利润 ÷ ${persons.length}\n'
                  '转账金额 = 个人收入 - 应分利润',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
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
          Flexible(child: Text(label, style: TextStyle(color: Colors.grey[600]))),
          Text(value, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : null)),
        ],
      ),
    );
  }
}
