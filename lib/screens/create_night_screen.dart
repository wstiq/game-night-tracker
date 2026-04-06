import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';

class CreateNightScreen extends StatefulWidget {
  final int nightId;
  const CreateNightScreen({super.key, required this.nightId});
  @override
  State<CreateNightScreen> createState() => _CreateNightScreenState();
}

class _CreateNightScreenState extends State<CreateNightScreen> {
  final _db = DatabaseService();
  final _nickCtrl = TextEditingController();
  final _focus = FocusNode();

  GameNight? _night;
  List<NightParticipant> _parts = [];
  bool _loading = true, _saving = false;

  static const double _cost = 400;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _nickCtrl.dispose(); _focus.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _night = await _db.getGameNightById(widget.nightId);
    _parts = await _db.getParticipants(widget.nightId);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _add() async {
    final nick = _nickCtrl.text.trim();
    if (nick.isEmpty) return;
    if (_parts.any((p) => p.nickname.toLowerCase() == nick.toLowerCase())) {
      _snack('«$nick» уже в списке'); _nickCtrl.clear(); return;
    }
    final pid = await _db.upsertPlayer(nick);
    // Новый участник добавляется с дефолтом PaymentMethod.unpaid
    final id = await _db.addParticipant(NightParticipant(
        nightId: widget.nightId, playerId: pid));
    if (!mounted) return;
    setState(() => _parts.add(NightParticipant(
        id: id, nightId: widget.nightId, playerId: pid, nickname: nick)));
    _nickCtrl.clear();
    _focus.requestFocus();
  }

  Future<void> _setPayment(int idx, PaymentMethod method) async {
    if (_night?.isClosed == true) return;
    final updated = _parts[idx].copyWith(paymentMethod: method);
    await _db.updateParticipant(updated);
    setState(() => _parts[idx] = updated);
  }

  Future<void> _remove(int idx) async {
    if (_night?.isClosed == true) return;
    await _db.deleteParticipant(_parts[idx].id!);
    setState(() => _parts.removeAt(idx));
  }

  // ── Закрытие вечера с валидацией ─────────────────────────────────────────────
  Future<void> _close() async {
    if (_parts.isEmpty) {
      _snack('Добавьте хотя бы одного участника'); return;
    }

    // Проверяем: у кого стоит «Списать с депозита» — у того должен быть депозит
    final badPlayers = <String>[];
    for (final p in _parts) {
      if (p.paymentMethod == PaymentMethod.deposit) {
        final hasDeposit = await _db.playerHasDeposit(p.playerId);
        if (!hasDeposit) badPlayers.add(p.nickname);
      }
    }

    if (badPlayers.isNotEmpty) {
      final names = badPlayers.join(', ');
      _snack(
        'У ${badPlayers.length == 1 ? "«$names»" : "игроков: $names"} нет депозита. '
            'Измените способ оплаты или пополните депозит.',
      );
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();

    for (final p in _parts) {
      // Списание создаётся для «депозита» и «не оплачено»
      if (p.paymentMethod == PaymentMethod.deposit ||
          p.paymentMethod == PaymentMethod.unpaid) {
        await _db.createTransaction(DepositTransaction(
            playerId: p.playerId,
            amount: -_cost,
            nightId: widget.nightId,
            createdAt: now));
      }
    }

    final updated = _night!.copyWith(isClosed: true);
    await _db.updateGameNight(updated);
    if (!mounted) return;
    setState(() { _night = updated; _saving = false; });
    _snack('Вечер закрыт. Списания выполнены.');
  }

  Future<void> _reopen() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Переоткрыть вечер?'),
        content: const Text('Все списания за этот вечер будут отменены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Переоткрыть')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    await _db.deleteTransactionsByNightId(widget.nightId);
    final updated = _night!.copyWith(isClosed: false);
    await _db.updateGameNight(updated);
    if (!mounted) return;
    setState(() { _night = updated; _saving = false; });
    _snack('Вечер переоткрыт. Списания отменены.');
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final closed = _night?.isClosed ?? false;

    return Scaffold(
      appBar: AppBar(
          title: Text(_night?.title ?? '…', style: const TextStyle(fontSize: 15)),
          centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
        if (closed)
          Material(
            color: s.errorContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Icon(Icons.lock_outline, size: 18, color: s.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(child: Text(
                    'Вечер закрыт. Нажмите «Переоткрыть» для редактирования.',
                    style: TextStyle(color: s.onErrorContainer, fontSize: 13))),
              ]),
            ),
          ),

        if (!closed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _nickCtrl,
                  focusNode: _focus,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'Ник игрока',
                    prefixIcon: const Icon(Icons.person_add_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _add,
                  style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: const Icon(Icons.add)),
            ]),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Участники (${_parts.length})',
                style: TextStyle(color: s.outline, fontWeight: FontWeight.w600)),
          ),
        ),

        Expanded(
          child: _parts.isEmpty
              ? Center(child: Text(
              closed ? 'Нет участников' : 'Добавьте первого участника',
              style: TextStyle(color: s.outlineVariant)))
              : ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: _parts.length,
            itemBuilder: (_, i) => _ParticipantCard(
              p: _parts[i],
              closed: closed,
              onMethod: (m) => _setPayment(i, m),
              onDelete: () => _remove(i),
            ),
          ),
        ),

        if (_parts.isNotEmpty) _SummaryBar(parts: _parts),
      ]),
      bottomNavigationBar: _loading ? null : SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(width: double.infinity, height: 52,
            child: _saving
                ? const Center(child: CircularProgressIndicator())
                : closed
                ? OutlinedButton.icon(onPressed: _reopen,
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('Переоткрыть вечер'))
                : FilledButton.icon(onPressed: _close,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Закрыть вечер')),
          ),
        ),
      ),
    );
  }
}

// ── Карточка участника с 4 вариантами оплаты ─────────────────────────────────
class _ParticipantCard extends StatelessWidget {
  final NightParticipant p;
  final bool closed;
  final ValueChanged<PaymentMethod> onMethod;
  final VoidCallback onDelete;

  const _ParticipantCard({
    required this.p, required this.closed,
    required this.onMethod, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: s.primaryContainer,
                child: Text(p.nickname.isNotEmpty ? p.nickname[0].toUpperCase() : '?',
                    style: TextStyle(fontWeight: FontWeight.bold,
                        color: s.onPrimaryContainer)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(p.nickname,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              if (!closed)
                IconButton(icon: const Icon(Icons.remove_circle_outline),
                    color: s.error, onPressed: onDelete, tooltip: 'Удалить'),
            ]),

            const SizedBox(height: 6),

            // Вариант 1: Не оплачено (красный, дефолт)
            _PayOption(
              label: 'Не оплачено (долг −400 ₽)',
              icon: Icons.money_off_outlined,
              selected: p.paymentMethod == PaymentMethod.unpaid,
              color: s.error,
              enabled: !closed,
              onTap: () => onMethod(PaymentMethod.unpaid),
            ),
            // Вариант 2: Списать с депозита
            _PayOption(
              label: 'Списать с депозита (−400 ₽)',
              icon: Icons.account_balance_wallet_outlined,
              selected: p.paymentMethod == PaymentMethod.deposit,
              color: s.primary,
              enabled: !closed,
              onTap: () => onMethod(PaymentMethod.deposit),
            ),
            // Вариант 3: Переводом
            _PayOption(
              label: 'Оплачено переводом',
              icon: Icons.send_outlined,
              selected: p.paymentMethod == PaymentMethod.transfer,
              color: Colors.blue.shade700,
              enabled: !closed,
              onTap: () => onMethod(PaymentMethod.transfer),
            ),
            // Вариант 4: Наличными
            _PayOption(
              label: 'Оплачено наличными',
              icon: Icons.payments_outlined,
              selected: p.paymentMethod == PaymentMethod.cash,
              color: Colors.green.shade700,
              enabled: !closed,
              onTap: () => onMethod(PaymentMethod.cash),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected, enabled;
  final Color color;
  final VoidCallback onTap;

  const _PayOption({
    required this.label, required this.icon,
    required this.selected, required this.enabled,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Row(children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? color : outline, size: 20),
          const SizedBox(width: 8),
          Icon(icon, size: 16,
              color: selected ? color : Theme.of(context).colorScheme.outline),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              fontSize: 13,
              color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
        ]),
      ),
    );
  }
}

// ── Итоговая строка ───────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final List<NightParticipant> parts;
  const _SummaryBar({required this.parts});

  @override
  Widget build(BuildContext context) {
    final unpaid   = parts.where((p) => p.paymentMethod == PaymentMethod.unpaid).length;
    final deposit  = parts.where((p) => p.paymentMethod == PaymentMethod.deposit).length;
    final transfer = parts.where((p) => p.paymentMethod == PaymentMethod.transfer).length;
    final cash     = parts.where((p) => p.paymentMethod == PaymentMethod.cash).length;
    final s = Theme.of(context).colorScheme;

    return Container(
      color: s.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _SI(label: 'Долг',     value: unpaid,   color: s.error),
        Container(width: 1, height: 28, color: s.outlineVariant),
        _SI(label: 'Депозит',  value: deposit,  color: s.primary),
        Container(width: 1, height: 28, color: s.outlineVariant),
        _SI(label: 'Перевод',  value: transfer, color: Colors.blue.shade700),
        Container(width: 1, height: 28, color: s.outlineVariant),
        _SI(label: 'Нал',      value: cash,     color: Colors.green.shade700),
        Container(width: 1, height: 28, color: s.outlineVariant),
        _SI(label: 'Итого',    value: parts.length, color: s.onSurface),
      ]),
    );
  }
}

class _SI extends StatelessWidget {
  final String label; final int value; final Color color;
  const _SI({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$value', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
    ],
  );
}
