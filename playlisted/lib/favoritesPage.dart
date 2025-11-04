import 'package:flutter/material.dart';
import 'favorites.dart';
import 'main.dart' show StarRating;

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Favorites.instance.favoritesStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No favorites yet.'));
        }

        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('You have ${items.length} favorites:'),
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

                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StarRating(
                      rating: (doc['rating'] ?? 0) as int,
                      onChanged: (r) => Favorites.instance.setRating(
                        trackId: doc['id'],
                        name: doc['name'],
                        artists: doc['artists'],
                        albumImageUrl: doc['albumImageUrl'],
                        rating: r,
                      ),
                      size: 20,
                      spacing: 2,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () async {
                        try {
                          await Favorites.instance.deleteTrack(
                            trackId: doc['id'],
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Deleted "${doc['name']}" from Firestore'),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Error deleting favorite: $e')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
