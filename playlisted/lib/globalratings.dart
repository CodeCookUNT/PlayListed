import 'package:cloud_firestore/cloud_firestore.dart';

class GlobalRatings {
  static final GlobalRatings instance = GlobalRatings._internal();
  GlobalRatings._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> submitRating({
    required String trackId,
    required String userId,
    required double rating,
  }) async {
    try {
      //stores user rating
      await _db
          .collection('ratings')
          .doc(trackId)
          .collection('user_ratings')
          .doc(userId)
          .set({
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
      });

      //update rating data
      await _updateAggregateRating(trackId);
    } catch (e) {
      print('Error submitting rating: $e');
      rethrow;
    }
  }

  //removes rating 
  Future<void> removeRating({
    required String trackId,
    required String userId,
  }) async {
    try {
      await _db
          .collection('ratings')
          .doc(trackId)
          .collection('user_ratings')
          .doc(userId)
          .delete();

      await _updateAggregateRating(trackId);
    } catch (e) {
      print('Error removing rating: $e');
      rethrow;
    }
  }

  //updates global rating
  Future<void> _updateAggregateRating(String trackId) async {
    try {
      final userRatingsSnapshot = await _db
          .collection('ratings')
          .doc(trackId)
          .collection('user_ratings')
          .get();

      if (userRatingsSnapshot.docs.isEmpty) {
        // No ratings, remove or zero out the aggregate
        await _db.collection('ratings').doc(trackId).set({
          'averageRating': 0.0,
          'totalRatings': 0,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        return;
      }

      double sum = 0;
      int count = 0;

      for (var doc in userRatingsSnapshot.docs) {
        final rating = doc.data()['rating'] as double?;
        if (rating != null) {
          sum += rating;
          count++;
        }
      }

      final average = count > 0 ? sum / count : 0.0;

      await _db.collection('ratings').doc(trackId).set({
        'averageRating': average,
        'totalRatings': count,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating aggregate rating: $e');
      rethrow;
    }
  }

  // Get the global average rating for a track
  Future<Map<String, dynamic>> getAverageRating(String trackId) async {
    try {
      final doc = await _db.collection('ratings').doc(trackId).get();

      if (!doc.exists || doc.data() == null) {
        return {
          'averageRating': 0.0,
          'totalRatings': 0,
        };
      }

      final data = doc.data()!;
      return {
        'averageRating': data['averageRating'] ?? 0.0,
        'totalRatings': data['totalRatings'] ?? 0,
      };
    } catch (e) {
      print('Error getting average rating: $e');
      return {
        'averageRating': 0.0,
        'totalRatings': 0,
      };
    }
  }

  //checks average rating to change when song rating changes
  Stream<Map<String, dynamic>> watchAverageRating(String trackId) {
    return _db
        .collection('ratings')
        .doc(trackId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return {
          'averageRating': 0.0,
          'totalRatings': 0,
        };
      }

      final data = snapshot.data()!;
      return {
        'averageRating': data['averageRating'] ?? 0.0,
        'totalRatings': data['totalRatings'] ?? 0,
      };
    });
  }

  //gets the users song rating
  Future<double?> getUserRating({
    required String trackId,
    required String userId,
  }) async {
    try {
      final doc = await _db
          .collection('ratings')
          .doc(trackId)
          .collection('user_ratings')
          .doc(userId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return doc.data()!['rating'] as double?;
    } catch (e) {
      print('Error getting user rating: $e');
      return null;
    }
  }
}