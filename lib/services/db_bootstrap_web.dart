/// Web: back sqflite with the WASM build (data persisted in IndexedDB).
/// Selected only when compiling for the browser (dart.library.html present).
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void configureDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}
