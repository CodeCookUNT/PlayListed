import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileFunctions {
  ProfileFunctions._();
  static final ProfileFunctions instance = ProfileFunctions._();

  // Get current user's UID
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // Get useremail and username
  String? get userEmail => FirebaseAuth.instance.currentUser?.email;
  String? get username => FirebaseAuth.instance.currentUser?.displayName;

  // Get first letter for profile picture
  String get profileInitial {
    final name = username ?? userEmail;
    if (name != null && name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return '?';
  }

  // Stream user's ratings for real-time updates
  Stream<QuerySnapshot> ratingsStream({String? uid}) {
    final targetUid = uid ?? _uid;
    if (targetUid == null || targetUid.isEmpty) return Stream.empty();
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .collection('ratings')
        .snapshots();
  }

  //get text reviews function for the your reviews section on the profile page
  List<Map<String, dynamic>> getTextReviews(QuerySnapshot snapshot) {
    List<Map<String, dynamic>> textReviews = [];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final rating = (data['rating'] as num?)?.toDouble();
      final reviewText = (data['review'] as String?)?.trim();

      // include only docs that have a non-empty text review
      if (reviewText != null && reviewText.isNotEmpty) {
        textReviews.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'artists': data['artists'] ?? 'Unknown Artist',
          'albumImageUrl': data['albumImageUrl'],
          'rating': rating ?? 0.0,
          'review': reviewText,
          'timestamp': data['timestamp'] ?? Timestamp(0, 0),
        });
      }
    }
    return textReviews;
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
