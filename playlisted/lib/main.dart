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
// recommendationsPage.dart is no longer referenced in main.dart
import 'search.dart';
import 'profile.dart';
import 'colike.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'globalratings.dart';
import 'friendsPage.dart';
import 'collectionspage.dart';
import 'loading_vinyl.dart';
import 'dart:async';
import 'content_filter.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );
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

  // Note: we no longer fetch a token or tracks here.  Instead the
  // application will request both after the user has successfully
  // logged in.  This keeps the login flow fast and ensures the feed is
  // refreshed on every sign‑in.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: Consumer<MyAppState>(
        builder: (context, appState, _) {
        return MaterialApp(
        title: 'Playlist\'d',

        //Theme Data
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
          return MyHomePage();
        }
        return const LoginPage();
      },
    );
  }
}

// Toggle button for dark mode
// Other toggle buttons can be added here later
class ToggleButtonManager extends StatefulWidget {
  const ToggleButtonManager({super.key});
  @override
  State<ToggleButtonManager> createState() => _ToggleButtonManagerState();
}

class _ToggleButtonManagerState extends State<ToggleButtonManager> {

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    final isDark = appState.isDarkMode;
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: CircleAvatar(
            radius: 28,
            backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            child: IconButton(
              iconSize: 32,
              icon: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: () => appState.toggleDarkMode(!isDark)    
            )
          )
        )
      );
  }
}


class MyAppState extends ChangeNotifier {
  bool isDarkMode = false;
  String? accessToken;
  List<Track>? tracks = [];
  Map<Track, double> recTracks = {};
  List<String> _tempLikedTracks = [];
  List<String> _deltracks= []; 
  Timer? _deleteTimer;
  int _trackCounter = 0;
  Recommendations recommendService = Recommendations.instance;
  Colikes colikeService = Colikes.instance;
  final Map<String, double> likedOrRated = {};
  final List<String> _likedOrRatedIDs = [];
  bool isHomeFeedLoading = false;
  String? homeFeedError;
  
  //track which tracks have been seen to avoid serving them again
  final Set<String> _seenTrackIds = <String>{};
  final Set<String> _seenTrackNameArtist = <String>{};
  
  String keyOf(Track t) => t.name;

  double ratingFor(Track t) => likedOrRated[keyOf(t)] ?? 0;

  var favorites = List<Track>.empty(growable: true);

  //Vinyl gradient color
  Color vinylColor = Colors.black;

  void setVinylColor(Color color) {
    if (vinylColor != color) {
      vinylColor = color;
      notifyListeners();
    }
  }

  void logout() {
    accessToken = null;
    vinylColor = Colors.black;
    SpotifyCache().clear();
    notifyListeners();
  }

  Future<void> loadUserRatings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('No user logged in, cannot load ratings');
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('ratings')
          .get();

      print('Loading ${snapshot.docs.length} ratings from Firestore');

      for (var doc in snapshot.docs) {
        final data = doc.data();
        _likedOrRatedIDs.add(doc.id);
        final trackName = data['name'] as String?;
        final rating = data['rating'] as double?;
        if (trackName != null) {
          likedOrRated[trackName] = rating ?? 0.0;
        }
      }
      
      notifyListeners();
      print('Finished loading ${likedOrRated.length} ratings');
    } catch (e) {
      print('Error loading user ratings: $e');
    }
  }

  Future<void> loadRecommendations() async {
    recTracks = await SpotifyService().fetchRecommendedSongs();
    print('loadRecommendations completed: ${recTracks.length} tracks loaded');
  }

  /// Fetch the feed that will back the generator page.
  ///
  /// This method ensures we have a valid access token (refreshing it if
  /// necessary), also guarantees that recommendations have been loaded so
  /// they can be mixed into the feed.  Once the call completes the
  /// `tracks` list and `current` track are updated and listeners are
  /// notified.
  Future<void> loadFeed({String? yearRange}) async {
    // grab token if we don't already have one
    if (accessToken == null) {
      try {
        accessToken = await SpotifyService().getAccessToken();
        print('Spotify token obtained in loadFeed');
      } catch (e) {
        homeFeedError = 'Unable to acquire Spotify token: $e';
        print(homeFeedError);
        notifyListeners();
        return;
      }
    }

    // ensure recommendations are fetched
    if (recTracks.isEmpty) {
      print('loadFeed: recTracks is empty, fetching recommendations...');
      await loadRecommendations();
      print('loadFeed: after loadRecommendations, recTracks has ${recTracks.length} items');
    }

    try {
      print('loadFeed: calling fetchSongs with ${recTracks.length} recommendation tracks');
      final newTracks = await SpotifyService().fetchSongs(
        accessToken!,
        recTracks,
        yearRange: yearRange,
        limit: 10,
      );

      tracks = newTracks;
      if (tracks != null && tracks!.isNotEmpty) {
        current = tracks![0];
        
        // track all returned tracks so we don't serve them again
        _seenTrackIds.clear();
        _seenTrackNameArtist.clear();
        for (final track in tracks!) {
          if (track.id != null && track.id!.isNotEmpty) {
            _seenTrackIds.add(track.id!);
          }
          _seenTrackNameArtist.add('${track.name}|${track.artists}'.toLowerCase());
        }
      }
      notifyListeners();
      print('Loaded ${tracks?.length ?? 0} feed tracks');
    } catch (e) {
      homeFeedError = 'Error fetching feed songs: $e';
      print(homeFeedError);
      notifyListeners();
    }
  }

  /// Fetch additional tracks and append them to the current feed.
  ///
  /// This is called when the user scrolls near the end to populate the
  /// rest of the feed with tracks they haven't seen. Uses the same
  /// recommendation/popular/random mix as loadFeed but excludes already
  /// loaded tracks.
  Future<void> loadMoreTracks({String? yearRange}) async {
    if (accessToken == null) {
      print('loadMoreTracks: no access token, skipping');
      return;
    }

    try {
      print('loadMoreTracks: fetching more tracks (excluding ${_seenTrackIds.length} seen)');
      final moreTracks = await SpotifyService().fetchSongs(
        accessToken!,
        recTracks,
        yearRange: yearRange,
        limit: 10,
        excludeIds: _seenTrackIds,
        excludeNameArtist: _seenTrackNameArtist,
      );

      if (moreTracks.isNotEmpty) {
        tracks!.addAll(moreTracks);
        
        // track these new tracks
        for (final track in moreTracks) {
          if (track.id != null && track.id!.isNotEmpty) {
            _seenTrackIds.add(track.id!);
          }
          _seenTrackNameArtist.add('${track.name}|${track.artists}'.toLowerCase());
        }
        
        notifyListeners();
        print('loadMoreTracks: added ${moreTracks.length} new tracks, total now ${tracks!.length}');
      } else {
        print('loadMoreTracks: no new tracks available');
      }
    } catch (e) {
      print('Error loading more tracks: $e');
    }
  }

  void setTrackCounter(int value){
    _trackCounter = value;
  }

  void markSongsForDeletion(String songID){
    _deltracks.add(songID);
    _deleteTimer?.cancel();
    _deleteTimer = Timer(const Duration(seconds: 2), () async {
      final todelete = List<String>.from(_deltracks);
      _deltracks.clear();
      await Recommendations.instance.removeRecommendationsFromSource(todelete);
    });
  }
  
  void printLikedOrRatedIDs(){
    print('Liked or rated IDs:');
    for (var id in _likedOrRatedIDs) {
      print(id);
    }
  }

  List<String> getLikedOrRatedIDs(){
    return _likedOrRatedIDs;
  }

  void setRating(Track t, double rating) {
    final r = rating.clamp(0.0, 5.0);
    final k = keyOf(t);

    if (r <= 0) {
      likedOrRated.remove(k);
      favorites.removeWhere((x) => keyOf(x) == k);
      _likedOrRatedIDs.remove(t.id!);
      _tempLikedTracks.remove(current!.id!);
      Recommendations.instance.removeOneSongFromSource(current!.id!);
      if (t.id != null) {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          GlobalRatings.instance.removeRating(
            trackId: t.id!,
            userId: userId,
          ).catchError((e) {
            print('Error removing global rating: $e');
          });
        }
      }
    } else {
      likedOrRated[k] = r;
      _likedOrRatedIDs.add(t.id!);
      _tempLikedTracks.add(current!.id!);
      if (!favorites.any((x) => keyOf(x) == k)) {
        favorites.add(t);
      }
      if (t.id != null) {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          GlobalRatings.instance.submitRating(
            trackId: t.id!,
            userId: userId,
            rating: r,
          ).catchError((e) {
            print('Error submitting global rating: $e');
          });
        }
      }
    }
    notifyListeners();
  }
  

  MyAppState({this.accessToken, this.tracks}) {
    // we keep this constructor for backwards compatibility, but the
    // startup fetch logic no longer passes any values in.  current is set
    // when loadFeed() completes later.
    if (tracks != null && tracks!.isNotEmpty) {
      current = tracks![0];
    } else {
      current = null;
    }
  }

  Track? current;

  void setCurrentTrack(Track track) {
    current = track;
    notifyListeners();
  }

  void getNext() {
    if (tracks != null && tracks!.isNotEmpty) {
      int currentIndex = tracks!.indexWhere((track) => track.name == current?.name);
      int nextIndex = (currentIndex + 1) % tracks!.length;
      current = tracks![nextIndex];
      setTrackCounter(nextIndex);
      //if approaching the end, load more tracks in the background
      if (nextIndex >= tracks!.length - 3) {
        print('getNext: near end of feed (index $nextIndex/${tracks!.length}), loading more...');
        loadMoreTracks(); //helper function to call fetchSongs and update feed dynamically
      }
      
      //generate new recommendation every 5 tracks
      //update co-liked tracks every 5 tracks
      //! UNCOMMENT TO ENABLE CO-LIKED UPDATES
      //! Warning: May cause slower performance due to batch writes
      if(_trackCounter % 5 == 0){
        print('Updating co-liked tracks...');
        _updateCoLiked(_tempLikedTracks, _likedOrRatedIDs);
        generateRecommendation();
        _tempLikedTracks.clear();
      }
    } else {
      current = null;
    }
    notifyListeners();
  }

  void getPrevious() {
    if (tracks != null && tracks!.isNotEmpty) {
      int currentIndex = tracks!.indexWhere((track) => track.name == current?.name);
      int nextIndex = (currentIndex - 1) % tracks!.length;
      current = tracks![nextIndex];
      setTrackCounter(nextIndex);
    } else {
      current = null;
    }
    notifyListeners();
  }

  // Keep backgroundColor for any legacy usages (e.g. SongInteractionPage)
  Color backgroundColor = Colors.white;

  void toggleFavorite() {
    if (current == null) return;
    final isFavNow = !favorites.any((t) => t.name == current!.name);
    if (isFavNow) {
      favorites.add(current!);
      likedOrRated[current!.name] = 0.0;
      _likedOrRatedIDs.add(current!.id!);
      _tempLikedTracks.add(current!.id!);
    } else {
      favorites.removeWhere((t) => t.name == current!.name);
      likedOrRated.remove(current!.name);
      _likedOrRatedIDs.remove(current!.id!);
      _tempLikedTracks.remove(current!.id!);
      Recommendations.instance.removeOneSongFromSource(current!.id!);
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
  
  void removeFavorite(String idToRemove) {
    favorites.removeWhere((fav) => fav.id == idToRemove);
    notifyListeners();
  }

  void removeFromLikedOrRated(String idToRemove) {
    _likedOrRatedIDs.remove(idToRemove);
    final index = favorites.indexWhere((fav) => fav.id == idToRemove);
    if (index != -1) {
      final trackToRemove = favorites[index];
      likedOrRated.remove(keyOf(trackToRemove));
      favorites.removeAt(index);
    }
    notifyListeners();
  }

  Future<void> generateRecommendation() async {
    if (current == null || accessToken == null) {
      print('No liked track available for recommendations.');
      return;
    }

    //run the recommendation algorithm (writes to Firestore)
    await recommendService.getRec(_tempLikedTracks, accessToken);

    //pull the updated recommendations back into memory
    await loadRecommendations();

    // f there is room in the current feed, fetch some new tracks now so
    //the user can immediately see the fresh recommendations
    if (tracks != null && tracks!.length < 5) {
      await loadMoreTracks();
    }

    // don't clear _tempLikedTracks here; it is managed elsewhere
    notifyListeners();
  }

  void changeBackground(Color color) {
    backgroundColor = color;
    notifyListeners();
  }

  Future<void> _updateCoLiked(List<String> tempLikedTracks, List<String> likedOrRatedIDs) async {
    final newTracks = List<String>.from(tempLikedTracks);
    if (newTracks.isEmpty) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    Set<String>? existingPairIds;
    if (userId != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('co_liked')
            .get();
        existingPairIds = snap.docs.map((d) => d.id).toSet();
      } catch (e) {
        print('Error fetching existing user co_likes: $e');
      }
    }

    print('Updating co-liked for ${newTracks.length} new songs');
    await colikeService.updateCoLikedBatch(
      newSongIds: List.from(newTracks),
      existingLikedSongs: likedOrRatedIDs,
      existingPairIds: existingPairIds,
    );
  }

  void toggleDarkMode(bool enabled) {
    isDarkMode = enabled;
    notifyListeners();
  }

  Future<void> initializeHomeFeed({String? yearRange}) async {
    isHomeFeedLoading = true;
    homeFeedError = null;
    notifyListeners();

    try {
      await loadUserRatings();
      await loadRecommendations();
      await loadFeed(yearRange: yearRange);

      if (current == null) {
        homeFeedError = 'No tracks returned.';
      }
    } catch (e) {
      homeFeedError = 'Failed to load tracks: $e';
    } finally {
      isHomeFeedLoading = false;
      notifyListeners();
    }
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int selectedIndex = 0;

  static const List<String> topPageTitle = [
    'Playlist\'d',
    'My Songs',
    'Song Search',
    'Friends',
    'Collections',
    'Profile',
  ];

  // @override
  // void initState() {
  //   super.initState();
  //   //Load user's previous ratings and build the feed once they're signed
  //   //in. We fetch recommendations first, then ask SpotifyService for a
  //   //batch of songs using the new `fetchSongs` helper.
  //   WidgetsBinding.instance.addPostFrameCallback((_) async {
  //     final appState = context.read<MyAppState>();
  //     await appState.loadUserRatings();
  //     await appState.loadRecommendations();
  //     await appState.loadFeed();
  //   });
  // }
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<MyAppState>().initializeHomeFeed();
    });
  }

  //this helper is no longer needed, we now use loadFeed() on the
  //app state which wraps token acquisition and calls fetchSongs.

  final pages = [
    GeneratorPage(),
    MySongsPage(),
    SearchPage(),
    FriendsPage(),
    CollectionsPage(),
    //RecommendationsPage(), // switches to the favorites page class
    ProfilePage(uid: FirebaseAuth.instance.currentUser!.uid),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final isDark = appState.isDarkMode;
    final vinyl = appState.vinylColor;

    // Build gradient colors based on vinyl color + theme
    final gradientTop = isDark
        ? Color.alphaBlend(vinyl.withOpacity(0.40), const Color(0xFF0A1628))
        : Color.alphaBlend(vinyl.withOpacity(0.50), Colors.white);
    final gradientBottom = isDark
        ? const Color(0xFF0A1628)
        : Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _openSettings(context),
            ),
            centerTitle: true,
            title: Text(
              topPageTitle[selectedIndex],
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          //Vinyl gradient 
          body: selectedIndex == 0
              ? AnimatedContainer(
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [gradientTop, gradientBottom],
                    ),
                  ),
                  // Show loading page if we're still fetching the feed, otherwise show the generator
                  child: (appState.isHomeFeedLoading || appState.current == null)
                      ? LoadingVinylPage(
                          labelText: 'Loading tracks...',
                          ringText: ' LOADING YOUR FEED ',
                          errorText: appState.homeFeedError,
                          onRetry: () => context.read<MyAppState>().initializeHomeFeed(),
                        )
                      : pages[selectedIndex],
                )
              : pages[selectedIndex],
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: NavigationBar(
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.library_music), label: 'Songs'),
                NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Search'),
                NavigationDestination(icon: Icon(Icons.people), label: 'Friends'),
                NavigationDestination(icon: Icon(Icons.library_music_outlined), label: 'Collections'),
                NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
              ],
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                setState(() => selectedIndex = index);
              },
            ),
          ),
        );
      },
    );
  }
}

class GeneratorPage extends StatelessWidget {
  final bool showScrollButtons;
  final bool centerVertically;

  const GeneratorPage({super.key, this.showScrollButtons = true, this.centerVertically = false});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    Track? track = appState.current;

    final isLiked = track != null && appState.favorites.any((t) => t.name == track.name);

    return SafeArea(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -250) {
            appState.getNext();
          } else if (velocity > 250) {
            appState.getPrevious();
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: Align(
                alignment: centerVertically ? Alignment.center : Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (track != null) ...[
                      FutureBuilder<Map<String, dynamic>>(
                        future: track.id != null 
                          ? GlobalRatings.instance.getAverageRating(track.id!)
                          : Future.value({'averageRating': 0.0, 'totalRatings': 0}),
                        builder: (context, snapshot) {
                          final globalRating = snapshot.hasData 
                            ? (snapshot.data!['averageRating'] as num?)?.toDouble() ?? 0.0
                            : 0.0;
                          
                          return BigCard(
                            track: track,
                            globalRating: globalRating,
                            userRating: appState.ratingFor(track),
                          );
                        },
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StarRating(
                            rating: appState.ratingFor(track),
                            onChanged: (r) async {
                              appState.setRating(track, r);
                              await Favorites.instance.setRating(
                                trackId: track.id!,
                                name: track.name,
                                artists: track.artists,
                                albumImageUrl: track.albumImageUrl,
                                rating: r,
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF1DB954),
                            child: IconButton(
                              icon: const Icon(Icons.open_in_new, color: Colors.white),
                              onPressed: () async {
                                final uri = Uri.parse(track.url!);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                } else {
                                  print('Could not launch ${track.url}');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else
                      const SizedBox.shrink(),

                    const SizedBox(height: 10),

                    if (track != null && track.id != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showReviewDialog(context, track),
                            icon: const Icon(Icons.rate_review),
                            label: const Text('Write Review'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () => _showAllReviewsDialog(context, track),
                            icon: const Icon(Icons.reviews),
                            label: const Text('Reviews'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showScrollButtons) ...[
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton(
                              onPressed: () => appState.getPrevious(),
                              child: const Text('Back'),
                            ),
                          ),
                        ],
                        LikeButton(
                          track: track,
                          isLiked: isLiked,
                          onToggle: appState.toggleFavorite,
                        ),
                        if (showScrollButtons) ...[
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => appState.getNext(),
                            child: const Text('Next'),
                          ),
                        ],
                      ],
                    ),

                    if (track != null && track.id != null) ...[
                      const SizedBox(height: 10),
                      GlobalRatingDisplay(trackId: track.id!),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            );
          },
        ),
      ),
    );
  }
}

class LikeButton extends StatefulWidget {
  final Track? track;
  final bool isLiked;
  final VoidCallback onToggle;

  const LikeButton({
    super.key,
    required this.track,
    required this.isLiked,
    required this.onToggle,
  });

  @override
  State<LikeButton> createState() => LikeButtonState();
}

class LikeButtonState extends State<LikeButton> {
  bool hovering = false;

  @override
  void didUpdateWidget(covariant LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.track?.id != oldWidget.track?.id) {
      hovering = false;
    }
  }

  IconData iconState() {
    if (widget.isLiked) {
      return hovering ? Icons.heart_broken : Icons.favorite;
    }
    return Icons.favorite_border;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: ElevatedButton.icon(
        onPressed: widget.track != null ? widget.onToggle : null,
        icon: Icon(iconState()),
        label: Text(widget.isLiked ? 'Liked' : 'Like'),
      ),
    );
  }
}

void _showReviewDialog(BuildContext context, Track track) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return;

  String existingReview = '';
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('ratings')
        .doc(track.id)
        .get();
    if (doc.exists && doc.data() != null) {
      existingReview = doc.data()!['review'] ?? '';
    }
  } catch (e) {
    print('Error loading existing review: $e');
  }

  final TextEditingController reviewController = TextEditingController(text: existingReview);
  showDialog(
    context: context,
    builder: (context) => ReviewDialog(track: track, reviewController: reviewController),
  );
}

void _showAllReviewsDialog(BuildContext context, Track track) async {
  print('Checking for reviews for trackId: ${track.id}');
  try {
    final testQuery = await FirebaseFirestore.instance
        .collection('song_reviews')
        .where('trackId', isEqualTo: track.id)
        .get();
    print('Found ${testQuery.docs.length} reviews');
  } catch (e) {
    print('Error testing query: $e');
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Reviews'),
          const SizedBox(height: 4),
          Text(track.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text('by ${track.artists}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('song_reviews')
              .where('trackId', isEqualTo: track.id)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Error loading reviews'),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', style: const TextStyle(fontSize: 10)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            }

            final reviews = snapshot.data?.docs ?? [];
            print('Loaded ${reviews.length} reviews');

            if (reviews.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.reviews_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No reviews yet', style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 8),
                    Text('Be the first to review!', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            }

            reviews.sort((a, b) {
              final aTime = (a.data() as Map<String, dynamic>)['updatedAt'] as Timestamp?;
              final bTime = (b.data() as Map<String, dynamic>)['updatedAt'] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

            return ListView.builder(
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final reviewData = reviews[index].data() as Map<String, dynamic>;
                final review = reviewData['review'] as String? ?? '';
                final rating = reviewData['rating'] as double?;
                final timestamp = reviewData['updatedAt'] as Timestamp?;
                final username = reviewData['username'] as String? ?? 'Anonymous';

                String timeAgo = 'Recently';
                if (timestamp != null) {
                  final date = timestamp.toDate();
                  final now = DateTime.now();
                  final difference = now.difference(date);
                  if (difference.inDays > 30) {
                    timeAgo = '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
                  } else if (difference.inDays > 0) {
                    timeAgo = '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
                  } else if (difference.inHours > 0) {
                    timeAgo = '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
                  } else if (difference.inMinutes > 0) {
                    timeAgo = '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
                  } else {
                    timeAgo = 'Just now';
                  }
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: Text(
                                username.isNotEmpty ? username[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    username.length > 20 ? '${username.substring(0, 20)}...' : username,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  Text(timeAgo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                            if (rating != null && rating > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 16),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(review, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class ReviewDialog extends StatefulWidget {
  final Track track;
  final TextEditingController reviewController;

  const ReviewDialog({super.key, required this.track, required this.reviewController});

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  static const int maxCharacters = 300;
  String? reviewExplicitCheck;

  @override
  void initState() {
    super.initState();
    widget.reviewController.addListener(() {
      setState(() => reviewExplicitCheck = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final remainingChars = maxCharacters - widget.reviewController.text.length;
    return AlertDialog(
      title: const Text('Write a Review'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.track.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('by ${widget.track.artists}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          TextField(
            controller: widget.reviewController,
            maxLength: maxCharacters,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Share your thoughts about this song...',
              border: const OutlineInputBorder(),
              counterText: '$remainingChars characters remaining',
            ),
          ),
          if (reviewExplicitCheck != null) ...[
            const SizedBox(height: 8),
            Text(reviewExplicitCheck!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.reviewController.text.isNotEmpty)
          TextButton(
            onPressed: () async {
              await Favorites.instance.setReview(
                trackId: widget.track.id!,
                name: widget.track.name,
                artists: widget.track.artists,
                albumImageUrl: widget.track.albumImageUrl,
                review: '',
              );
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Review deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ElevatedButton(
          onPressed: () async {
            final review = widget.reviewController.text.trim();
            if (review.isEmpty) {
              Navigator.of(context).pop();
              return;
            }
            if (ExplicitContentFilter.containsExplicitContent(review)) {
              setState(() {
                reviewExplicitCheck = 'Please remove explicit language from your review.';
              });
              return;
            }
            await Favorites.instance.setReview(
              trackId: widget.track.id!,
              name: widget.track.name,
              artists: widget.track.artists,
              albumImageUrl: widget.track.albumImageUrl,
              review: review,
            );
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Review saved!')),
            );
          },
          child: const Text('Save Review'),
        ),
      ],
    );
  }
}

class BigCard extends StatefulWidget {
  const BigCard({super.key, required this.track, this.globalRating = 0.0, this.userRating = 0.0});

  final Track track;
  final double globalRating;
  final double userRating;

  @override
  State<BigCard> createState() => _BigCardState();
}

class _BigCardState extends State<BigCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  Track? _previousTrack;
  Color _currentVinylColor = Colors.black;
  double _previousRating = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 103.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _previousTrack = widget.track;
    _previousRating = widget.globalRating;
    _currentVinylColor = _getVinylColor(_effectiveRating());
    _animationController.forward();

    // Push initial vinyl color to app state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MyAppState>().setVinylColor(_currentVinylColor);
      }
    });
  }

  @override
  void didUpdateWidget(BigCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.track.id != widget.track.id) {
      _previousTrack = oldWidget.track;
      _previousRating = oldWidget.globalRating;
      setState(() {
        _currentVinylColor = _getVinylColor(_effectiveRating());
      });
      _animationController.reset();
      _animationController.forward();

      // Notify app state of new vinyl color
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<MyAppState>().setVinylColor(_currentVinylColor);
        }
      });
    } else if (oldWidget.globalRating != widget.globalRating || oldWidget.userRating != widget.userRating) {
      setState(() {
        _currentVinylColor = _getVinylColor(_effectiveRating());
      });
      // Notify app state when rating changes color
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<MyAppState>().setVinylColor(_currentVinylColor);
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  double _effectiveRating() {
    // Combine global and user rating for vinyl color
    if (widget.userRating > 0) {
      return widget.userRating;
    }
    return widget.globalRating;
  }

  Color _getVinylColor(double rating) {
    if (rating >= 4.8) {
      return const Color.fromARGB(255, 167, 228, 227); // Platinum
    } else if (rating >= 4.0) {
      return const Color.fromARGB(255, 207, 205, 51);  // Gold
    } else if (rating >= 3.0) {
      return const Color.fromARGB(255, 154, 168, 168); // Silver
    } else if (rating >= 2.0) {
      return const Color.fromARGB(255, 168, 125, 39);  // Bronze
    } else {
      return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleLarge!.copyWith(color: theme.colorScheme.primary);
    final artistStyle = theme.textTheme.titleMedium!.copyWith(
      color: theme.colorScheme.primary.withOpacity(0.8),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.track.albumImageUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 1.0),
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Vinyl record
                    Transform.translate(
                      offset: Offset(_slideAnimation.value, 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentVinylColor,
                          boxShadow: [
                            BoxShadow(
                              color: _currentVinylColor.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            for (int i = 1; i <= 6; i++)
                              Container(
                                width: 180 - (i * 30.0),
                                height: 180 - (i * 30.0),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color.fromARGB(255, 245, 244, 244).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                              ),
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary,
                              ),
                              child: Icon(Icons.album, color: theme.colorScheme.onPrimary, size: 40),
                            ),
                            Container(
                              width: 15,
                              height: 15,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 200, height: 200, decoration: const BoxDecoration(color: Colors.grey)),
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(5, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4.0),
                        child: Image.network(
                          widget.track.albumImageUrl!,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 300,
                            height: 300,
                            color: Colors.grey,
                            child: const Icon(Icons.album, size: 100, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
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
                  widget.track.name,
                  style: style.copyWith(color: theme.colorScheme.onPrimary),
                  textAlign: TextAlign.center,
                  semanticsLabel: widget.track.name,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.track.artists,
                  style: artistStyle.copyWith(color: theme.colorScheme.onPrimary.withOpacity(0.8)),
                  textAlign: TextAlign.center,
                  semanticsLabel: "by ${widget.track.artists}",
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class GlobalRatingDisplay extends StatelessWidget {
  final String trackId;
  const GlobalRatingDisplay({super.key, required this.trackId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: GlobalRatings.instance.watchAverageRating(trackId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: [
              Text(
                'Global Avg',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          );
        }

        final data = snapshot.data ?? {'averageRating': 0.0, 'totalRatings': 0};
        final averageRating = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
        final totalRatings = data['totalRatings'] as int;

        return Column(
          children: [
            Text(
              'Global Avg',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) {
                    final starValue = index + 1;
                    IconData icon;
                    if (averageRating >= starValue) {
                      icon = Icons.star;
                    } else if (averageRating >= starValue - 0.5) {
                      icon = Icons.star_half;
                    } else {
                      icon = Icons.star_border;
                    }
                    return Icon(icon, size: 24, color: Colors.amber);
                  }),
                ),
                const SizedBox(width: 8),
                Text(
                  '${averageRating.toStringAsFixed(1)} ($totalRatings)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

void _openSettings(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 170,
          height: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                child: const Text('Logout'),
                onPressed: () async {
                  context.read<MyAppState>().logout();
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pop();
                },
              ),
              const ToggleButtonManager(),
            ],
          ),
        ),
      );
    },
  );
}

class StarRating extends StatelessWidget {
  final double rating;
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