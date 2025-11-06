import 'recommendations.dart';
import 'package:flutter/material.dart';
import 'main.dart' show MyAppState;
import 'package:provider/provider.dart';
import 'spotify.dart' show Track;
import 'favorites.dart';

class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({Key? key}) : super(key: key);

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  bool _hasGenerated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    //only trigger once when the page is first opened
    if (!_hasGenerated) {
      _hasGenerated = true;

      //access appState
      final appState = Provider.of<MyAppState>(context, listen: false);

      //generate recommendations
      appState.generateRecommendations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Recommendations.instance.recommendedStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No recommendations yet.'));
        }

        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('You have ${items.length} recommendations:'),
            ),

            for (final doc in items)
              ListTile(
                leading: (doc['albumImageUrl'] as String?) != null
                    ? Image.network(
                        doc['albumImageUrl'],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.favorite),
                      )
                    : const Icon(Icons.favorite),
                title: Text(doc['name'] ?? ''),
                subtitle: Text(doc['artists'] ?? ''),
              ),
          ],
        );
      },
    );
  }
}