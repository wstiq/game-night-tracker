import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart';
import 'create_night_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService();
  List<GameNight> _nights = [];
  final Map<int, int> _counts = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final nights = await _db.getAllGameNights();
    _counts.clear();
    for (final n in nights) {
      if (n.id != null) _counts[n.id!] = await _db.getParticipantCount(n.id!);
    }
    if (!mounted) return;
    setState(() { _nights = nights; _loading = false; });
  }

  Future<void> _createNight() async {
    final now = DateTime.now();
    final id = await _db.createGameNight(
        GameNight(title: formatNightTitle(now), createdAt: now));
    if (!mounted) return;
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => CreateNightScreen(nightId: id)));
    _load();
  }

  Future<void> _openNight(GameNight n) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => CreateNightScreen(nightId: n.id!)));
    _load();
  }

  Future<void> _deleteNight(GameNight n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить вечер?'),
        content: Text('Вечер «${n.title}» и все связанные данные будут удалены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true) { await _db.deleteGameNight(n.id!); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Игровые вечера'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _nights.isEmpty
              ? _empty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _nights.length,
                    itemBuilder: (_, i) => _NightCard(
                      night: _nights[i],
                      count: _counts[_nights[i].id] ?? 0,
                      onTap: () => _openNight(_nights[i]),
                      onDelete: () => _deleteNight(_nights[i]),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
          onPressed: _createNight, tooltip: 'Создать вечер',
          child: const Icon(Icons.add)),
    );
  }

  Widget _empty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.nights_stay_outlined, size: 72,
          color: Theme.of(context).colorScheme.outlineVariant),
      const SizedBox(height: 16),
      Text('Пока нет ни одного вечера',
          style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      const SizedBox(height: 8),
      Text('Нажмите «+», чтобы создать первый',
          style: TextStyle(color: Theme.of(context).colorScheme.outlineVariant)),
    ],
  ));
}

class _NightCard extends StatelessWidget {
  final GameNight night;
  final int count;
  final VoidCallback onTap, onDelete;
  const _NightCard({required this.night, required this.count,
      required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(night.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async { onDelete(); return false; },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: s.errorContainer,
        child: Icon(Icons.delete_outline, color: s.onErrorContainer),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: night.isClosed ? s.surfaceContainerHighest : s.primaryContainer,
            child: Icon(night.isClosed ? Icons.lock_outline : Icons.lock_open_outlined,
                color: night.isClosed ? s.outline : s.primary),
          ),
          title: Text(night.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('$count ${_pl(count)}'),
          trailing: Chip(
            label: Text(night.isClosed ? 'Закрыт' : 'Открыт',
                style: TextStyle(fontSize: 12,
                    color: night.isClosed ? s.onErrorContainer : s.onPrimaryContainer)),
            backgroundColor: night.isClosed ? s.errorContainer : s.primaryContainer,
            side: BorderSide.none, padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  String _pl(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'участник';
    if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) return 'участника';
    return 'участников';
  }
}
