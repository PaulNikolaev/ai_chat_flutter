import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';

/// Точка входа в приложение.
///
/// Инициализирует и запускает Flutter приложение.
void main() {
  // Инициализируем sqflite_common_ffi для десктопных платформ
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  runApp(const MyApp());
}
