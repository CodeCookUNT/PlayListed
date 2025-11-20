import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Favorites {
  Favorites._();
  static final Favorites instance = Favorites._();


  // Current user's UID
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // Reference to this user's ratings collection
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('ratings');

  /// Set a 0–5 rating (can include halves, e.g., 3.5).
  Future<void> setRating({
    required String trackId,
    required String name,
    required String artists,
    String? albumImageUrl,
    double? rating,
  }) async {
    final double? safe = rating?.clamp(0.0, 5.0);
    await _col.doc(trackId).set({
      'name': name,
      'artists': artists,
      'albumImageUrl': albumImageUrl,
      'rating': safe,
      'favorite': safe != null && safe > 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    // Update rating in song_reviews if a review exists
    try {
      final reviewDoc = await FirebaseFirestore.instance
          .collection('song_reviews')
          .doc('${trackId}_$_uid')
          .get();
      
      if (reviewDoc.exists) {
        await FirebaseFirestore.instance
            .collection('song_reviews')
            .doc('${trackId}_$_uid')
            .update({'rating': safe});
        print('Updated rating in existing review');
      }
    } catch (e) {
      print('Error updating rating in song_reviews: $e');
    }
  }

  /// Set or update a text review for a track
  Future<void> setReview({
    required String trackId,
    required String name,
    required String artists,
    String? albumImageUrl,
    required String review,
  }) async {
    print('setReview called for trackId: $trackId, review: "$review"');
    
    // Save to user's personal ratings
    await _col.doc(trackId).set({
      'name': name,
      'artists': artists,
      'albumImageUrl': albumImageUrl,
      'review': review,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    print('Saved to user ratings collection');

    // Also save to global reviews collection for easy querying
    if (review.trim().isNotEmpty) {
      final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Anonymous';
      final docId = '${trackId}_$_uid';
      print('Saving to song_reviews collection with docId: $docId');
      
      try {
        await FirebaseFirestore.instance
            .collection('song_reviews')
            .doc(docId)
            .set({
          'trackId': trackId,
          'trackName': name,
          'artists': artists,
          'albumImageUrl': albumImageUrl,
          'review': review,
          'userId': _uid,
          'userEmail': userEmail,
          'rating': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Successfully saved to song_reviews collection');
        
        // Update with rating if exists
        final ratingDoc = await _col.doc(trackId).get();
        if (ratingDoc.exists && ratingDoc.data() != null) {
          final rating = ratingDoc.data()!['rating'] as double?;
          if (rating != null) {
            await FirebaseFirestore.instance
                .collection('song_reviews')
                .doc(docId)
                .update({'rating': rating});
            print('Updated rating in song_reviews: $rating');
          }
        }
      } catch (e) {
        print('Error saving to song_reviews: $e');
        rethrow;
      }
    } else {
      // Delete from global reviews if review is empty
      final docId = '${trackId}_$_uid';
      print('Deleting from song_reviews: $docId');
      try {
        await FirebaseFirestore.instance
            .collection('song_reviews')
            .doc(docId)
            .delete();
        print('Successfully deleted from song_reviews');
      } catch (e) {
        print('Error deleting from song_reviews: $e');
      }
    }
  }

  // Delete the song from the database
  Future<void> deleteTrack({required String trackId}) async {
    await _col.doc(trackId).delete();
    // Also delete from global reviews
    // try {
    //   await FirebaseFirestore.instance
    //       .collection('song_reviews')
    //       .doc('${trackId}_$_uid')
    //       .delete();
    // } catch (_) { //ignore missing doc
    // }
  }

  /// Toggle favorite flag (true/false).
  Future<void> setFavorite({
    required String trackId,
    required String name,
    required String artists,
    String? albumImageUrl,
    required bool favorite,
  }) async {
    await _col.doc(trackId).set({
      'name': name,
      'artists': artists,
      'albumImageUrl': albumImageUrl,
      'favorite': favorite,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }


  /// streams favorited tracks for the current user.
  Stream<List<Map<String, dynamic>>> favoritesStream() {
    return _col.where('favorite', isEqualTo: true).snapshots().map(
      (snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList(),
    );
  }

  /// Stream rated tracks (rating > 0)
  Stream<List<Map<String, dynamic>>> ratedStream() {
    return _col.where('rating', isGreaterThan: 0).snapshots().map(
      (snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList(),
    );
  }
}