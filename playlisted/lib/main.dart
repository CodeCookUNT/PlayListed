import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'spotify.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('Firebase initialized ✅');
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

  //get tracks by searching popular genres and years
  List<Track> initialTracks = [];
  try {
    initialTracks = await SpotifyService().fetchTopSongs(initialToken);
    print('Fetched ${initialTracks.length} songs');
  } catch (e) {
    print('Failed to fetch top songs: $e');
  }
  
  runApp(MyApp(initialAccessToken: initialToken, intialAccessTracks: initialTracks));
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
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        child: IconButton(
        icon: Icon( isDark ? Icons.dark_mode : Icons.light_mode, color: isDark ? Colors.white : Colors.black, ),
        onPressed: (){
          appState.toggleDarkMode(!isDark);
        },
      ),
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
  //map for song ratings
  final Map<String, int> ratings = {};
  String keyOf(Track t) => t.name;

  int ratingFor(Track t) => ratings[keyOf(t)] ?? 0;

  void setRating(Track t, int rating) {
    final r = rating.clamp(0, 5);
    final k = keyOf(t);

    if (r <= 0) {
      ratings.remove(k);
      favorites.removeWhere((x) => keyOf(x) == k);
    } else {
      ratings[k] = r;
      if (!favorites.any((x) => keyOf(x) == k)) {
        favorites.add(t);
      }
    }
    notifyListeners();
  }
  

  MyAppState({this.accessToken, this.tracks}) {
    // Initialize current safely
    if (tracks != null && tracks!.isNotEmpty) {
      current = tracks![0];
    } else {
      current = null;
    }
  }

  Track? current; // Changed to Track? instead of dynamic
  //! in order for the next button and next button to work correctly you need to create a index
  //! function that both pull from so they dont make 2 seperate indexs
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
  void getPrevious() {
    if (tracks != null && tracks!.isNotEmpty) {
      //cycle to previous track
      int currentIndex = tracks!.indexWhere((track) => track.name == current?.name);
      int nextIndex = (currentIndex - 1) % tracks!.length;
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
          ),
          body: Container(
            color: context.watch<MyAppState>().backgroundColor,
            child: pages[selectedIndex],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: Offset(0, -3),
                ),
              ],
            ),
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
          if (track != null)...[
            BigCard(track: track),

           StarRating(
              rating: appState.ratingFor(track),
              onChanged: (r) => appState.setRating(track, r),
            ),
          ]else
            Text('Failed to fetch track'),
          SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () {
                    appState.getNext();
                  },
                  child: Text('Back'),
                ),
              ),
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
            leading: track.albumImageUrl != null
                ? Image.network(
                    track.albumImageUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.favorite);
                    },
                  )
                : Icon(Icons.favorite),
            title: Text(track.name),
            subtitle: Text(track.artists),
            trailing: StarRating(
              rating: appState.ratingFor(track),
              onChanged: (r) => appState.setRating(track, r),
              size: 20,
              spacing: 2,
            ),
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
    final style = theme.textTheme.titleLarge!.copyWith(
      color: theme.colorScheme.primary,
    );
    final artistStyle = theme.textTheme.titleMedium!.copyWith(
      color: theme.colorScheme.primary.withOpacity(0.8),
    );

    // Album artwork
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (track.albumImageUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                track.albumImageUrl!,
                width: 300,
                height: 300,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 300,
                    height: 300,
                    color: Colors.grey,
                    child: Icon(Icons.album, size: 100, color: Colors.white),
                  );
                },
              ),
            ),
          ),
        Card(
          color: theme.colorScheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.name,
                  style: style.copyWith(color: theme.colorScheme.onPrimary),
                  textAlign: TextAlign.center,
                  semanticsLabel: track.name,
                ),
                SizedBox(height: 8),
                Text(
                  track.artists,
                  style: artistStyle.copyWith(color: theme.colorScheme.onPrimary.withOpacity(0.8)),
                  textAlign: TextAlign.center,
                  semanticsLabel: "by ${track.artists}",
                ),
              ],
            ),
          ),
        ),
      ],
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
              '    Settings    ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                child: Text('Sign up'),
                onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpPage()),
                );
              },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpPage extends StatefulWidget {
  @override
  State<SignUpPage> createState() => SignUpPageState();
}

class SignUpPageState extends State<SignUpPage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);

    return Scaffold(
      appBar: AppBar(title: Text('SignUp')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: firstNameController,
              decoration: InputDecoration(labelText: 'First Name'),
            ),
            TextField(
              controller: lastNameController,
              decoration: InputDecoration(labelText: 'Last Name'),
            ),
            TextField(
              controller: usernameController,
              decoration: InputDecoration(labelText: 'User Name'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Finish'),
              onPressed: () {
                //just goes back to login page for now
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    required this.onChanged,
    this.size = 28,
    this.spacing = 0,
  });

  final int rating;
  final ValueChanged<int> onChanged;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return Padding(
          padding: EdgeInsets.only(right: i == 4 ? 0 : spacing),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: size,
            icon: Icon(filled ? Icons.star : Icons.star_border),
            onPressed: () => onChanged(i + 1),
            tooltip: 'Rate ${i + 1}',
          ),
        );
      }),
    );
  }
}