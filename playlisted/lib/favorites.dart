import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'recommendations.dart';
import 'main.dart' show MyAppState;

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
  }

  /// Set or update a text review for a track
  Future<void> setReview({
    required String trackId,
    required String name,
    required String artists,
    String? albumImageUrl,
    required String review,
  }) async {
    await _col.doc(trackId).set({
      'name': name,
      'artists': artists,
      'albumImageUrl': albumImageUrl,
      'review': review,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get review for a specific track
  Future<String?> getReview(String trackId) async {
    try {
      final doc = await _col.doc(trackId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['review'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting review: $e');
      return null;
    }
  }

  // Delete the song from the database
  Future<void> deleteTrack({required String trackId}) async {
    await _col.doc(trackId).delete();
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