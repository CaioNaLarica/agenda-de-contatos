import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

import '../model/contact_model.dart';

// Android uses sqflite as in the reference; Linux uses SQLite through FFI.
void initializeDatabasePlatform() {
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

class ContactHelper {
  static const schemaVersion = 2;
  static final ContactHelper _instance = ContactHelper._internal();
  factory ContactHelper() => _instance;
  ContactHelper._internal();
  ContactHelper.withDatabase(Database database) : _db = database;

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get db async {
    if (_db != null) return _db!;
    return _opening ??= initDb();
  }

  Future<Database> initDb() async {
    try {
      final databasePath = Platform.isLinux || Platform.isWindows
          ? (await getApplicationSupportDirectory()).path
          : await getDatabasesPath();
      _db = await openDatabase(
        join(databasePath, 'contactsDB.db'),
        version: schemaVersion,
        onCreate: (database, version) => createTable(database),
        onUpgrade: upgradeDatabase,
      );
      return _db!;
    } finally {
      _opening = null;
    }
  }

  static Future<void> createTable(Database database) => database.execute(
    'CREATE TABLE $contactTable('
    '$idColumn INTEGER PRIMARY KEY, '
    '$nameColumn TEXT, '
    '$emailColumn TEXT, '
    '$phoneColumn TEXT, '
    '$imgColumn TEXT, '
    '${addressColumns.map((column) => "$column TEXT NOT NULL DEFAULT ''").join(', ')})',
  );

  static Future<void> upgradeDatabase(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      for (final column in addressColumns) {
        await database.execute(
          "ALTER TABLE $contactTable ADD COLUMN $column TEXT NOT NULL DEFAULT ''",
        );
      }
    }
  }

  Future<Contact> saveContact(Contact contact) async {
    final database = await db;
    contact.id = await database.insert(contactTable, contact.toMap());
    return contact;
  }

  Future<Contact?> getContact(int id) async {
    final database = await db;
    final maps = await database.query(
      contactTable,
      where: '$idColumn = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? Contact.fromMap(maps.first) : null;
  }

  Future<List<Contact>> getAllContacts() async {
    final database = await db;
    final maps = await database.query(contactTable);
    return maps.map(Contact.fromMap).toList();
  }

  Future<int> deleteContact(int id) async {
    final database = await db;
    return database.delete(
      contactTable,
      where: '$idColumn = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateContact(Contact contact) async {
    final database = await db;
    return database.update(
      contactTable,
      contact.toMap(),
      where: '$idColumn = ?',
      whereArgs: [contact.id],
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
