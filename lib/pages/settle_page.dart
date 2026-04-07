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
  String? _expandedBatchId;
  String? _payer;
  final _paidCtrl = TextEditingController();

  String _fmtFace(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final batches = List.of(prov.data.batches)..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (batches.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('暂无批次', style: TextStyle(color: Colors.grey[500])),
          ))
        else
          ...batches.map((b) => _buildBatchCard(prov, b)),
      ],
    );
  }

  Widget _buildBatchCard(AppProvider prov, Batch batch) {
    final isExpanded = _expandedBatchId == batch.id;
    final soldCards = batch.cards.where((c) => c.sold && !c.bad).toList();
    final badCards = batch.cards.where((c) => c.bad).toList();
    final unsoldCards = batch.cards.where((c) => !c.sold && !c.bad).toList();
    final totalFace = batch.cards.fold<double>(0, (s, c) => s + c.face);
    final totalCost = totalFace * batch.rate;
    final soldFace = soldCards.fold<double>(0, (s, c) => s + c.face);
    final badRecovered = badCards.fold<double>(0, (s, c) => s + c.soldPrice);
    final totalRevenue = soldFace + badRecovered;
    final persons = prov.data.persons;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedBatchId = null;
              } else {
                _expandedBatchId = batch.id;
                _payer = null;
                _paidCtrl.clear();
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(batch.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${batch.batchDate} · 汇率${batch.rate} · ${batch.cards.length}张 · 已卖${soldCards.length}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                )),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('收入¥${_fmtFace(totalRevenue)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text('成本¥${_fmtFace(totalCost)}', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey),
              ]),
            ),
          ),

          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary
                  _row('总卡数', '${batch.cards.length} 张'),
                  _row('已卖 / 剩余 / 坏卡', '${soldCards.length} / ${unsoldCards.length} / ${badCards.length}'),
                  _row('总面值', '¥${_fmtFace(totalFace)}'),
                  _row('总成本 (面值×汇率)', '¥${_fmtFace(totalCost)}'),
                  _row('已售面值', '¥${_fmtFace(soldFace)}'),
                  if (badRecovered > 0) _row('坏卡回收余额', '¥${_fmtFace(badRecovered)}'),
                  _row('总收入', '¥${_fmtFace(totalRevenue)}', bold: true),
                  _row('利润', '¥${_fmtFace(totalRevenue - totalCost)}',
                    color: (totalRevenue - totalCost) >= 0 ? Colors.green : Colors.red, bold: true),

                  const Divider(height: 24),

                  // Per person
                  ...persons.map((p) {
                    final pCards = batch.cards.where((c) => c.sold && !c.bad && c.soldBy == p).toList();
                    final pFace = pCards.fold<double>(0, (s, c) => s + c.face);
                    return ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      title: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(8)),
                          child: Text(p, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        const Spacer(),
                        Text('${pCards.length}张 · ¥${_fmtFace(pFace)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ]),
                      children: pCards.isEmpty
                        ? [Text('暂无售出', style: TextStyle(fontSize: 12, color: Colors.grey[400]))]
                        : pCards.map((c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Row(children: [
                              Expanded(child: Text(c.label, style: const TextStyle(fontFamily: 'monospace', fontSize: 11), overflow: TextOverflow.ellipsis)),
                              Text('¥${_fmtFace(c.face)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            ]),
                          )).toList(),
                    );
                  }),

                  const Divider(height: 24),

                  // Settlement calculator
                  const Text('结算', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  const Text('谁付的货款？', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: persons.map((p) => ChoiceChip(
                      label: Text(p),
                      selected: _payer == p,
                      onSelected: (sel) => setState(() => _payer = sel ? p : null),
                    )).toList(),
                  ),
                  const SizedBox(height: 10),
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

                  if (_payer != null && (double.tryParse(_paidCtrl.text) ?? 0) > 0) ...[
                    const SizedBox(height: 12),
                    Builder(builder: (_) {
                      final paid = double.tryParse(_paidCtrl.text) ?? 0;
                      final profit = totalRevenue - paid;
                      final profitShare = profit / persons.length;

                      final personRevenue = <String, double>{};
                      for (final p in persons) {
                        personRevenue[p] = batch.cards
                            .where((c) => c.sold && !c.bad && c.soldBy == p)
                            .fold<double>(0, (s, c) => s + c.face);
                      }

                      final results = <Widget>[];
                      for (final p in persons) {
                        if (p == _payer) continue;
                        final rev = personRevenue[p] ?? 0;
                        final shouldTransfer = rev - profitShare;
                        if (shouldTransfer > 0.01) {
                          results.add(Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                            child: Text('$p 应转给 $_payer：¥${_fmtFace(shouldTransfer)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.deepOrange)),
                          ));
                        } else if (shouldTransfer < -0.01) {
                          results.add(Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                            child: Text('$_payer 应转给 $p：¥${_fmtFace(-shouldTransfer)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
                          ));
                        } else {
                          results.add(Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                            child: Text('$p 已结清', style: TextStyle(color: Colors.grey[600])),
                          ));
                        }
                      }

                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _row('总利润', '¥${_fmtFace(profit)}', color: profit >= 0 ? Colors.green : Colors.red, bold: true),
                        _row('每人分利', '¥${_fmtFace(profitShare)}'),
                        const SizedBox(height: 8),
                        ...results,
                      ]);
                    }),
                  ],

                  const Divider(height: 24),

                  // Clear account button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_sweep, color: Colors.red),
                      label: const Text('清账（删除此批次）', style: TextStyle(color: Colors.red)),
                      onPressed: () async {
                        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                          title: const Text('清账确认'),
                          content: Text('确定清账并删除批次"${batch.name}"的所有记录？此操作不可撤销。'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定清账', style: TextStyle(color: Colors.red))),
                          ],
                        ));
                        if (ok == true) {
                          await prov.deleteBatch(batch.id);
                          setState(() => _expandedBatchId = null);
                          _msg('已清账: ${batch.name}');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: bold ? FontWeight.bold : null)),
        ],
      ),
    );
  }
}
