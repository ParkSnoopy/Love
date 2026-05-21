import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeBiblePackIdProvider =
    NotifierProvider<ActiveBiblePackIdController, String?>(
      ActiveBiblePackIdController.new,
    );

class ActiveBiblePackIdController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String packId) {
    state = packId;
  }
}
