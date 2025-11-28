import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart'; // ✅ Needed for directory path

import 'package:snevva/consts/colors.dart';
import 'package:snevva/consts/images.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/services/api_service.dart';

/// ---------- DECISION TREE MODEL ----------

class DecisionNode {
  final String message;
  final List<Option> options;

  DecisionNode({required this.message, required this.options});

  factory DecisionNode.fromJson(Map<String, dynamic> json) {
    List<Option> opts = [];
    if (json['options'] != null) {
      opts = (json['options'] as List).map((e) => Option.fromJson(e)).toList();
    }
    return DecisionNode(message: json['message'], options: opts);
  }
}

class Option {
  final String text;
  final String? next;

  Option({required this.text, this.next});

  factory Option.fromJson(Map<String, dynamic> json) {
    return Option(text: json['text'], next: json['next']);
  }
}

/// ---------- LOAD DECISION TREE FROM API OR CACHE ----------

Future<Map<String, DecisionNode>> loadDecisionTree() async {
  try {
    final response = await ApiService.post(
      ellychat,
      {},
      withAuth: true,
      encryptionRequired: true,
    );

    print(response);

    // Convert to Map
    if (response is Map && response['data'] != null) {
      final res = Map<String, dynamic>.from(response['data']);
      print("API decision tree fetched.");

      // Save JSON
      // await _saveDecisionJsonLocally(res);
      // print("Decision tree saved locally.");
      // Parse
      final nodes = <String, DecisionNode>{};

      res.forEach((key, value) {
        try {
          final normalized = Map<String, dynamic>.from(
            jsonDecode(jsonEncode(value)),
          );

          nodes[key] = DecisionNode.fromJson(normalized);
        } catch (e) {
          print('Error parsing decision node for key $key: $e');
        }
      });

      // print("Decision tree parsed from API.");

      return nodes;
    } else {
      throw FormatException("Response does not contain 'data'");
    }
  } catch (e) {
    print("API failed, loading cached decision tree…");
    return await _loadDecisionJsonFromCache();
  }
}

/// ---------- LOCAL STORAGE ----------

Future<File> _decisionFile() async {
  final dir =
      await getApplicationDocumentsDirectory(); // ✔ real Flutter function
  print(dir.path);
  return File('${dir.path}/decision.json');
}

Future<void> _saveDecisionJsonLocally(Map<String, dynamic> json) async {
  final file = await _decisionFile();
  await file.writeAsString(jsonEncode(json));
  print("Decision tree updated locally.");
}

Future<Map<String, DecisionNode>> _loadDecisionJsonFromCache() async {
  try {
    final file = await _decisionFile();
    print("Looking for cached decision tree at: ${file.path}");

    String text;

    // 1. If the local cached file exists → load it
    if (await file.exists()) {
      text = await file.readAsString();
      print("Loaded decision tree from cached file.");
    }
    // 2. Otherwise → load from assets
    else {
      text = await rootBundle.loadString('assets/decision_tree.json');
      print("Loaded decision tree from assets file.");
    }

    final Map<String, dynamic> json = jsonDecode(text);

    final nodes = <String, DecisionNode>{};

    json.forEach((key, value) {
      nodes[key] = DecisionNode.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(value))),
      );
    });

    return nodes;
  } catch (e) {
    print("Error loading decision tree: $e");
    return {};
  }
}

/// ---------- CHAT MESSAGE MODEL ----------

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({required this.text, required this.isUser, required this.time});
}

/// ---------- MAIN SCREEN ----------

class SnevvaAIChatScreen extends StatefulWidget {
  const SnevvaAIChatScreen({super.key});

  @override
  State<SnevvaAIChatScreen> createState() => _SnevvaAIChatScreenState();
}

class _SnevvaAIChatScreenState extends State<SnevvaAIChatScreen> {
  final List<ChatMessage> messages = [];
  final ScrollController _scrollController = ScrollController();

  Map<String, DecisionNode> decisionTree = {};
  String currentNodeKey = "welcome";
  bool waitingForUser = false;

  @override
  void initState() {
    super.initState();
    _initializeTree();
  }

  Future<void> _initializeTree() async {
    decisionTree = await loadDecisionTree(); // ✔ load API or cache
    _showCurrentNode();
  }

  /// Smooth scroll
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showCurrentNode() {
    final node = decisionTree[currentNodeKey];
    if (node != null) {
      _addBotMessage(node.message);
      setState(() => waitingForUser = true);
    }
  }

  void _addBotMessage(String text) {
    setState(() {
      messages.add(
        ChatMessage(text: text, isUser: false, time: DateTime.now()),
      );
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      messages.add(ChatMessage(text: text, isUser: true, time: DateTime.now()));
    });
    _scrollToBottom();
  }

  void _handleOptionSelected(Option option) async {
    _addUserMessage(option.text);
    setState(() => waitingForUser = false);

    await Future.delayed(const Duration(milliseconds: 500));

    if (option.next != null && decisionTree.containsKey(option.next)) {
      currentNodeKey = option.next!;
      _showCurrentNode();
    } else {
      _addBotMessage("💙 Glad I could help today. Talk soon!");
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bool isDark = mediaQuery.platformBrightness == Brightness.dark;

    final node = decisionTree[currentNodeKey];

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: SizedBox(
            width: 24, 
            height: 24,
            child: Image.asset(bacskarrowBlack),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Chat with Elly",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),

      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              chatWallpaper,
              fit: BoxFit.cover,
            ),
          ),
          
          Column(
            children: [
              /// ------------ CHAT LIST ------------
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  // Add top padding to account for AppBar and StatusBar
                  padding: EdgeInsets.only(
                    top: kToolbarHeight + mediaQuery.padding.top + 10, 
                    left: 16, 
                    right: 16, 
                    bottom: 10
                  ),
                  // Add 1 to count if we have options to show them at the end of the list
                  itemCount: messages.length + (waitingForUser && node != null && node.options.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, i) {
                    
                    // If we are at the end and have options, render them
                    if (waitingForUser && node != null && node.options.isNotEmpty && i == messages.length) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: node.options.map((opt) => Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 60), // Indent to align right
                          child: GestureDetector(
                            onTap: () => _handleOptionSelected(opt),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD09CFA), // Purple for options (User bubble color)
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                opt.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        )).toList(),
                      );
                    }

                    final msg = messages[i];
                    
                    return Align(
                      alignment:
                          msg.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        constraints: BoxConstraints(maxWidth: mediaQuery.size.width * 0.75),
                        decoration: BoxDecoration(
                          color:
                              msg.isUser
                                  ? const Color(0xFFD09CFA) // Purple for user
                                  : Colors.white, // White for bot
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft:
                                msg.isUser
                                    ? const Radius.circular(20)
                                    : Radius.zero,
                            bottomRight:
                                msg.isUser
                                    ? Radius.zero
                                    : const Radius.circular(20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          msg.text,
                          style: TextStyle(
                            color:
                                msg.isUser
                                    ? Colors.white
                                    : Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
