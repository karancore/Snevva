import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:snevva/views/Chat/snevva_ai_chat_screen.dart';

import '../consts/consts.dart';

class DecisionTreeService {
  static final DecisionTreeService _instance = DecisionTreeService._internal();

  factory DecisionTreeService() => _instance;

  DecisionTreeService._internal();

  Map<String, DecisionNode>? _cachedTree;
  bool _isLoading = false;

  /// 🔥 USED BY CHAT SCREEN
  Future<Map<String, DecisionNode>> getDecisionTree() async {
    if (_cachedTree != null) {
      debugPrint("🧠 Decision tree served from MEMORY");
      return _cachedTree!;
    }

    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _cachedTree ?? {};
    }

    _isLoading = true;
    try {
      final tree = await loadDecisionTree();
      debugPrint("🌳 Tree size after load: ${tree.length}");
      debugPrint("🌳 Tree keys: ${tree.keys.toList()}");

      _cachedTree = tree;
      debugPrint("🌐 Decision tree loaded");
      return tree;
    } finally {
      _isLoading = false;
    }
  }

  // ==========================================================
  // 🧹 CLEAR MEMORY CACHE (CALL ON LOGOUT)
  // ==========================================================
  void clearMemory() {
    _cachedTree = null;
    debugPrint("🧹 Decision tree memory cache cleared");
  }

  // ==========================================================
  // 🗑️ DELETE LOCAL FILE CACHE (OPTIONAL)
  // ==========================================================
  Future<void> deleteLocalCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/decision.json');

      if (await file.exists()) {
        await file.delete();
        debugPrint("🗑️ decision.json deleted");
      } else {
        debugPrint("ℹ️ decision.json not found");
      }
    } catch (e) {
      debugPrint("❌ Failed to delete decision.json: $e");
    }
  }

  // ==========================================================
  // 🚪 ONE-LINE LOGOUT CLEANUP
  // ==========================================================
  Future<void> clearAll() async {
    clearMemory();
    await deleteLocalCache();
  }
}
