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

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        agentName TEXT,
        senderNumber TEXT,
        receiverNumber TEXT,
        amount REAL,
        charge REAL,
        agentFee REAL,
        screenshotPath TEXT,
        status TEXT
      )
    ''');
  }

  Future<Transfer> createTransfer(Transfer t) async {
    final db = await instance.database;
    final id = await db.insert('transfers', t.toMap());
    return Transfer(
      id: id,
      agentName: t.agentName,
      senderNumber: t.senderNumber,
      receiverNumber: t.receiverNumber,
      amount: t.amount,
      charge: t.charge,
      agentFee: t.agentFee,
      screenshotPath: t.screenshotPath,
      status: t.status,
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
