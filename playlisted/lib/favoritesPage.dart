import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'favorites.dart';
import 'main.dart' show StarRating;

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Favorites.instance.favoritesStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Spinning vinyl
                SizedBox(
                  width: 200,
                  height: 200,
                  child: TweenAnimationBuilder(
                    duration: const Duration(seconds: 2),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.linear,
                    builder: (context, value, child) {
                      return Transform.rotate(
                        angle: value * 6.28319, // 2 * pi for full rotation
                        child: child,
                      );
                    },
                    child: Container(
                      width: 200,
                      height: 200,
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
                              width: 200 - (i * 20.0),
                              height: 200 - (i * 20.0),
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
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary,
                            ),
                            child: Icon(
                              Icons.album,
                              color: theme.colorScheme.onPrimary,
                              size: 30,
                            ),
                          ),
                          // Center hole
                          Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Loading favorites...',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        final items = snap.data ?? [];
        
        // Sort by updatedAt - most recent first
        items.sort((a, b) {
          final aUpdated = a['updatedAt'] as Timestamp?;
          final bUpdated = b['updatedAt'] as Timestamp?;
          
          if (aUpdated == null && bUpdated == null) return 0;
          if (aUpdated == null) return 1;
          if (bUpdated == null) return -1;
          
          return bUpdated.compareTo(aUpdated);
        });

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
                      rating: (doc['rating'] ?? 0).toDouble(),
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