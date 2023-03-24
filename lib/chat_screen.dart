import 'dart:convert';

import 'package:flutter/material.dart';
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

  ChatScreen({required this.chatId, required this.APIKey});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatId),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int index) {
                return Column(
                  children: [
                    ListTile(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: _messages[index].content));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Copied to clipboard'),
                        ));
                      },
                      leading: CircleAvatar(
                        child: _messages[index].sender == 'me' ? Icon(Icons.person) : Icon(Icons.android),
                      ),
                      title: Text(_messages[index].sender),
                      subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('yyyy-MM-dd hh:mm:ss').format(
                                DateTime.fromMicrosecondsSinceEpoch(
                                    _messages[index].createdAt))),
                            SizedBox(height: 5),
                            _messages[index].messageType == 'text'
                                ? Text(_messages[index].content)
                                : Text(_messages[index].content, style: TextStyle(color: Colors.red)),
                          ]),
                    ),
                    Divider(
                      thickness: 2,
                      height: 20,
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(hintText: 'Type a message'),
                    onSubmitted: (value) {
                      _sendMessage(value, 'me', 'chatGPT');
                      setState(() {
                        _textController.clear();
                      });
                    },
                    controller: _textController,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    String text = _textController.text;
                    _sendMessage(text, 'me', 'chatGPT');
                    setState(() {
                      _textController.clear();
                    });
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
        createdAt: DateTime.now().microsecondsSinceEpoch,
        id: uuid.v4());
    
    addMessage(newMessage);
    // generate response
    try {
      http.Response response = await http.post(request_url, headers: {
        'Authorization': 'Bearer ${widget.APIKey}',
        'Content-Type': 'application/json'
      }, body: jsonEncode({
        'model': 'gpt-3.5-turbo-0301',
        "messages": [
          {"role": "user", "content": text}
        ]
      }));
      int status = response.statusCode;

      status == 200
          ? addMessage(Message(
              chatId: widget.chatId,
              content: jsonDecode(response.body)['choices'][0]['message']['content'],
              sender: recipient,
              messageType: 'text',
              createdAt: DateTime.now().microsecondsSinceEpoch,
              id: uuid.v4()))
          : addMessage(Message(
              chatId: widget.chatId,
              content: jsonDecode(response.body)['error']['type'] + ': ' + jsonDecode(response.body)['error']['message'],
              sender: recipient,
              messageType: 'error',
              createdAt: DateTime.now().microsecondsSinceEpoch,
              id: uuid.v4()));
    } catch (e) {
      addMessage(Message(
              chatId: widget.chatId,
              content: 'Error: $e',
              sender: recipient,
              messageType: 'error',
              createdAt: DateTime.now().microsecondsSinceEpoch,
              id: uuid.v4()));
    }
  }
}
