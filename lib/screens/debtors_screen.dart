import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart';

class DebtorsScreen extends StatefulWidget {
  const DebtorsScreen({super.key});
  @override
  State<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends State<DebtorsScreen> {
  final _db = DatabaseService();
  List<_Debtor> _debtors = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _db.getDebtorsData();
    if (!mounted) return;
    setState(() {
      _debtors = rows.map((r) => _Debtor(
          playerId: r['id'] as int,
          nickname: r['nickname'] as String,
          balance: (r['balance'] as num).toDouble())).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Должники'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _debtors.isEmpty
              ? _empty()
              : Column(children: [
                  _Banner(debtors: _debtors),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _debtors.length,
                        itemBuilder: (_, i) => _DebtorTile(
                          debtor: _debtors[i],
                          rank: i + 1,
                          onTap: () => _showUnpaidNights(_debtors[i]),
                        ),
                      ),
                    ),
                  ),
                ]),
    );
  }

  Future<void> _showUnpaidNights(_Debtor d) async {
    final rows = await _db.getUnpaidNightsForPlayer(d.playerId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final s = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (_, ctrl) => Column(children: [
            // Ручка
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: s.outlineVariant,
                      borderRadius: BorderRadius.circular(2))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                CircleAvatar(backgroundColor: s.errorContainer,
                    child: Text(d.nickname[0].toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.bold,
                            color: s.onErrorContainer))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.nickname,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Долг: ${formatRubles(d.balance)}',
                      style: TextStyle(color: s.error, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Вечера, за которые не оплачено:',
                    style: TextStyle(color: s.outline, fontWeight: FontWeight.w600)),
              ),
            ),
            rows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Нет данных'),
                  )
                : Expanded(
                    child: ListView.builder(
                      controller: ctrl,
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        final date = DateTime.parse(r['created_at'] as String);
                        final amt  = (r['amount'] as num).toDouble();
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: s.errorContainer,
                            child: Text('${i + 1}',
                                style: TextStyle(fontSize: 12, color: s.onErrorContainer)),
                          ),
                          title: Text(r['title'] as String,
                              style: const TextStyle(fontSize: 14)),
                          subtitle: Text(formatDate(date),
                              style: TextStyle(color: s.outline, fontSize: 12)),
                          trailing: Text('−${formatRubles(amt)}',
                              style: TextStyle(color: s.error,
                                  fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                  ),
          ]),
        );
      },
    );
  }

  Widget _empty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.sentiment_satisfied_alt_outlined, size: 72,
          color: Colors.green.shade300),
      const SizedBox(height: 16),
      Text('Должников нет!',
          style: TextStyle(color: Colors.green.shade700,
              fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 8),
      Text('Все депозиты в плюсе',
          style: TextStyle(color: Theme.of(context).colorScheme.outlineVariant)),
    ],
  ));
}

class _Debtor {
  final int playerId;
  final String nickname;
  final double balance;
  const _Debtor({required this.playerId, required this.nickname, required this.balance});
}

class _Banner extends StatelessWidget {
  final List<_Debtor> debtors;
  const _Banner({required this.debtors});
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final total = debtors.fold<double>(0, (s, d) => s + d.balance.abs());
    final n = debtors.length;
    final word = n % 10 == 1 && n % 100 != 11 ? 'должник'
        : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) ? 'должника'
        : 'должников';
    return Material(
      color: s.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, color: s.error, size: 28),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$n $word', style: TextStyle(color: s.onErrorContainer,
                fontWeight: FontWeight.w600)),
            Text('Суммарный долг: ${formatRubles(total)}',
                style: TextStyle(color: s.onErrorContainer, fontSize: 13)),
          ]),
        ]),
      ),
    );
  }
}

class _DebtorTile extends StatelessWidget {
  final _Debtor debtor;
  final int rank;
  final VoidCallback onTap;
  const _DebtorTile({required this.debtor, required this.rank, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: s.errorContainer,
            child: Text('$rank',
                style: TextStyle(fontWeight: FontWeight.bold,
                    color: s.onErrorContainer))),
        title: Text(debtor.nickname,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Нажмите, чтобы увидеть вечера'),
        trailing: Text('−${formatRubles(debtor.balance)}',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                color: s.error)),
      ),
    );
  }
}
