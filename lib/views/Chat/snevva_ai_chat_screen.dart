import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:snevva/consts/colors.dart';
import 'package:snevva/consts/images.dart';

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

/// ---------- LOCAL STORAGE ----------

/// ---------- CHAT MESSAGE MODEL ----------

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final File? image;


  ChatMessage(
      {required this.text, required this.isUser, required this.time, this.image});
}

/// ---------- MAIN SCREEN ----------

class SnevvaAIChatScreen extends StatefulWidget {
  const SnevvaAIChatScreen({super.key});

  @override
  State<SnevvaAIChatScreen> createState() => _SnevvaAIChatScreenState();
}

class _SnevvaAIChatScreenState extends State<SnevvaAIChatScreen> {
  final List<ChatMessage> messages = [];
  final _userController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _openGallery() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    } else {
      debugPrint("No image selected");
    }
  }

  Map<String, DecisionNode> decisionTree = {};
  String currentNodeKey = "welcome";
  bool waitingForUser = false;

  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      final scrolled = _scrollController.offset > 10;

      if (scrolled != _isScrolled) {
        setState(() {
          _isScrolled = scrolled;
        });
      }
    });
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

  void _addUserMessage(String text, {File ? image}) {
    setState(() {
      messages.add(ChatMessage(
          text: text, isUser: true, time: DateTime.now(), image: image));
    });
    _scrollToBottom();
  }

  void _sendMessage() {
    final text = _userController.text.trim();
    if (text.isEmpty && _selectedImage == null) return; // nothing to send

    _addUserMessage(text, image: _selectedImage);

    _userController.clear();
    setState(() {
      _selectedImage = null; // clears the thumbnail preview too
    });
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

  Future<void> _cancelImage() async {
    setState(() {
      _selectedImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final node = decisionTree[currentNodeKey];

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          child: AppBar(
            elevation: 0,
            automaticallyImplyLeading: false,
            backgroundColor:
            _isScrolled ? (isDarkMode ? black : white) : Colors.transparent,
            leading: IconButton(
              onPressed: () {
                Get.back();
              },
              icon: const Icon(Icons.arrow_back_ios_new),
            ),
            iconTheme: IconThemeData(color: isDarkMode ? white : black),
            title: Text(
              "Chat with Elly",
              style: TextStyle(
                color: isDarkMode ? white : black,
                fontWeight: FontWeight.w500,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
          ),
        ),
      ),

      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Opacity(
              opacity: 0.5,
              child: Image.asset(
                isDarkMode ? chatwallpaperdark : chatWallpaper,
                fit: BoxFit.cover,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                /// ------------ CHAT LIST ------------
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    // Add top padding to account for AppBar and StatusBar
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),

                    // Add 1 to count if we have options to show them at the end of the list
                    itemCount:
                        messages.length +
                        (waitingForUser &&
                                node != null &&
                                node.options.isNotEmpty
                            ? 1
                            : 0),
                    itemBuilder: (context, i) {
                      // If we are at the end and have options, render them
                      if (waitingForUser &&
                          node != null &&
                          node.options.isNotEmpty &&
                          i == messages.length) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children:
                              node.options
                                  .map(
                                    (opt) => Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8.0,
                                        left: 60,
                                      ), // Indent to align right
                                      child: InkWell(
                                        onTap: () => _handleOptionSelected(opt),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: AppColors.primaryGradient,
                                            // Purple for options (User bubble color)
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
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
                                    ),
                                  )
                                  .toList(),
                        );
                      }

                      final msg = messages[i];

                      return Align(
                        alignment: msg.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment:
                          msg.isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            msg.isUser
                                ? const SizedBox.shrink()
                                : Text(
                              "Elly  ${DateFormat('hh:mm a').format(msg.time)}",
                              style: const TextStyle(fontSize: 10),
                            ),

                            // Image bubble (only if this message has an image)
                            if (msg.image != null)
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                constraints: BoxConstraints(
                                  maxWidth: mediaQuery.size.width * 0.6,
                                ),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Image.file(
                                    msg.image!, fit: BoxFit.cover),
                              ),

                            // Text bubble (only if there's actual text)
                            if (msg.text.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                constraints: BoxConstraints(
                                  maxWidth: mediaQuery.size.width * 0.75,
                                ),
                                decoration: BoxDecoration(
                                  gradient: msg.isUser
                                      ? AppColors.primaryGradient
                                      : AppColors.whiteGradient,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: msg.isUser ? const Radius
                                        .circular(20) : Radius.zero,
                                    bottomRight: msg.isUser
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
                                    color: msg.isUser ? Colors.white : Colors
                                        .black87,
                                    fontSize: 16,
                                  ),
                                ),
                              ),

                            msg.isUser
                                ? Text(
                              "YOU  ${DateFormat('hh:mm a').format(msg.time)}",
                              style: const TextStyle(fontSize: 10),
                            )
                                : const SizedBox.shrink(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedImage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _selectedImageViewer(),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _userController,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: white,
                                  hintText: "Enter message",
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _openGallery,
                              icon: Icon(
                                  Icons.attach_file_outlined, color: black),
                            ),
                            InkWell(
                              onTap: _sendMessage,
                              child: Container(
                                height: 36,
                                width: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryColor,
                                ),
                                child: Center(
                                  child: Icon(Icons.send, color: white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedImageViewer() {
    if (_selectedImage == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.topLeft,
      child: Stack(
        clipBehavior: Clip.none, // lets the cancel badge overflow the corner
        children: [
          Container(
            height: 70,
            width: 70,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.file(_selectedImage!, fit: BoxFit.cover),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: _cancelImage,
              child: Container(
                height: 20,
                width: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black54,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
