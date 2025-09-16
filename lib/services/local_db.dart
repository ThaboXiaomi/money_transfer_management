import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/transfer.dart';

class LocalDb {
  static final LocalDb instance = LocalDb._init();
  static Database? _database;
  LocalDb._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('transfers.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        agentName TEXT,
        agentId TEXT,
        senderNumber TEXT,
        receiverNumber TEXT,
        amount REAL,
        charge REAL,
        agentFee REAL,
        screenshotPath TEXT,
        status TEXT,
        txRef TEXT,
        destination TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE agents (
        id TEXT PRIMARY KEY,
        name TEXT,
        locationId TEXT,
        status TEXT,
        dailyVolume REAL,
        commissionRate REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE recipients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        number TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT,
        role TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT,
        meta TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        body TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // add agents table and agentId column to transfers
      try {
        await db.execute('ALTER TABLE transfers ADD COLUMN agentId TEXT');
      } catch (_) {}
      try {
        await db.execute('''
        CREATE TABLE IF NOT EXISTS agents (
          id TEXT PRIMARY KEY,
          name TEXT,
          locationId TEXT,
          status TEXT,
          dailyVolume REAL,
          commissionRate REAL
        )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
        CREATE TABLE IF NOT EXISTS recipients (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          number TEXT
        )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT,
          role TEXT
        )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
        CREATE TABLE IF NOT EXISTS audit (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action TEXT,
          meta TEXT,
          created_at TEXT
        )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          body TEXT
        )
        ''');
      } catch (_) {}
    }
  }

  // Audit helper
  Future<void> logAudit(String action, String meta) async {
    final db = await instance.database;
    await db.insert('audit', {
      'action': action,
      'meta': meta,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Notifications CRUD
  Future<int> insertNotification(Map<String, dynamic> n) async {
    final db = await instance.database;
    return await db.insert('notifications', n);
  }

  Future<List<Map<String, dynamic>>> readNotifications() async {
    final db = await instance.database;
    return await db.query('notifications', orderBy: 'id DESC');
  }

  Future<void> updateNotification(int id, Map<String, dynamic> n) async {
    final db = await instance.database;
    await db.update('notifications', n, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteNotification(int id) async {
    final db = await instance.database;
    await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }

  // Agents CRUD helpers
  Future<void> upsertAgent(Map<String, dynamic> a) async {
    final db = await instance.database;
    await db.insert('agents', a, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> readAgents() async {
    final db = await instance.database;
    return await db.query('agents');
  }

  Future<void> deleteAgentById(String id) async {
    final db = await instance.database;
    await db.delete('agents', where: 'id = ?', whereArgs: [id]);
  }

  Future<Transfer> createTransfer(Transfer t) async {
    final db = await instance.database;
    final id = await db.insert('transfers', t.toMap());
    return Transfer(
      id: id,
      agentName: t.agentName,
      agentId: (t as dynamic).agentId,
      senderNumber: t.senderNumber,
      receiverNumber: t.receiverNumber,
      amount: t.amount,
      charge: t.charge,
      agentFee: t.agentFee,
      screenshotPath: t.screenshotPath,
      status: t.status,
      txRef: t.txRef,
      destination: t.destination,
    );
  }

  Future<List<Transfer>> readAll() async {
    final db = await instance.database;
    final res = await db.query('transfers', orderBy: 'id DESC');
    return res.map((m) => Transfer.fromMap(m)).toList();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
