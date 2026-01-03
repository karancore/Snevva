import 'package:snevva/consts/colors.dart';
import 'package:snevva/consts/images.dart';
import 'package:flutter/material.dart';

class DrChat extends StatefulWidget {
  const DrChat({super.key});

  @override
  State<DrChat> createState() => _DrChatState();
}

class _DrChatState extends State<DrChat> {
  final TextEditingController _controller = TextEditingController();

  final List<Map<String, dynamic>> messages = [
    {
      "sender": "Dr. Sharma",
      "text": "Sed ut perspiciatis unde omnis iste natus error sit voluptatem,",
      "time": "10:32AM",
    },
    {
      "sender": "You",
      "text":
          "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore",
      "time": "10:32AM",
    },
    {
      "sender": "Dr. Sharma",
      "text": "nisi ut aliquid ex ea commodi consequatur?",
      "time": "10:32AM",
    },
    {
      "sender": "You",
      "text":
          "Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?",
      "time": "10:32AM",
    },
    {"sender": "Dr. Sharma", "text": "iste natus error sit", "time": "10:32AM"},
    {
      "sender": "You",
      "text": "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
      "time": "10:32AM",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // final height = mediaQuery.size.height;
    // final width = mediaQuery.size.width;
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text("Dr. Sharma"),
        centerTitle: true,
        backgroundColor: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Image.asset(bacskarrowBlack), // your custom close icon
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isMe = message['sender'] == "You";
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment:
                        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      if (!isMe)
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: AssetImage(avatar1), // doctor image
                        ),
                      if (!isMe) SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment:
                              isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['sender'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    isMe
                                        ? AppColors.primaryColor
                                        : Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                message['text'],
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              message['time'],
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isMe) SizedBox(width: 8),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
              child: Row(
                children: [
                  Icon(Icons.add, color: Colors.grey),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Type your message',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      if (_controller.text.trim().isNotEmpty) {
                        setState(() {
                          messages.add({
                            "sender": "You",
                            "text": _controller.text.trim(),
                            "time": "Now",
                          });
                          _controller.clear();
                        });
                      }
                    },
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primaryColor,
                      child: Icon(Icons.send, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
