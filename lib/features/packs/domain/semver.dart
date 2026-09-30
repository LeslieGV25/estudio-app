/// Versión semántica `MAYOR.MENOR.PARCHE` de un pack.
///
/// Comparar las versiones como texto fallaría: «1.10.0» < «1.9.0» por orden
/// alfabético. Aquí se compara número a número.
final class SemVer implements Comparable<SemVer> {
  const SemVer(this.major, this.minor, this.patch);

  /// Acepta el mismo formato que el esquema del pack (`^\d+\.\d+\.\d+$`).
  factory SemVer.parse(String version) {
    final match = _pattern.firstMatch(version);
    if (match == null) {
      throw FormatException('Versión no válida: «$version»');
    }
    return SemVer(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static final _pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');

  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(SemVer other) => major != other.major
      ? major.compareTo(other.major)
      : minor != other.minor
      ? minor.compareTo(other.minor)
      : patch.compareTo(other.patch);

  bool operator >(SemVer other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is SemVer && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}
