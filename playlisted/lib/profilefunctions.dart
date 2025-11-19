import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile.dart';
import 'main.dart' show MyAppState;

class ProfileFunctions {
  ProfileFunctions._();
  static final ProfileFunctions instance = ProfileFunctions._();

  // Get current user's UID
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // Get current user's email
  String? get userEmail => FirebaseAuth.instance.currentUser?.email;

  // Get first letter of email for profile picture
  String get profileInitial {
    final email = userEmail;
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }

  // Stream user's ratings for real-time updates
  Stream<QuerySnapshot> ratingsStream() {
    if (_uid == null) {
      return Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('ratings')
        .snapshots();
  }

  // Calculate total number of reviews (ratings > 0)
  int calculateTotalReviews(QuerySnapshot snapshot) {
    int total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      //final rating = data['rating'] as double?; causes bug
      final rating = (data['rating'] as num?)?.toDouble();
      if (rating != null && rating > 0) {
        total++;
      }
    }
    return total;
  }

  // Calculate average rating across all rated songs
  double calculateAverageRating(QuerySnapshot snapshot) {
    int count = 0;
    double sum = 0.0;

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      //final rating = data['rating'] as double?; causes bug I think
      final rating = (data['rating'] as num?)?.toDouble();
      if (rating != null && rating > 0) {
        count++;
        sum += rating;
      }
    }

    return count > 0 ? sum / count : 0.0;
  }

  // Get user's favorite songs (5 star ratings)
  List<Map<String, dynamic>> getFavoriteSongs(QuerySnapshot snapshot) {
    List<Map<String, dynamic>> favorites = [];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      //final rating = data['rating'] as double?; cause sbug
      final rating = (data['rating'] as num?)?.toDouble();
      
      // Only include songs with 5 star rating
      if (rating != null && rating == 5.0) {
        favorites.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'artists': data['artists'] ?? 'Unknown Artist',
          'albumImageUrl': data['albumImageUrl'],
          'rating': rating,
        });
      }
    }

    return favorites;
  }

  // Get user statistics as a map
  Map<String, dynamic> getUserStats(QuerySnapshot snapshot) {
    int totalReviews = calculateTotalReviews(snapshot);
    double averageRating = calculateAverageRating(snapshot);
    List<Map<String, dynamic>> favoriteSongs = getFavoriteSongs(snapshot);

    return {
      'totalReviews': totalReviews,
      'averageRating': averageRating,
      'favoriteSongs': favoriteSongs,
    };
  }
}