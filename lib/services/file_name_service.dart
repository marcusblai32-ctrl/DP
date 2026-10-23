/// Helpers légers pour créer des noms de fichiers portables.
class FileNameService {
  const FileNameService._();

  static String safe(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    return cleaned.isEmpty ? 'document' : cleaned;
  }
}
