import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart';

// ── Экран истории: список всех игроков ───────────────────────────────────────
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = DatabaseService();
  List<Player> _all = [];
  List<Player> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filter);
    _load();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final players = await _db.getPlayersWithHistory();
    if (!mounted) return;
    setState(() { _all = players; _filtered = players; _loading = false; });
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((p) => p.nickname.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('История'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Поиск
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Поиск по нику…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear),
                            onPressed: () { _searchCtrl.clear(); })
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),

              // Список
              Expanded(
                child: _filtered.isEmpty
                    ? Center(child: Text(
                        _all.isEmpty ? 'Нет данных — сначала создайте вечер' : 'Никого не найдено',
                        style: TextStyle(color: Theme.of(context).colorScheme.outline),
                      ))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final p = _filtered[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text(p.nickname[0].toUpperCase(),
                                    style: TextStyle(fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer)),
                              ),
                              title: Text(p.nickname,
                                  style: const TextStyle(fontWeight: FontWeight.w500)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => PlayerHistoryScreen(player: p))),
                            );
                          },
                        ),
                      ),
              ),
            ]),
    );
  }
}

// ── Экран истории конкретного игрока ─────────────────────────────────────────
class PlayerHistoryScreen extends StatefulWidget {
  final Player player;
  const PlayerHistoryScreen({super.key, required this.player});
  @override
  State<PlayerHistoryScreen> createState() => _PlayerHistoryScreenState();
}

class _PlayerHistoryScreenState extends State<PlayerHistoryScreen> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _history = [];
  double _balance = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final h = await _db.getPlayerHistory(widget.player.id!);
    final b = await _db.getPlayerBalance(widget.player.id!);
    if (!mounted) return;
    setState(() { _history = h; _balance = b; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final negBalance = _balance < 0;

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.player.nickname), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Шапка с балансом
              Material(
                color: negBalance ? s.errorContainer : s.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(children: [
                    CircleAvatar(
                      backgroundColor: negBalance ? s.error : s.primary,
                      child: Text(widget.player.nickname[0].toUpperCase(),
                          style: TextStyle(color: s.onPrimary,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Текущий баланс',
                          style: TextStyle(fontSize: 12,
                              color: negBalance ? s.onErrorContainer : s.onPrimaryContainer)),
                      Text(
                        negBalance
                            ? '−${formatRubles(_balance)}'
                            : formatRubles(_balance),
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold,
                            color: negBalance ? s.error : s.primary),
                      ),
                    ]),
                    const Spacer(),
                    Text('${_history.length} ${_plVech(_history.length)}',
                        style: TextStyle(
                            color: negBalance ? s.onErrorContainer : s.onPrimaryContainer)),
                  ]),
                ),
              ),

              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Вечера', style: TextStyle(color: s.outline,
                      fontWeight: FontWeight.w600)),
                ),
              ),

              // История вечеров
              Expanded(
                child: _history.isEmpty
                    ? Center(child: Text('Нет вечеров',
                        style: TextStyle(color: s.outlineVariant)))
                    : ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (_, i) {
                          final r = _history[i];
                          final dt    = DateTime.parse(r['created_at'] as String);
                          final pm    = PaymentMethodX.fromKey(r['payment_method'] as String?);
                          final closed = (r['is_closed'] as int) == 1;
                          return _NightRow(
                            title: r['title'] as String,
                            date: dt,
                            paymentMethod: pm,
                            isClosed: closed,
                          );
                        },
                      ),
              ),
            ]),
    );
  }

  String _plVech(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'вечер';
    if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) return 'вечера';
    return 'вечеров';
  }
}

class _NightRow extends StatelessWidget {
  final String title;
  final DateTime date;
  final PaymentMethod paymentMethod;
  final bool isClosed;

  const _NightRow({
    required this.title, required this.date,
    required this.paymentMethod, required this.isClosed,
  });

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;

    Color pmColor;
    IconData pmIcon;
    switch (paymentMethod) {
      case PaymentMethod.unpaid:
        pmColor = s.error; pmIcon = Icons.money_off_outlined; break;
      case PaymentMethod.deposit:
        pmColor = s.primary; pmIcon = Icons.account_balance_wallet_outlined; break;
      case PaymentMethod.transfer:
        pmColor = Colors.blue.shade700; pmIcon = Icons.send_outlined; break;
      case PaymentMethod.cash:
        pmColor = Colors.green.shade700; pmIcon = Icons.payments_outlined; break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isClosed ? s.surfaceContainerHighest : s.primaryContainer,
          child: Icon(
            isClosed ? Icons.lock_outline : Icons.lock_open_outlined,
            size: 18,
            color: isClosed ? s.outline : s.primary,
          ),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(formatDate(date), style: TextStyle(color: s.outline, fontSize: 12)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(pmIcon, color: pmColor, size: 16),
          const SizedBox(width: 4),
          Text(paymentMethod.label,
              style: TextStyle(color: pmColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
