import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const _assetPath = 'assets/data/app_data.db';
  static const _dbFileName = 'app_data.db';

  static Future<AppDatabase> open() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, _dbFileName);
    final dbFile = File(dbPath);

    final bytes = await rootBundle.load(_assetPath);

    // The bundled dataset is read-only (the app never writes to it), so
    // there's nothing on-device worth preserving. Re-copy whenever the
    // bundled asset doesn't match what's already there — not just on first
    // install — so a rebuilt asset (new scrape/import) actually reaches
    // the device instead of silently keeping whatever was copied the very
    // first time the app ever ran.
    final needsCopy = !await dbFile.exists() || await dbFile.length() != bytes.lengthInBytes;
    if (needsCopy) {
      await dbFile.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }

    final db = await openDatabase(dbPath);
    return AppDatabase._(db);
  }
}
