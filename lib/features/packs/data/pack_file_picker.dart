import 'package:file_picker/file_picker.dart';

/// Pide a la usuaria un fichero de pack y devuelve sus bytes.
///
/// Siempre bytes, nunca una ruta: en web no hay rutas de fichero, y así el
/// mismo flujo de importación sirve para Android y web.
abstract interface class PackFilePicker {
  /// `null` si la usuaria cancela.
  Future<List<int>?> pickPackFile();
}

class FilePickerPackFilePicker implements PackFilePicker {
  const FilePickerPackFilePicker();

  @override
  Future<List<int>?> pickPackFile() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Elige un fichero .pack.json',
      type: FileType.custom,
      // Los packs se llaman `*.pack.json`; el filtro solo admite la última
      // extensión. Si no es un pack, el validador lo dirá.
      allowedExtensions: const ['json'],
    );
    return file?.readAsBytes();
  }
}
