import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to control the visibility of the commentary pane in the Reader view.
class CommentaryVisibilityController extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void show() => state = true;
  void hide() => state = false;
}

final commentaryVisibilityProvider =
    NotifierProvider<CommentaryVisibilityController, bool>(
      CommentaryVisibilityController.new,
    );
