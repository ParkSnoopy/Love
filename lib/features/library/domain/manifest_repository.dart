import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'bible_pack.dart';

class ManifestRepository {
  const ManifestRepository();

  List<BiblePack> parseBiblePacks(String jsonText) {
    final List<dynamic> raw = jsonDecode(jsonText) as List<dynamic>;
    final packs = raw
        .whereType<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .map(_normalizePackJson)
        .map(BiblePack.fromJson)
        .where((p) => p.shortName.isNotEmpty)
        .toList();

    packs.sort(_comparePacks);
    return List.unmodifiable(packs);
  }

  Future<List<BiblePack>> loadBiblePacksFromAsset() async {
    final manifest = await rootBundle.loadString('assets/data/manifest.json');
    return parseBiblePacks(manifest);
  }

  Map<String, dynamic> _normalizePackJson(Map<String, dynamic> json) {
    return {
      ...json,
      'language': _normalizeLanguage(json['language']?.toString() ?? ''),
    };
  }

  String _normalizeLanguage(String language) {
    final key = language.trim().toLowerCase();
    return switch (key) {
      'cmn' || 'zh' || 'zho' || 'chi' => 'Chinese',
      'kor' || 'ko' => 'Korean',
      'eng' || 'en' => 'English',
      'jpn' || 'jap' || 'ja' => 'Japanese',
      'deu' || 'ger' || 'de' => 'German',
      'heb' || 'he' => 'Hebrew',
      _ => language,
    };
  }

  int _comparePacks(BiblePack a, BiblePack b) {
    return _packSortKey(a).compareTo(_packSortKey(b));
  }

  String _packSortKey(BiblePack pack) {
    final typeRank = pack.type == 'bible'
        ? '0'
        : pack.type == 'commentary'
        ? '1'
        : '2';
    final koreanRank = pack.language == 'Korean' ? '0' : '1';
    return [
      typeRank,
      koreanRank,
      pack.language.toLowerCase(),
      pack.name.toLowerCase(),
      pack.id.toLowerCase(),
    ].join('\u{0}');
  }
}
