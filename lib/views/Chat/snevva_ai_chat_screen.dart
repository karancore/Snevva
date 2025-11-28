import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart'; // ✅ Needed for directory path
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
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
      appBar: CustomAppBar(appbarText: "Ask Elly" , showDrawerIcon: false,),

      body: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Image.asset(chatWallpaper),
          ),
          Column(
            children: [
              /// ------------ CHAT LIST ------------
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final formattedTime = TimeOfDay.fromDateTime(
                      msg.time,
                    ).format(context);
                    final sender = msg.isUser ? "You" : "Elly";

                    return Align(
                      alignment:
                          msg.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment:
                            msg.isUser
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(

                              color:
                                  msg.isUser
                                      ? AppColors.primaryColor.withOpacity(0.9)
                                      : (isDark
                                          ? Colors.grey[800]
                                          : Colors.white),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft:
                                    msg.isUser
                                        ? const Radius.circular(16)
                                        : Radius.zero,
                                bottomRight:
                                    msg.isUser
                                        ? Radius.zero
                                        : const Radius.circular(16),
                              ),
                            ),
                            child: AutoSizeText(
                              msg.text,
                              style: TextStyle(
                                color:
                                    msg.isUser
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                fontSize: 16,
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              "$sender • $formattedTime",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              /// ------------ OPTION BUTTONS ------------
              if (waitingForUser && node != null && node.options.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: isDark ? scaffoldColorDark : scaffoldColorLight,
                  child: Column(
                    children:
                        node.options
                            .map(
                              (opt) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryColor,
                                    minimumSize: const Size(double.infinity, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => _handleOptionSelected(opt),
                                  child: Text(opt.text , style: TextStyle(color: white),),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
