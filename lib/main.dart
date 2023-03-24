import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:chat_gpt/chat.dart';
import 'package:chat_gpt/database.dart';
import 'package:uuid/uuid.dart';
import 'package:chat_gpt/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'My App',
        home: MyHomePage(),
        themeMode: ThemeMode.dark,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Color(0xff161c23),
          appBarTheme: AppBarTheme(
            backgroundColor: Color(0xff161c23),
          ),
        ));
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  PageController _pageController = PageController(initialPage: 0);
  List<Chat> _chats = [];
  final uuid = Uuid();
  TextEditingController _apiController = TextEditingController();

  Uri test_url =
      Uri(scheme: 'https', host: 'api.openai.com', path: 'v1/models');

  @override
  void initState() {
    super.initState();
    _getChatsFromDatabase();
    initializeSharedPreferences();
  }

  void initializeSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Now that the prefs variable has a value, you can use it
    if (prefs.containsKey('APIKey')) {
      _apiController.text = prefs.getString('APIKey')!;
    }
  }

  Future<void> _getChatsFromDatabase() async {
    List<Chat> items = await DatabaseProvider.getChats();
    setState(() {
      _chats = items;
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onNavItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }





  @override
  Widget build(BuildContext context) {
    ScrollController _scrollController = ScrollController();

    return Scaffold(
      appBar: AppBar(
        title: Text('My App'),
        backgroundColor: Color(0xff161c23),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [
          ListView.builder(
            itemCount: _chats.length,
            controller: _scrollController,
            itemBuilder: (context, index) {
              Chat chat = _chats[index];

              return ListTile(
                  title: Text(chat.id),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                            chatId: chat.id,
                            APIKey: _apiController.text,
                            createdAt: chat.createdAt),
                      ),
                    );
                  },
                  onLongPress: () async {
                    await DatabaseProvider.deleteChat(chat.id);
                    setState(() {
                      _chats.removeAt(index);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Item deleted'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () async {
                          setState(() {
                            _chats.insert(index, chat);
                          });
                          await DatabaseProvider.addChat(chat);
                          await _getChatsFromDatabase();
                        },
                      ),
                    ));
                  });
            },
          ),
          Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: TextField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'API Key',
                    ),
                    controller: _apiController,
                  )),
              IconButton(
                  onPressed: () async {
                    String APIKey = _apiController.text;
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    await prefs.setString('api_key', APIKey);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('API Key saved'),
                    ));
                  },
                  icon: Icon(Icons.save)),
              Container(
                height: 50,
                child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateColor.resolveWith((states) => Colors.teal),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      http.Response response = await http.get(test_url,
                          headers: {
                            'Authorization': 'Bearer ${_apiController.text}'
                          });
                      int status = response.statusCode;

                      status == 200
                          ? ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Server is online'),
                            ))
                          : ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Error: $status'),
                            ));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Error: $e'),
                      ));
                    }
                  },
                  child: Text('Check API Status'),
                ),
              )
            ],
          )),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color(0xff1b242f),
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: CustomFab(
        callback: _getChatsFromDatabase,
        apiController: _apiController,
        scrollController: _scrollController,)
    );
  }
}


class CustomFab extends StatefulWidget {
  final Function callback;
  final TextEditingController apiController;
  final ScrollController scrollController;
  
  CustomFab({required this.callback, required this.apiController, required this.scrollController});

  @override
  _CustomFabState createState() => _CustomFabState();
}

class _CustomFabState extends State<CustomFab> {
  final uuid = Uuid();

  bool isVisible = true;

  @override
  void initState() {
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
            final newChat = Chat(
              id: chatId,
              createdAt: createdAt,
            );
            await DatabaseProvider.addChat(newChat);
            await widget.callback();

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                    chatId: chatId,
                    APIKey: widget.apiController.text,
                    createdAt: createdAt),
              ),
            );
          },
          label: Text('New Chat'),
          icon: Icon(Icons.add));
  }
}