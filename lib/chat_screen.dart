import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:uuid/uuid.dart';
import 'package:chat_gpt/message.dart';
import 'package:chat_gpt/database.dart';
import 'package:intl/intl.dart'; // for date format
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String apiKey;
  final int createdAt;
  String title;

  ChatScreen(
      {super.key,
      required this.chatId,
      required this.apiKey,
      required this.createdAt,
      required this.title});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  List<Message> _messages = [];
  final uuid = const Uuid();
  final TextEditingController _textController = TextEditingController();
  Uri requestUrl =
      Uri(scheme: 'https', host: 'api.openai.com', path: 'v1/chat/completions');
  bool enableEditTitle = false;

  @override
  void initState() {
    super.initState();
    _getMessagesFromDatabase(widget.chatId);
  }

  Future<void> _getMessagesFromDatabase(chatId) async {
    List<Message> items = await DatabaseProvider.getMessages(chatId);
    setState(() {
      _messages = items;
    });
  }

  Widget _customText(String content, bool isMe, bool isError) {
    Color backgroundColor =
        isMe ? Colors.lightBlueAccent : const Color(0xff2b303a);
    Color textColor = isError ? Colors.red : const Color(0xfffefefe);

    return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: backgroundColor, borderRadius: BorderRadius.circular(20)),
        child: Text(content, style: TextStyle(color: textColor)));
  }

  Widget _textAvatar(String content, bool isMe, bool isError) {
    Widget textWidget = Flexible(child: _customText(content, isMe, isError));
    Widget avatar = isMe
        ? const CircleAvatar(
            backgroundColor: Colors.lightBlueAccent,
            child: Icon(Icons.person),
          )
        : const CircleAvatar(
            backgroundColor: Color(0xff74a99d),
            child: Icon(Icons.android),
          );
    Widget first = isMe ? textWidget : avatar;
    Widget last = isMe ? avatar : textWidget;

    return Container(
        margin: isMe
            ? const EdgeInsets.only(left: 80, right: 10)
            : const EdgeInsets.only(right: 80, left: 10),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            first,
            const SizedBox(width: 10),
            last,
          ],
        ));
  }

  Widget _textAvatarTime(
      String content, bool isMe, bool isError, int createdAt) {
    Widget textWidget = _textAvatar(content, isMe, isError);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Text(DateFormat('EEE, MMM dd HH:mm').format(
              DateTime.fromMicrosecondsSinceEpoch(createdAt, isUtc: true)
                  .toLocal())),
          const SizedBox(height: 5),
          textWidget
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController controller = ScrollController();
    final TextEditingController titleController = TextEditingController();
    titleController.text = widget.title;

    void scrollToBottom() {
      controller.animateTo(controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context, widget.title);
            },
            icon: const Icon(Icons.arrow_back)),
        title: TextField(
            controller: titleController,
            enabled: enableEditTitle,
            decoration: const InputDecoration(border: InputBorder.none)),
        actions: [
          IconButton(
              onPressed: () async {
                if (enableEditTitle) {
                  widget.title = titleController.text;
                  await DatabaseProvider.updateChatTitle(
                      widget.chatId, titleController.text);

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat title updated')));
                }
                setState(() {
                  enableEditTitle = !enableEditTitle;
                });
              },
              icon: enableEditTitle
                  ? const Icon(Icons.save)
                  : const Icon(Icons.edit))
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int index) {
                Message message = _messages[index];

                return _textAvatarTime(message.content, message.sender == 'me',
                    message.messageType == 'error', message.createdAt);
              },
            ),
          ),
          Container(
            margin:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30.0),
                color: const Color(0xff2b303a)),
            child: Row(
              children: [
                Expanded(
                    child: TextField(
                  decoration: const InputDecoration(
                      hintText: 'Type a message', border: InputBorder.none),
                  maxLines: null,
                  onSubmitted: (value) {
                    _sendMessage(value, 'me', 'chatGPT');
                    setState(() {
                      _textController.clear();
                    });
                    scrollToBottom();
                  },
                  controller: _textController,
                )),
                IconButton(
                  splashColor: Colors.transparent,
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    String text = _textController.text;
                    _sendMessage(text, 'me', 'chatGPT');
                    setState(() {
                      _textController.clear();
                    });
                    scrollToBottom();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> addMessage(Message message) async {
    await DatabaseProvider.addMessage(message);
    List<Message> messages = await DatabaseProvider.getMessages(widget.chatId);
    setState(() {
      _messages = messages;
    });
  }

  Future<void> _sendMessage(
      String text, String sender, String recipient) async {
    if (text.isEmpty) {
      return;
    }
    Message newMessage = Message(
        chatId: widget.chatId,
        content: text,
        sender: sender,
        messageType: 'text',
        createdAt: DateTime.now().toUtc().microsecondsSinceEpoch,
        id: uuid.v4());

    addMessage(newMessage);
    // generate response
    try {
      http.Response response = await http.post(requestUrl,
          headers: {
            'Authorization': 'Bearer ${widget.apiKey}',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'model': 'gpt-3.5-turbo-0301',
            "messages": [
              {"role": "user", "content": text}
            ]
          }));
      int status = response.statusCode;

      status == 200
          ? addMessage(Message(
              chatId: widget.chatId,
              content: jsonDecode(response.body)['choices'][0]['message']
                  ['content'],
              sender: recipient,
              messageType: 'text',
              createdAt: DateTime.now().toUtc().microsecondsSinceEpoch,
              id: uuid.v4()))
          : addMessage(Message(
              chatId: widget.chatId,
              content: jsonDecode(response.body)['error']['type'] +
                  ': ' +
                  jsonDecode(response.body)['error']['message'],
              sender: recipient,
              messageType: 'error',
              createdAt: DateTime.now().toUtc().microsecondsSinceEpoch,
              id: uuid.v4()));
    } catch (e) {
      addMessage(Message(
          chatId: widget.chatId,
          content: 'Error: $e',
          sender: recipient,
          messageType: 'error',
          createdAt: DateTime.now().toUtc().microsecondsSinceEpoch,
          id: uuid.v4()));
    }
  }
}
