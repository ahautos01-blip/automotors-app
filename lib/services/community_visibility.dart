import 'package:flutter/foundation.dart';

/// Only the viewer's own confirmed block actions affect their local feed.
class CommunityVisibility extends ChangeNotifier {
  static final instance = CommunityVisibility();
  final _hidden = <String, Set<String>>{};
  bool hides(String? viewer, String? seller) =>
      viewer != null &&
      seller != null &&
      (_hidden[viewer]?.contains(seller) ?? false);
  void record({
    required String viewer,
    required String seller,
    required bool blocked,
  }) {
    final hidden = _hidden.putIfAbsent(viewer, () => <String>{});
    final changed = blocked ? hidden.add(seller) : hidden.remove(seller);
    if (changed) notifyListeners();
  }
}
