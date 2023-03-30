import 'package:chat_gpt/chat.dart';
import 'package:chat_gpt/chat_screen.dart';
import 'package:chat_gpt/database.dart';
import 'package:chat_gpt/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:uuid/uuid.dart';

class CustomFab extends StatefulWidget {
  final Function callback;
  final TextEditingController apiController;
  final bool isVisible;

  const CustomFab(
      {super.key,
      required this.callback,
      required this.apiController,
      required this.isVisible});

  @override
  CustomFabState createState() => CustomFabState();
}

class CustomFabState extends State<CustomFab>
    with SingleTickerProviderStateMixin {
  final uuid = const Uuid();
  final double _size = 56.toDouble();
  final double _expandedSize = 150.toDouble();
  final Icon _icon = const Icon(Icons.chat);

  @override
  void initState() {
    super.initState();
  }

  Future<void> _onPressFab() async {
    String chatId = uuid.v4();
        int createdAt = DateTime.now().toUtc().millisecondsSinceEpoch;
        final newChat = Chat(id: chatId, createdAt: createdAt, title: chatId);

        await DatabaseProvider.addChat(newChat);
        await DatabaseProvider.addMessage(Message(
            id: uuid.v4(),
            content: "You are a helpful assistant.",
            sender: "system",
            createdAt: createdAt,
            chatId: chatId,
            messageType: "text"));
        await widget.callback();
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
  }

  Widget extendedFab() {
    return FloatingActionButton.extended(
      shape: const StadiumBorder(),
      onPressed: _onPressFab,
      label: const Text("New Chat"),
      icon: _icon,
    );
  }

  Widget fab() {
    return FloatingActionButton(
      shape: const CircleBorder(),
      onPressed: _onPressFab,
      child: _icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      width: widget.isVisible ? _expandedSize : _size,
      height: _size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_size / 2),
      ),
      duration: const Duration(milliseconds: 150),
      curve: Curves.linear,
      child: widget.isVisible ? extendedFab() : fab(),
    );
  }
}

/*  */