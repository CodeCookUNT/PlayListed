import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Favorites {
  Favorites._();
  static final Favorites instance = Favorites._();

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('ratings');

  /// Set a 0-5 rating.
  Future<void> setRating({
    required String trackId,
    required String name,
    required String artists,
    String? albumImageUrl,
    required int rating,
  }) async {
    final safe = rating.clamp(0, 5);
    await _col.doc(trackId).set({
      'name': name,
      'artists': artists,
      'albumImageUrl': albumImageUrl,
      'rating': safe,
      'favorite': safe > 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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