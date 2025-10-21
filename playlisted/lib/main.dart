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

  //get tracks in an album and print the names and artists
  List<Track> intialTracks = [];
  intialTracks = await SpotifyService().fetchTopTracks(initialToken);

  runApp(MyApp(initialAccessToken: initialToken, intialAccessTracks: intialTracks));
}

class MyApp extends StatelessWidget {
  final String? initialAccessToken;
  final List<Track>? intialAccessTracks;
  const MyApp({super.key, this.initialAccessToken, this.intialAccessTracks});  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(accessToken: initialAccessToken,tracks: intialAccessTracks),
      child: Consumer<MyAppState>(
        builder: (context, appState, _) {
        return MaterialApp(
        title: 'Playlistd',

        //Theme Data

        //Light theme
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 21, 131, 183),
            brightness: Brightness.light,            
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1583B7),
            foregroundColor: Colors.white,
          ),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: Color(0xFF1583B7),
          ),
          ),

        //Dark theme
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 21, 131, 183),
            brightness: Brightness.dark,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0A2233),
            foregroundColor: Colors.white,
          ),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: Color(0xFF0A2233),
            indicatorColor: Color(0xFF1583B7),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF1583B7),
            foregroundColor: Colors.white,            
          ),
          ),

        themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,

        home: appState.isLoggedIn ? MyHomePage() : LoginPage(),
        );
        },
      ),
    );
  }
}


class ToggleButtonManager extends StatefulWidget {
  const ToggleButtonManager({super.key});
  @override
  State<ToggleButtonManager> createState() => _ToggleButtonManagerState();
}

// Toggle button for dark mode
//Other toggle buttons can be added here later
class _ToggleButtonManagerState extends State<ToggleButtonManager> {

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    final isDark = appState.isDarkMode;
    return CircleAvatar(
      radius: 22,
      backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
      child: IconButton(
      icon: Icon( isDark ? Icons.dark_mode : Icons.light_mode, color: isDark ? Colors.white : Colors.black, ),
      onPressed: (){
        appState.toggleDarkMode(!isDark);
      },
    ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  bool isLoggedIn = false;
  bool isDarkMode = false;
  //optional access token (fetched at app startup)
  String? accessToken;
  List<Track>? tracks = [];
  

  MyAppState({this.accessToken, this.tracks}) {
    // Initialize current safely
    if (tracks != null && tracks!.isNotEmpty) {
      current = tracks![0];
    } else {
      current = null;
    }
  }

  Track? current; // Changed to Track? instead of dynamic

  void getNext() {
    if (tracks != null && tracks!.isNotEmpty) {
      //cycle to next track
      int currentIndex = tracks!.indexWhere((track) => track.name == current?.name);
      int nextIndex = (currentIndex + 1) % tracks!.length;
      current = tracks![nextIndex];
    } else {
      current = null;
    }
    notifyListeners();
  }
  
  var favorites = List<Track>.empty(growable: true);

  Color backgroundColor = Colors.white;

  void toggleFavorite() {
    if (current != null) {
      if (favorites.any((track) => track.name == current!.name)) {
        favorites.removeWhere((track) => track.name == current!.name);
      } else {
        favorites.add(current!);
      }
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

  void toggleDarkMode(bool enabled) {
    isDarkMode = enabled;
    if(isDarkMode){
      backgroundColor = Colors.grey.shade800;
    } else {
      backgroundColor = Colors.white;
    }
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
    Track? track = appState.current;

    IconData icon;
    if (track != null && appState.favorites.any((t) => t.name == track.name)) {
      icon = Icons.favorite;
    } else {
      icon = Icons.favorite_border;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Playlistd'), // Title above track names
          if (track != null)
            BigCard(track: track)
          else
            Text('Failed to fetch track'),
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
        for (var track in appState.favorites)
          ListTile(
            leading: Icon(Icons.favorite),
            title: Text(track.name),
            subtitle: Text(track.artists),
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
    required this.track,
  });

  final Track track;

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);
    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );
    final artistStyle = theme.textTheme.titleLarge!.copyWith(
      color: theme.colorScheme.onPrimary.withOpacity(0.8),
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              track.name,
              style: style,
              textAlign: TextAlign.center,
              semanticsLabel: "${track.name}",
            ),
            SizedBox(height: 8),
            Text(
              track.artists,
              style: artistStyle,
              textAlign: TextAlign.center,
              semanticsLabel: "by ${track.artists}",
            ),
          ],
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
            const ToggleButtonManager(),
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