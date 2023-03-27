import 'package:chat_gpt/chat.dart';
import 'package:chat_gpt/chat_screen.dart';
import 'package:chat_gpt/database.dart';
import 'package:chat_gpt/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:uuid/uuid.dart';

class CustomFab extends StatefulWidget {
  final Function callback;
  final TextEditingController apiController;
  final ScrollController scrollController;

  const CustomFab(
      {super.key,
      required this.callback,
      required this.apiController,
      required this.scrollController});

  @override
  CustomFabState createState() => CustomFabState();
}

class CustomFabState extends State<CustomFab> {
  final uuid = const Uuid();

  bool isVisible = true;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(() {
      if (widget.scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (isVisible) {
          setState(() {
            isVisible = false;
          });
        }
      }
      if (widget.scrollController.position.userScrollDirection ==
          ScrollDirection.forward) {
        if (!isVisible) {
          setState(() {
            isVisible = true;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
        isExtended: isVisible,
        onPressed: () async {
          String chatId = uuid.v4();
          int createdAt = DateTime.now().toUtc().millisecondsSinceEpoch;
          final newChat = Chat(id: chatId, createdAt: createdAt, title: chatId);
          await DatabaseProvider.addChat(newChat);
          await widget.callback();
          await DatabaseProvider.addMessage(Message(
              id: uuid.v4(),
              content: "You are a helpful assistant.",
              sender: "system",
              createdAt: createdAt,
              chatId: chatId,
              messageType: "text"));
          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                apiKey: widget.apiController.text,
                createdAt: createdAt,
                title: chatId,
              ),
            ),
          );
        },
        label: const Text("New Chat"),
        icon: const Icon(Icons.add));
  }
}
