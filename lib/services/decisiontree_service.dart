import 'package:snevva/views/Chat/snevva_ai_chat_screen.dart';

class DecisionTreeService {
  static final DecisionTreeService _instance =
      DecisionTreeService._internal();

  factory DecisionTreeService() => _instance;

  DecisionTreeService._internal();

  Map<String, DecisionNode>? _cachedTree;
  bool _isLoading = false;

  Future<Map<String, DecisionNode>> getDecisionTree() async {
    // 🟢 If already loaded → return instantly
    if (_cachedTree != null) {
      print("🧠 Decision tree served from MEMORY");
      return _cachedTree!;
    }

    // 🟡 Prevent multiple parallel API calls
    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _cachedTree ?? {};
    }

    _isLoading = true;

    try {
      final tree = await loadDecisionTree(); // your existing function
      _cachedTree = tree;
      print("🌐 Decision tree fetched ONCE from API");
      return tree;
    } finally {
      _isLoading = false;
    }
  }

  /// Call this on LOGOUT
  void clear() {
    _cachedTree = null;
    print("🧹 Decision tree cache cleared");
  }
}
