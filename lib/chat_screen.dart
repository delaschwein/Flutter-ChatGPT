import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:chat_gpt/message.dart';
import 'package:chat_gpt/chat.dart';
import 'package:chat_gpt/database.dart';
import 'package:intl/intl.dart'; // for date format
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String APIKey;
  final int createdAt;

  ChatScreen(
      {required this.chatId, required this.APIKey, required this.createdAt});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Message> _messages = [];
  final uuid = Uuid();
  TextEditingController _textController = TextEditingController();
  Uri request_url =
      Uri(scheme: 'https', host: 'api.openai.com', path: 'v1/chat/completions');

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
    Color backgroundColor = isMe ? Colors.lightBlueAccent : Color(0xff2b303a);
    Color textColor = isError ? Colors.red : Color(0xfffefefe);

    return Container(
        child: Text(content, style: TextStyle(color: textColor)),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: backgroundColor, borderRadius: BorderRadius.circular(20)));
  }

  Widget _textAvatar(String content, bool isMe, bool isError) {
    Widget textWidget = Flexible(child: _customText(content, isMe, isError));
    Widget avatar = isMe
        ? CircleAvatar(
            child: Icon(Icons.person),
            backgroundColor: Colors.lightBlueAccent,
          )
        : CircleAvatar(
            child: Icon(Icons.android),
            backgroundColor: Color(0xff74a99d),
          );
    Widget first = isMe ? textWidget : avatar;
    Widget last = isMe ? avatar : textWidget;

    return Container(
        margin: isMe
            ? EdgeInsets.only(left: 80, right: 10)
            : EdgeInsets.only(right: 80, left: 10),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            first,
            SizedBox(width: 10),
            last,
          ],
        ));
  }

  Widget _textAvatarTime(
      String content, bool isMe, bool isError, int createdAt) {
    Widget textWidget = _textAvatar(content, isMe, isError);

    return Container(
        child: Column(
          children: [
            Text(DateFormat('EEE, MMM dd HH:mm').format(
                DateTime.fromMicrosecondsSinceEpoch(createdAt, isUtc: true)
                    .toLocal())),
            SizedBox(height: 5),
            textWidget
          ],
        ),
        margin: EdgeInsets.only(bottom: 10));
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController _controller = ScrollController();

    void _scrollToBottom() {
      _controller.animateTo(_controller.position.maxScrollExtent,
          duration: Duration(milliseconds: 500), curve: Curves.easeOut);
    }

    SchedulerBinding.instance!.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatId),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _controller,
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int index) {
                Message message = _messages[index];

                return _textAvatarTime(message.content, message.sender == 'me',
                    message.messageType == 'error', message.createdAt);
              },
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30.0),
                color: Color(0xff2b303a)),
            child: Row(
              children: [
                Expanded(
                    child: TextField(
                  decoration: InputDecoration(
                      hintText: 'Type a message', border: InputBorder.none),
                  maxLines: null,
                  onSubmitted: (value) {
                    _sendMessage(value, 'me', 'chatGPT');
                    setState(() {
                      _textController.clear();
                    });
                    _scrollToBottom();
                  },
                  controller: _textController,
                )),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    String text = _textController.text;
                    _sendMessage(text, 'me', 'chatGPT');
                    setState(() {
                      _textController.clear();
                    });
                    _scrollToBottom();
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
      http.Response response = await http.post(request_url,
          headers: {
            'Authorization': 'Bearer ${widget.APIKey}',
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
