import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart';

class DepositsScreen extends StatefulWidget {
  const DepositsScreen({super.key});
  @override
  State<DepositsScreen> createState() => _DepositsScreenState();
}

class _DepositsScreenState extends State<DepositsScreen> {
  final _db = DatabaseService();
  List<_Entry> _entries = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _db.getDepositsData();
    if (!mounted) return;
    setState(() {
      _entries = rows.map((r) => _Entry(
          playerId: r['id'] as int,
          nickname: r['nickname'] as String,
          balance: (r['balance'] as num).toDouble())).toList();
      _loading = false;
    });
  }

  // ── Диалог добавления депозита ──────────────────────────────────────────────
  // Исправление: используем простой Column вместо ListView внутри AlertDialog,
  // чтобы избежать ошибки "RenderShrinkWrappingViewport intrinsic dimensions"
  Future<void> _showAddDialog({String? prefilledNick}) async {
    final allPlayers = await _db.getAllPlayers();
    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    final nickCtrl = TextEditingController(text: prefilledNick ?? '');
    final amtCtrl  = TextEditingController();
    var suggestions = <Player>[];
    var showSuggestions = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          void updateSugg(String text) {
            final q = text.trim().toLowerCase();
            setSt(() {
              if (q.isEmpty) { suggestions = []; showSuggestions = false; return; }
              suggestions = allPlayers
                  .where((p) => p.nickname.toLowerCase().contains(q))
                  .take(5)
                  .toList();
              showSuggestions = suggestions.isNotEmpty;
            });
          }

          return AlertDialog(
            title: const Text('Добавить депозит'),
            // Ключевое исправление: НЕ оборачиваем в SingleChildScrollView с ListView
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Поле ника
                        TextFormField(
                          controller: nickCtrl,
                          enabled: prefilledNick == null,
                          decoration: InputDecoration(
                            labelText: 'Никнейм',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: prefilledNick == null ? updateSugg : null,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Введите никнейм' : null,
                        ),

                        // Подсказки — простой Column, не ListView
                        if (showSuggestions) ...[
                          const SizedBox(height: 4),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Theme.of(ctx).colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: suggestions.map((p) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.person, size: 18),
                                title: Text(p.nickname),
                                onTap: () {
                                  nickCtrl.text = p.nickname;
                                  setSt(() { showSuggestions = false; suggestions = []; });
                                },
                              )).toList(),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Поле суммы
                        TextFormField(
                          controller: amtCtrl,
                          decoration: InputDecoration(
                            labelText: 'Сумма пополнения',
                            suffixText: '₽',
                            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Введите сумму';
                            final n = double.tryParse(v.trim().replaceAll(',', '.'));
                            if (n == null || n <= 0) return 'Сумма должна быть > 0';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final nick = nickCtrl.text.trim();
                  final amt = double.parse(amtCtrl.text.trim().replaceAll(',', '.'));
                  Navigator.pop(ctx);
                  await _saveDeposit(nick, amt);
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveDeposit(String nick, double amt) async {
    final pid = await _db.upsertPlayer(nick);
    await _db.createTransaction(DepositTransaction(
        playerId: pid, amount: amt, createdAt: DateTime.now()));
    if (!mounted) return;
    _snack('Депозит ${formatRubles(amt)} добавлен игроку «$nick»');
    _load();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Депозиты'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _empty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _entries.length,
                    itemBuilder: (_, i) => _DepositTile(
                      entry: _entries[i],
                      onTap: () => _showAddDialog(prefilledNick: _entries[i].nickname),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Добавить депозит')),
    );
  }

  Widget _empty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.account_balance_wallet_outlined, size: 72,
          color: Theme.of(context).colorScheme.outlineVariant),
      const SizedBox(height: 16),
      Text('Депозитов пока нет',
          style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      const SizedBox(height: 8),
      Text('Нажмите «+», чтобы добавить первый',
          style: TextStyle(color: Theme.of(context).colorScheme.outlineVariant)),
    ],
  ));
}

class _Entry {
  final int playerId;
  final String nickname;
  final double balance;
  const _Entry({required this.playerId, required this.nickname, required this.balance});
}

class _DepositTile extends StatelessWidget {
  final _Entry entry;
  final VoidCallback onTap;
  const _DepositTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final neg = entry.balance < 0;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: neg ? s.errorContainer : s.primaryContainer,
          child: Text(entry.nickname[0].toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold,
                  color: neg ? s.onErrorContainer : s.onPrimaryContainer)),
        ),
        title: Text(entry.nickname, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Нажмите для пополнения'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(neg ? '−${formatRubles(entry.balance)}' : formatRubles(entry.balance),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: neg ? s.error : Colors.green.shade700)),
            Text(neg ? 'долг' : 'баланс',
                style: TextStyle(fontSize: 11, color: s.outline)),
          ],
        ),
      ),
    );
  }
}
