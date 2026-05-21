class BiblePack {
  const BiblePack({
    required this.id,
    required this.shortName,
    required this.language,
    required this.type,
  });

  final String id;
  final String shortName;
  final String language;
  final String type;

  factory BiblePack.fromJson(Map<String, dynamic> json) {
    return BiblePack(
      id: (json['id'] ?? '') as String,
      shortName: (json['shortname'] ?? '') as String,
      language: (json['language'] ?? '') as String,
      type: (json['type'] ?? '') as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BiblePack &&
        other.id == id &&
        other.shortName == shortName &&
        other.language == language &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(id, shortName, language, type);
}
