import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Id nuevo para datos de usuario: UUID v4 generado en el cliente, así dos
/// dispositivos pueden crear filas sin pedir el id a un servidor.
String newId() => _uuid.v4();

/// Instante actual en UTC. Todas las fechas de usuario se guardan en UTC.
DateTime nowUtc() => DateTime.now().toUtc();
