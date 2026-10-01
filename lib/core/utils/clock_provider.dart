import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'ids.dart';

part 'clock_provider.g.dart';

/// Hora actual en UTC. Los tests la sustituyen por un reloj fijo para medir
/// tiempos de respuesta de forma determinista.
@Riverpod(keepAlive: true)
DateTime Function() clock(Ref ref) => nowUtc;
