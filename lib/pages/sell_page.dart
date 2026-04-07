import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/card_tile.dart';

class SellPage extends StatefulWidget {
  const SellPage({super.key});
  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  String? _batchId;
  final Set<String> _selected = {};

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final batches = prov.data.batches;
    final batch = _batchId != null ? batches.where((b) => b.id == _batchId).firstOrNull : null;

    final hasUnsoldSelected = _selected.isNotEmpty && batch != null &&
        batch.cards.any((c) => _selected.contains(c.id) && !c.sold && !c.bad);
    final hasSoldSelected = _selected.isNotEmpty && batch != null &&
        batch.cards.any((c) => _selected.contains(c.id) && (c.sold || c.bad));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: _batchId,
          decoration: const InputDecoration(labelText: '选择批次', border: OutlineInputBorder(), isDense: true),
          items: batches.map((b) {
            final remain = b.cards.where((c) => !c.sold && !c.bad).length;
            return DropdownMenuItem(value: b.id, child: Text('${b.name} (剩${remain}张)'));
          }).toList(),
          onChanged: (v) => setState(() { _batchId = v; _selected.clear(); }),
        ),
        const SizedBox(height: 16),

        if (batch != null) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, childAspectRatio: 0.85, crossAxisSpacing: 6, mainAxisSpacing: 6,
            ),
            itemCount: batch.cards.length,
            itemBuilder: (_, i) {
              final c = batch.cards[i];
              return CardTile(
                card: c,
                selected: _selected.contains(c.id),
                onTap: () {
                  setState(() {
                    if (_selected.contains(c.id)) {
                      _selected.remove(c.id);
                    } else {
                      _selected.add(c.id);
                    }
                  });
                },
                onLongPress: () {
                  final text = c.secret.isNotEmpty ? '${c.label} ${c.secret}' : c.label;
                  Clipboard.setData(ClipboardData(text: text));
                  _msg('已复制: ${c.label}');
                },
              );
            },
          ),
          const SizedBox(height: 16),

          if (_selected.isNotEmpty)
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('已选 ${_selected.length} 张卡', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (hasUnsoldSelected)
                          FilledButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('确认卖出'),
                            onPressed: () async {
                              final unsoldIds = batch.cards
                                  .where((c) => _selected.contains(c.id) && !c.sold && !c.bad)
                                  .map((c) => c.id)
                                  .toSet();
                              if (unsoldIds.isEmpty) return;
                              final seller = prov.myRole ?? '未知';
                              await prov.sellCards(_batchId!, unsoldIds, seller);
                              _msg('已标记 ${unsoldIds.length} 张卡为已卖');
                              setState(() => _selected.clear());
                            },
                          ),
                        FilledButton.icon(
                          icon: const Icon(Icons.warning),
                          label: const Text('标记坏卡'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () async {
                            final balanceCtrl = TextEditingController(text: '0');
                            final result = await showDialog<double?>(context: context, builder: (ctx) => AlertDialog(
                              title: const Text('标记坏卡'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('确定将 ${_selected.length} 张卡标记为坏卡？'),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: balanceCtrl,
                                    decoration: const InputDecoration(
                                      labelText: '实际余额（每张）',
                                      hintText: '0 = 完全无效，如面值20实际5则填5',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('取消')),
                                TextButton(onPressed: () => Navigator.pop(ctx, double.tryParse(balanceCtrl.text) ?? 0), child: const Text('确定', style: TextStyle(color: Colors.red))),
                              ],
                            ));
                            if (result != null) {
                              await prov.markBad(_batchId!, _selected, actualBalance: result);
                              _msg('已标记 ${_selected.length} 张坏卡${result > 0 ? "（余额$result）" : ""}');
                              setState(() => _selected.clear());
                            }
                          },
                        ),
                        if (hasSoldSelected)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.undo),
                            label: const Text('撤销'),
                            onPressed: () async {
                              await prov.undoCards(_batchId!, _selected);
                              _msg('已撤销 ${_selected.length} 张卡');
                              setState(() => _selected.clear());
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
