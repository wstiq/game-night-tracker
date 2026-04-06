import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'game_nights_v2.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE players (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        nickname TEXT    NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE game_nights (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        title      TEXT    NOT NULL,
        is_closed  INTEGER NOT NULL DEFAULT 0,
        created_at TEXT    NOT NULL
      )
    ''');

    // payment_method: 'unpaid' | 'deposit' | 'transfer' | 'cash'
    await db.execute('''
      CREATE TABLE night_participants (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        night_id       INTEGER NOT NULL,
        player_id      INTEGER NOT NULL,
        payment_method TEXT    NOT NULL DEFAULT 'unpaid'
      )
    ''');

    await db.execute('''
      CREATE TABLE deposit_transactions (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        player_id  INTEGER NOT NULL,
        amount     REAL    NOT NULL,
        night_id   INTEGER,
        created_at TEXT    NOT NULL
      )
    ''');
  }

  // ── PLAYERS ──────────────────────────────────────────────────────────────────

  Future<int> upsertPlayer(String nickname) async {
    final db = await database;
    final trimmed = nickname.trim();
    final rows = await db.rawQuery(
      'SELECT id FROM players WHERE LOWER(nickname) = LOWER(?) LIMIT 1',
      [trimmed],
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return db.insert('players', {'nickname': trimmed});
  }

  Future<List<Player>> getAllPlayers() async {
    final db = await database;
    final rows = await db.query('players', orderBy: 'nickname ASC');
    return rows.map(Player.fromMap).toList();
  }

  /// Проверяет, есть ли у игрока хотя бы одно пополнение депозита (amount > 0).
  /// Используется при валидации закрытия вечера — нельзя «списать с депозита»
  /// если его никогда не пополняли.
  Future<bool> playerHasDeposit(int playerId) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM deposit_transactions WHERE player_id = ? AND amount > 0',
      [playerId],
    );
    return ((r.first['c'] as int?) ?? 0) > 0;
  }

  // ── GAME NIGHTS ───────────────────────────────────────────────────────────────

  Future<int> createGameNight(GameNight night) async {
    final db = await database;
    return db.insert('game_nights', night.toMap());
  }

  Future<void> updateGameNight(GameNight night) async {
    final db = await database;
    await db.update('game_nights', night.toMap(),
        where: 'id = ?', whereArgs: [night.id]);
  }

  Future<void> deleteGameNight(int nightId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('deposit_transactions',
          where: 'night_id = ?', whereArgs: [nightId]);
      await txn.delete('night_participants',
          where: 'night_id = ?', whereArgs: [nightId]);
      await txn.delete('game_nights',
          where: 'id = ?', whereArgs: [nightId]);
    });
  }

  Future<List<GameNight>> getAllGameNights() async {
    final db = await database;
    final rows = await db.query('game_nights', orderBy: 'created_at DESC');
    return rows.map(GameNight.fromMap).toList();
  }

  Future<GameNight?> getGameNightById(int id) async {
    final db = await database;
    final rows = await db.query('game_nights',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return GameNight.fromMap(rows.first);
  }

  // ── PARTICIPANTS ──────────────────────────────────────────────────────────────

  Future<int> addParticipant(NightParticipant p) async {
    final db = await database;
    return db.insert('night_participants', p.toMap());
  }

  Future<void> updateParticipant(NightParticipant p) async {
    final db = await database;
    await db.update('night_participants', p.toMap(),
        where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> deleteParticipant(int id) async {
    final db = await database;
    await db.delete('night_participants', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<NightParticipant>> getParticipants(int nightId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT np.id, np.night_id, np.player_id, np.payment_method, p.nickname
      FROM   night_participants np
      JOIN   players p ON p.id = np.player_id
      WHERE  np.night_id = ?
      ORDER  BY np.id ASC
    ''', [nightId]);
    return rows.map(NightParticipant.fromMap).toList();
  }

  Future<int> getParticipantCount(int nightId) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM night_participants WHERE night_id = ?',
      [nightId],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  // ── TRANSACTIONS ──────────────────────────────────────────────────────────────

  Future<void> createTransaction(DepositTransaction tx) async {
    final db = await database;
    await db.insert('deposit_transactions', tx.toMap());
  }

  Future<void> deleteTransactionsByNightId(int nightId) async {
    final db = await database;
    await db.delete('deposit_transactions',
        where: 'night_id = ?', whereArgs: [nightId]);
  }

  // ── QUERIES FOR SCREENS ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getDepositsData() async {
    final db = await database;
    return db.rawQuery('''
      SELECT   p.id, p.nickname,
               COALESCE(SUM(dt.amount), 0) AS balance
      FROM     players p
      JOIN     deposit_transactions dt ON dt.player_id = p.id
      WHERE    p.id IN (
                 SELECT DISTINCT player_id FROM deposit_transactions WHERE amount > 0
               )
      GROUP BY p.id, p.nickname
      ORDER BY p.nickname ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getDebtorsData() async {
    final db = await database;
    return db.rawQuery('''
      SELECT   p.id, p.nickname,
               COALESCE(SUM(dt.amount), 0) AS balance
      FROM     players p
      JOIN     deposit_transactions dt ON dt.player_id = p.id
      GROUP BY p.id, p.nickname
      HAVING   balance < 0
      ORDER BY balance ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getUnpaidNightsForPlayer(int playerId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT   gn.id, gn.title, gn.created_at, dt.amount
      FROM     deposit_transactions dt
      JOIN     game_nights gn ON gn.id = dt.night_id
      WHERE    dt.player_id = ? AND dt.amount < 0
      ORDER BY gn.created_at DESC
    ''', [playerId]);
  }

  Future<List<Player>> getPlayersWithHistory() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT p.id, p.nickname
      FROM   players p
      JOIN   night_participants np ON np.player_id = p.id
      ORDER  BY p.nickname ASC
    ''');
    return rows.map(Player.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> getPlayerHistory(int playerId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT   gn.id, gn.title, gn.created_at, gn.is_closed,
               np.payment_method
      FROM     night_participants np
      JOIN     game_nights gn ON gn.id = np.night_id
      WHERE    np.player_id = ?
      ORDER BY gn.created_at DESC
    ''', [playerId]);
  }

  Future<double> getPlayerBalance(int playerId) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS b FROM deposit_transactions WHERE player_id = ?',
      [playerId],
    );
    return (r.first['b'] as num).toDouble();
  }
}
