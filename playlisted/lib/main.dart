import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'spotify.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'favorites.dart';
import 'favoritesPage.dart';
import 'recommendations.dart';
import 'recommendationsPage.dart';
import 'search.dart';
import 'profile.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  //firebase local part for web dev
  if (kIsWeb) {
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  } else {
    FirebaseFirestore.instance.settings =
        const Settings(cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  }
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

        home: const AuthGate(),
        );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasData) {
          // user is signed in
          return MyHomePage(); // remove const if MyHomePage isn't const
        }
        // user is signed out
        return const LoginPage();
      },
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
  bool isDarkMode = false;
  //optional access token (fetched at app startup)
  String? accessToken;
  List<Track>? tracks = [];
  Recommendations recommendService = Recommendations.instance;
  //map for song ratings
  final Map<String, double> ratings = {};
  String keyOf(Track t) => t.name;

  double ratingFor(Track t) => ratings[keyOf(t)] ?? 0;



void setRating(Track t, double rating) {
  final r = rating.clamp(0.0, 5.0);
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
    if (current == null) return;
    final isFavNow = !favorites.any((t) => t.name == current!.name);
    if (isFavNow) {
      favorites.add(current!);
    } else {
      favorites.removeWhere((t) => t.name == current!.name);
    }
    notifyListeners();
    try {
        Favorites.instance.setFavorite(
        trackId: current!.id!,
        name: current!.name,
        artists: current!.artists,
        albumImageUrl: current!.albumImageUrl,
        favorite: isFavNow,
      );
    } catch (e) {
      print('Failed to save favorite: $e');
    }
  }
  
  //! DEPRECATED
  // void incRecCount() {
  //   recommendService.recCount++;
  //   if(recommendService.recCount >= 5) {
  //     recommendService.recCount = 0;
  //     generateRecommendations();
  //   }
  // }

  Future<void> generateRecommendations() async {
    if (favorites.isEmpty) {
      print('No liked tracks available for recommendations.');
      return;
    }
    else{
      await recommendService.getRec(favorites, accessToken);
    }
    notifyListeners();
  }

  void changeBackground(Color color) {
    backgroundColor = color;
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
    SearchPage(),
    RecommendationsPage(), // switches to the favorites page class
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) { 
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.settings),
              onPressed: () => _openSettings(context),
            ),
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
                  icon: Icon(Icons.search_rounded),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music),
                  label: 'Recommend',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person),
                  label: 'My Profile',
                ),
              ],
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                setState(() => selectedIndex = index);
              },
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
              onChanged: (r) async {
              // local
              appState.setRating(track, r);
              // Reloads Favorites from Firestore
              await Favorites.instance.setRating(
                trackId: track.id!,
                name: track.name,
                artists: track.artists,
                albumImageUrl: track.albumImageUrl,
                rating: r,
                );
              },
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
                    appState.getPrevious();
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Vinyl and jacket display
        if (track.albumImageUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Vinyl record 
                Transform.translate(
                  offset: Offset(132, 0),
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Vinyl grooves
                        for (int i = 1; i <= 6; i++)
                          Container(
                            width: 280 - (i * 30.0),
                            height: 280 - (i * 30.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                          ),
                        // Center label
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                          child: Icon(
                            Icons.album,
                            color: theme.colorScheme.onPrimary,
                            size: 40,
                          ),
                        ),
                        // Center hole
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
               
               // Gray box that appear when imgage is loading and will be cover by the album image  
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                     color: Colors.grey,
                  )
                ),
                
                 // Album jacket/cover
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: Offset(5, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: Image.network(
                      track.albumImageUrl!,
                      width: 250,
                      height: 250,
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
              ],
            ),
          ),
        // Track info card
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
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
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



class StarRating extends StatelessWidget {
  final double rating; // 0.0–5.0, supports halves
  final ValueChanged<double> onChanged;
  final double size;
  final double spacing;

  const StarRating({
    super.key,
    required this.rating,
    required this.onChanged,
    this.size = 28,
    this.spacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Use theme color for consistency
    final starColor = Theme.of(context).colorScheme.secondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        IconData icon;

        if (rating >= starValue) {
          icon = Icons.star;
        } else if (rating >= starValue - 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }

        return GestureDetector(
          onTap: () {
            if (rating >= starValue) {
              onChanged(starValue - 0.5);
            } else {
              onChanged(starValue.toDouble());
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: Icon(icon, size: size, color: starColor),
          ),
        );
      }),
    );
  }
}



