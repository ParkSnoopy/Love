class BiblePack {
  const BiblePack({
    required this.id,
    required this.shortName,
    required this.name,
    required this.language,
    required this.type,
    required this.file,
    required this.source,
  });

  final String id;
  final String shortName;
  final String name;
  final String language;
  final String type;
  final String file;
  final String source;

  factory BiblePack.fromJson(Map<String, dynamic> json) {
    return BiblePack(
      id: (json['id'] ?? '') as String,
      shortName: (json['shortname'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      language: (json['language'] ?? '') as String,
      type: (json['type'] ?? '') as String,
      file: (json['file'] ?? '') as String,
      source: (json['source'] ?? 'unknown') as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BiblePack &&
        other.id == id &&
        other.shortName == shortName &&
        other.language == language &&
        other.type == type &&
        other.file == file;
  }

  @override
  int get hashCode => Object.hash(id, shortName, language, type, file);
}
