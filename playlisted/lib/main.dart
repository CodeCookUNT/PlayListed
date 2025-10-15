import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'spotify.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //load environment variables (.env) so SpotifyService can read client id/secret
  await dotenv.load(fileName: '.env');

  //get our initial token, ? means our token can be null if fetch fails
  String? initialToken;
  try {
    initialToken = await SpotifyService().getAccessToken();
    print('Initial Spotify token fetched');
  } catch (e) {
    initialToken = null;
    print('Failed to fetch initial token: $e');
  }

  runApp(MyApp(initialAccessToken: initialToken));
}

class MyApp extends StatelessWidget {
  final String? initialAccessToken;
  const MyApp({super.key, this.initialAccessToken});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(accessToken: initialAccessToken),
      child: MaterialApp(
        title: 'Playlistd',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 21, 131, 183)),
        ),
        home: Consumer<MyAppState>(
          builder: (context, appState, _) {
            if (appState.isLoggedIn) {
              return MyHomePage(); // your existing home page
            } else {
              return LoginPage();
            }
          },
        ),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  bool isLoggedIn = false;
  //optional access token (fetched at app startup)
  String? accessToken;
  //use this to hold fetched tracks when fetchTopTracks returns data
  late final Future<List<Track>> tracks;

  MyAppState({this.accessToken}){
     //get top tracks (later would be user specific)
     tracks = SpotifyService().fetchTopTracks(accessToken);
     print(tracks);
  }

  var current = WordPair.random();
  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }
  var favorites = <WordPair>[];
  Color backgroundColor = Colors.white;

  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current);
    }
    notifyListeners();
  }

  void changeBackground(Color color) {
    backgroundColor = color;
    notifyListeners();
  }

  //login in section
  void login(String username, String password) {
    isLoggedIn = true;
    notifyListeners();
  }
  void logout() {
    isLoggedIn = false;
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int selectedIndex = 0;

  final pages = [
    GeneratorPage(),
    FavoritesPage(),
    RecommendationsPage(), // switches to the favorites page class
  ];

  @override
  Widget build(BuildContext context) { 
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          appBar: AppBar(
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(30), //adjust distance of nav bar
              child: NavigationBar(
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.favorite),
                    label: 'Favorites',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.library_music),
                    label: 'Recommendations',
                  ),
                ],
        
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) {
                  setState(() => selectedIndex = index);
                },
        
              ),
            ),
          ),
          body: Container(
          color: context.watch<MyAppState>().backgroundColor,
          child: pages[selectedIndex],
          ),

          floatingActionButton: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: FloatingActionButton(
            heroTag: 'settingsButton',
            onPressed: () => _openSettings(context),
            child: const Icon(Icons.settings),
            ),
            ),
          ),
        );
      }
    );
  }
}

class GeneratorPage extends StatelessWidget { // page builder
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var pair = appState.current;

    IconData icon;
    if (appState.favorites.contains(pair)) {
      icon = Icons.favorite;
    } else {
      icon = Icons.favorite_border;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Playlistd'), // Title above random word pairs
          BigCard(pair: pair),
          SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  appState.toggleFavorite();
                },
                icon: Icon(icon),
                label: Text('Like'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  appState.getNext();
                },
                child: Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget { //favorites page 
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.favorites.isEmpty) {
      return Center(
        child: Text('No favorites yet.'),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('You have '
              '${appState.favorites.length} favorites:'),
        ),
        for (var pair in appState.favorites)
          ListTile(
            leading: Icon(Icons.favorite),
            title: Text(pair.asLowerCase),
          ),
      ],
    );
  }
}

class RecommendationsPage extends StatelessWidget { //favorites page 
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('You have no Recommendations yet'),
        )
      ],
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.pair,
  });

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          pair.asLowerCase,
          style: style,
          semanticsLabel: "${pair.first} ${pair.second}",
        ),
      ),
    );
  }
}
void _openSettings(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      var appState = context.watch<MyAppState>();
      return Container(
        padding: const EdgeInsets.all(16),
        height: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Background Color',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              children: [
                _colorCircle(context, Colors.white),
                _colorCircle(context, Colors.blue.shade100),
                _colorCircle(context, Colors.green.shade100),
                _colorCircle(context, Colors.pink.shade100),
                _colorCircle(context, Colors.grey.shade300),
              ],
            ),
            ElevatedButton(
              child: Text('Logout'),
              onPressed: () {
                appState.logout();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    },
  );
}

Widget _colorCircle(BuildContext context, Color color) {
  var appState = context.read<MyAppState>();
  return GestureDetector(
    onTap: () {
      appState.changeBackground(color);
      Navigator.pop(context);
    },
    child: CircleAvatar(
      backgroundColor: color,
      radius: 22,
      child: appState.backgroundColor == color
          ? const Icon(Icons.check, color: Colors.black)
          : null,
    ),
  );
}
// login page
class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Login'),
              onPressed: () {
                appState.login(usernameController.text, passwordController.text);
              },
            ),
          ],
        ),
      ),
    );
  }
}
