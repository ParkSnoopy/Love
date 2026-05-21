class ImportException implements Exception {
  ImportException({
    required this.code,
    required this.message,
    this.phase,
    this.detail,
  });

  final String code;
  final String message;
  final String? phase;
  final String? detail;

  @override
  String toString() {
    final b = StringBuffer('ImportException($code): $message');
    if (phase != null) b.write(' phase=$phase');
    if (detail != null) b.write(' detail=$detail');
    return b.toString();
  }
}
