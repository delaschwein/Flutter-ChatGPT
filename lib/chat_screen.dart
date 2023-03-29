import "dart:convert";

import "package:chat_gpt/database.dart";
import "package:chat_gpt/message.dart";
import "package:chat_gpt/typing_indicator.dart";
import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";
import 'package:flutter/services.dart';
import "package:http/http.dart" as http;
import "package:intl/intl.dart"; // for date format
import "package:uuid/uuid.dart";

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

class ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  List<Message> _messages = [];
  final uuid = const Uuid();
  final TextEditingController _textController = TextEditingController();
  Uri requestUrl =
      Uri(scheme: "https", host: "api.openai.com", path: "v1/chat/completions");
  bool enableEditTitle = false;
  final ScrollController controller = ScrollController();
  final TextEditingController titleController = TextEditingController();
  late AnimationController animationController;
  bool isWaitingResponse = false;
  bool isTextEmpty = true;
  bool isKeyboardVisible = false;
  double keyboardHeight = 0.0;

  @override
  void initState() {
    super.initState();
    _getMessagesFromDatabase(widget.chatId);
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    animationController.forward();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _getMessagesFromDatabase(chatId) async {
    List<Message> items = await DatabaseProvider.getMessages(chatId);
    setState(() {
      _messages = items;
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox) {
      final viewInsets = WidgetsBinding.instance.window.viewInsets;
      final newKeyboardHeight = viewInsets.bottom;
      final keyboardVisibility = viewInsets.bottom > 0.0;
      if (keyboardHeight != newKeyboardHeight) {
        setState(() {
          keyboardHeight = newKeyboardHeight;
        });
      }
      if (isKeyboardVisible != keyboardVisibility) {
        setState(() {
          isKeyboardVisible = keyboardVisibility;
        });
      }
    }
  }

  Widget _customText(
      String content, String sender, bool isError, bool isLatestMessage) {
    final bool isMe = sender == "me";
    Color backgroundColor =
        isMe ? Colors.lightBlueAccent : const Color(0xff2b303a);
    Color textColor;

    if (isError) {
      textColor = Colors.red;
    } else if (isMe) {
      textColor = Colors.black;
    } else {
      textColor = const Color(0xfffefefe);
    }

    return GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: content));
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Copied to clipboard")));
        },
        child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(20)),
            child: Text(content,
                style: TextStyle(
                  color: textColor,
                ))));
  }

  Widget _textAvatar(
      String content, String sender, bool isError, bool isLatestMessage) {
    Widget textWidget =
        Flexible(child: _customText(content, sender, isError, isLatestMessage));
    final bool isMe = sender == "user";
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
          crossAxisAlignment: CrossAxisAlignment.end,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            first,
            const SizedBox(width: 10),
            last,
          ],
        ));
  }

  Widget _textAvatarTime(String content, String sender, bool isError,
      int createdAt, bool isLatestMessage) {
    Widget textWidget = _textAvatar(content, sender, isError, isLatestMessage);
    Widget listItem = sender == "user"
        ? Column(
            children: [
              Text(DateFormat("EEE, MMM dd HH:mm").format(
                  DateTime.fromMicrosecondsSinceEpoch(createdAt, isUtc: true)
                      .toLocal())),
              const SizedBox(height: 5),
              textWidget
            ],
          )
        : textWidget;

    return Container(margin: const EdgeInsets.only(top: 10), child: listItem);
  }

  @override
  Widget build(BuildContext context) {
    titleController.text = widget.title;

    void scrollToBottom() {
      controller.animateTo(controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      scrollToBottom();
    });

    return GestureDetector(
        onTap: () {
          if (isKeyboardVisible) {
            final currentFocus = FocusScope.of(context);
            if (!currentFocus.hasPrimaryFocus) {
              currentFocus.unfocus();
            }
          }
        },
        child: Scaffold(
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
                          const SnackBar(content: Text("Chat title updated")));
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

                    if (message.sender != "system") {
                      return _textAvatarTime(
                          message.content,
                          message.sender,
                          message.messageType == "error",
                          message.createdAt,
                          index == _messages.length - 1);
                    }
                    return Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration:
                            const BoxDecoration(color: Color(0xff2b303a)),
                        child: const Center(
                          child:
                              Text("This is the beginning of the conversation"),
                        ));
                  },
                ),
              ),
              // Represents the text field where the user types the message
              Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 10.0),
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30.0),
                    color: const Color(0xff2b303a)),
                child: Row(
                  children: [
                    Expanded(
                        child: TextField(
                      decoration: const InputDecoration(
                          hintText: "Type a message", border: InputBorder.none),
                      maxLines: null,
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          setState(() {
                            isTextEmpty = false;
                          });
                        } else {
                          setState(() {
                            isTextEmpty = true;
                          });
                        }
                      },
                      onSubmitted: (value) {
                        _sendMessage(value, "user", "assistant", _messages);
                        setState(() {
                          _textController.clear();
                        });
                        scrollToBottom();
                      },
                      controller: _textController,
                    )),
                    AnimatedOpacity(
                      opacity: isTextEmpty ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animationController,
                            curve: Curves.easeInOut,
                          )),
                          child: IconButton(
                            highlightColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            icon: const Icon(Icons.send),
                            onPressed: () async {
                              String text = _textController.text.trim();
                              setState(() {
                                _textController.clear();
                              });
                              await _sendMessage(
                                  text, "user", "assistant", _messages);

                              scrollToBottom();
                            },
                          )),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  Future<void> addMessage(Message message) async {
    if (message.sender == "user") {
      setState(() {
        isWaitingResponse = true;
      });
    }
    if (message.sender == "assistant") {
      setState(() {
        isWaitingResponse = false;
      });
    }
    await DatabaseProvider.addMessage(message);
    _getMessagesFromDatabase(widget.chatId);
  }

  Future<void> _sendMessage(String text, String sender, String recipient,
      List<Message> history) async {
    if (text.isEmpty) {
      return;
    }
    Message newMessage = Message(
        chatId: widget.chatId,
        content: text,
        sender: sender,
        messageType: "text",
        createdAt: DateTime.now().toUtc().microsecondsSinceEpoch,
        id: uuid.v4());

    await addMessage(newMessage);

    List<Map<String, String>> allMessages = [];
    for (Message message in history) {
      allMessages.add({
        "role": message.sender,
        "content": message.content,
      });
    }
    allMessages.add({"role": "user", "content": text});
    // generate response
    try {
      http.Response response = await http.post(requestUrl,
          headers: {
            "Authorization": "Bearer ${widget.apiKey}",
            "Content-Type": "application/json"
          },
          body: jsonEncode(
              {"model": "gpt-3.5-turbo-0301", "messages": allMessages}));
      int status = response.statusCode;

      status == 200
          ? await addMessage(Message(
              chatId: widget.chatId,
              content: jsonDecode(response.body)["choices"][0]["message"]
                  ["content"],
              sender: recipient,
              messageType: "text",
              createdAt: DateTime.now().toUtc().microsecondsSinceEpoch,
              id: uuid.v4()))
          : await addMessage(Message(
              chatId: widget.chatId,
              content: jsonDecode(response.body)["error"]["type"] +
                  ": " +
                  jsonDecode(response.body)["error"]["message"],
              sender: recipient,
              messageType: "error",
              createdAt: DateTime.now().toUtc().microsecondsSinceEpoch,
              id: uuid.v4()));
    } catch (e) {
      await addMessage(Message(
          chatId: widget.chatId,
          content: "Error: $e",
          sender: recipient,
          messageType: "error",
          createdAt: DateTime.now().toUtc().microsecondsSinceEpoch,
          id: uuid.v4()));
    }
  }
}
