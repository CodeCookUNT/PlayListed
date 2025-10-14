import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Playlistd',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 21, 131, 183)),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
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
    RecommendationsPage(), // switchs to the favorites page class
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
