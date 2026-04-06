// ─── Метод оплаты участника вечера ───────────────────────────────────────────
// unpaid   = не оплачено (по умолчанию) → долг +400 при закрытии
// deposit  = списать с депозита → −400 с депозита при закрытии
// transfer = оплачено переводом → без списания
// cash     = оплачено наличными → без списания
enum PaymentMethod { unpaid, deposit, transfer, cash }

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.unpaid:   return 'Не оплачено';
      case PaymentMethod.deposit:  return 'Списать с депозита';
      case PaymentMethod.transfer: return 'Переводом';
      case PaymentMethod.cash:     return 'Наличными';
    }
  }

  String get key {
    switch (this) {
      case PaymentMethod.unpaid:   return 'unpaid';
      case PaymentMethod.deposit:  return 'deposit';
      case PaymentMethod.transfer: return 'transfer';
      case PaymentMethod.cash:     return 'cash';
    }
  }

  static PaymentMethod fromKey(String? key) {
    switch (key) {
      case 'deposit':  return PaymentMethod.deposit;
      case 'transfer': return PaymentMethod.transfer;
      case 'cash':     return PaymentMethod.cash;
      default:         return PaymentMethod.unpaid; // дефолт
    }
  }
}

// ─── GameNight ────────────────────────────────────────────────────────────────
class GameNight {
  final int? id;
  final String title;
  final bool isClosed;
  final DateTime createdAt;

  const GameNight({
    this.id,
    required this.title,
    this.isClosed = false,
    required this.createdAt,
  });

  factory GameNight.fromMap(Map<String, dynamic> m) => GameNight(
    id: m['id'] as int?,
    title: m['title'] as String,
    isClosed: (m['is_closed'] as int) == 1,
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'is_closed': isClosed ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  GameNight copyWith({bool? isClosed}) => GameNight(
    id: id,
    title: title,
    isClosed: isClosed ?? this.isClosed,
    createdAt: createdAt,
  );
}

// ─── Player ───────────────────────────────────────────────────────────────────
class Player {
  final int? id;
  final String nickname;
  const Player({this.id, required this.nickname});

  factory Player.fromMap(Map<String, dynamic> m) =>
      Player(id: m['id'] as int?, nickname: m['nickname'] as String);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'nickname': nickname};
    if (id != null) map['id'] = id;
    return map;
  }
}

// ─── NightParticipant ─────────────────────────────────────────────────────────
class NightParticipant {
  final int? id;
  final int nightId;
  final int playerId;
  final PaymentMethod paymentMethod;
  final String nickname;

  const NightParticipant({
    this.id,
    required this.nightId,
    required this.playerId,
    this.paymentMethod = PaymentMethod.unpaid, // дефолт — «Не оплачено»
    this.nickname = '',
  });

  factory NightParticipant.fromMap(Map<String, dynamic> m) => NightParticipant(
    id: m['id'] as int?,
    nightId: m['night_id'] as int,
    playerId: m['player_id'] as int,
    paymentMethod: PaymentMethodX.fromKey(m['payment_method'] as String?),
    nickname: m['nickname'] as String? ?? '',
  );

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'night_id': nightId,
      'player_id': playerId,
      'payment_method': paymentMethod.key,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  NightParticipant copyWith({PaymentMethod? paymentMethod}) =>
      NightParticipant(
        id: id,
        nightId: nightId,
        playerId: playerId,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        nickname: nickname,
      );
}

// ─── DepositTransaction ───────────────────────────────────────────────────────
class DepositTransaction {
  final int? id;
  final int playerId;
  final double amount;
  final int? nightId;
  final DateTime createdAt;

  const DepositTransaction({
    this.id,
    required this.playerId,
    required this.amount,
    this.nightId,
    required this.createdAt,
  });

  factory DepositTransaction.fromMap(Map<String, dynamic> m) =>
      DepositTransaction(
        id: m['id'] as int?,
        playerId: m['player_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        nightId: m['night_id'] as int?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'player_id': playerId,
      'amount': amount,
      'night_id': nightId,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }
}
