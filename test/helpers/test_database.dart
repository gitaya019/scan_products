import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Prepara `sqflite` para funcionar en el entorno de pruebas (headless).
///
/// En desktop y en tests no existe el plugin nativo de Android/iOS, asi que
/// se registra la implementacion FFI de sqlite.
void inicializarBaseDeDatosDePrueba() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
