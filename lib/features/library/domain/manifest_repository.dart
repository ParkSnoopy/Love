import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'bible_pack.dart';

class ManifestRepository {
  const ManifestRepository();

  List<BiblePack> parseBiblePacks(String jsonText) {
    final List<dynamic> raw = jsonDecode(jsonText) as List<dynamic>;
    return raw
        .whereType<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .map(BiblePack.fromJson)
        .where((p) => p.shortName.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<BiblePack>> loadBiblePacksFromAsset() async {
    final manifest = await rootBundle.loadString('assets/data/manifest.json');
    return parseBiblePacks(manifest);
  }
}
