import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:chat_gpt/chat.dart';
import 'package:chat_gpt/database.dart';
import 'package:uuid/uuid.dart';
import 'package:chat_gpt/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Chat GPT',
        home: const MyHomePage(),
        themeMode: ThemeMode.dark,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xff161c23),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xff161c23),
          ),
        ));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController(initialPage: 0);
  List<Chat> _chats = [];
  final uuid = const Uuid();
  final TextEditingController _apiController = TextEditingController();

  Uri testUrl = Uri(scheme: 'https', host: 'api.openai.com', path: 'v1/models');

  @override
  void initState() {
    super.initState();
    _getChatsFromDatabase();
    initializeSharedPreferences();
  }

  void initializeSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Now that the prefs variable has a value, you can use it
    String? apiKey = prefs.getString('api_key');
    if (apiKey != null) {
      _apiController.text = apiKey;
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
    ScrollController scrollController = ScrollController();
    List<String> chatTitles = _chats.map((e) => e.title).toList();

    return Scaffold(
        appBar: AppBar(
          title: const Text('My App'),
          backgroundColor: const Color(0xff161c23),
        ),
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          children: [
            ListView.builder(
              itemCount: _chats.length,
              controller: scrollController,
              itemBuilder: (context, index) {
                Chat chat = _chats[index];

                return ListTile(
                    title: Text(chatTitles[index]),
                    onTap: () async {
                      String newTitle = await Navigator.push(
                          context,
                          PageRouteBuilder(
                              pageBuilder: (_, __, ___) => ChatScreen(
                                  chatId: chat.id,
                                  apiKey: _apiController.text,
                                  createdAt: chat.createdAt,
                                  title: chat.title),
                              transitionsBuilder: (_,
                                  Animation<double> animation,
                                  __,
                                  Widget child) {
                                return SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(1.0, 0.0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                );
                              }));
                          if (newTitle != chatTitles[index]) {
                            setState(() {
                              chatTitles[index] = newTitle;
                            });
                          }
                        await _getChatsFromDatabase();
                    },
                    onLongPress: () async {
                      await DatabaseProvider.deleteChat(chat.id);
                      if (!mounted) return;

                      setState(() {
                        _chats.removeAt(index);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Item deleted'),
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
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: TextField(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'API Key',
                      ),
                      controller: _apiController,
                    )),
                IconButton(
                    onPressed: () async {
                      String apiKey = _apiController.text;
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();

                      await prefs.setString('api_key', apiKey);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('API Key saved'),
                      ));
                    },
                    icon: const Icon(Icons.save)),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateColor.resolveWith(
                          (states) => Colors.teal),
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25.0),
                        ),
                      ),
                    ),
                    onPressed: () async {
                      try {
                        http.Response response = await http.get(testUrl,
                            headers: {
                              'Authorization': 'Bearer ${_apiController.text}'
                            });

                        if (!mounted) return;
                        int status = response.statusCode;
                        status == 200
                            ? ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                                content: Text('Server is online'),
                              ))
                            : ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(
                                content: Text('Error: $status'),
                              ));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Error: $e'),
                        ));
                      }
                    },
                    child: const Text('Check API Status'),
                  ),
                )
              ],
            )),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: const Color(0xff1b242f),
          currentIndex: _selectedIndex,
          onTap: _onNavItemTapped,
          items: const [
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
          scrollController: scrollController,
        ));
  }
}

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
          final newChat = Chat(
            id: chatId,
            createdAt: createdAt,
            title: chatId
          );
          await DatabaseProvider.addChat(newChat);
          await widget.callback();
          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                  chatId: chatId,
                  apiKey: widget.apiController.text,
                  createdAt: createdAt,
                  title: chatId,),
            ),
          );
        },
        label: const Text('New Chat'),
        icon: const Icon(Icons.add));
  }
}
