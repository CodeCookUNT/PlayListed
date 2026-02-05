import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Colikes {
  Colikes._();
  static final Colikes instance = Colikes._();


  // Reference to this user's coliked tracks collection
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('co_liked');


  /// Remove a track from coliked tracks
  Future<void> removeColikedTrack({
    required String pairId,
  }) async {
    await _col.doc(pairId).delete();
  }

  ///Stream of coliked tracks for real-time updates
  Stream<List<Map<String, dynamic>>> colikedTracksStream() {
    return _col.orderBy('colikedAt', descending: true).snapshots().map(
      (snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList(),
    );
  }

  //generate consistent pair ID for two songs (would be the two song IDs concatenated in alphabetical order)
  String generatePairId(String song1, String song2) {
  if (song1.compareTo(song2) < 0) {
    return '${song1}__$song2';
  } else {
    return '${song2}__$song1';
  }
}

//retrieve co-liked songs for a given song
Future<List<QueryDocumentSnapshot>> getCoLikedSongs(
    String songId,
) async {
  final firestore = FirebaseFirestore.instance;

  final q1 = await firestore
      .collection('co_liked')
      .where('songA', isEqualTo: songId)
      .orderBy('count', descending: true)
      .limit(25)
      .get();

  final q2 = await firestore
      .collection('co_liked')
      .where('songB', isEqualTo: songId)
      .orderBy('count', descending: true)
      .limit(25)
      .get();

  return [...q1.docs, ...q2.docs];
}


//extract the "other" song from a pair
String extractOtherSong(String songId, Map<String, dynamic> data) {
  return data['songA'] == songId
      ? data['songB']
      : data['songA'];
}

// Future<bool> hasUserColiked({
//   required String pairId, required String userId
// }) async {
//   try{
//   final docRef = FirebaseFirestore.instance
//       .collection('users')
//       .doc(userId)
//       .collection('co_liked')
//       .doc(pairId);

//   final snapshot = await docRef.get();
//   return snapshot.exists;
//   } catch(e){
//     print("Error $e");
//     return false;
//   }
// }

//Optimized batch update: accept multiple newSongIds or a single one,
//and a pre-fetched set of existing pair IDs to avoid per-pair queries.
Future<void> updateCoLikedBatch({
  required List<String> newSongIds,
  required List<String> existingLikedSongs,
  Set<String>? existingPairIds,
}) async {
  final firestore = FirebaseFirestore.instance;
  final userId = FirebaseAuth.instance.currentUser!.uid;
  final batch = firestore.batch();

  //if existingPairIds not provided, fetch them once.
  Set<String> userPairIdSet = existingPairIds ?? <String>{};
  if (existingPairIds == null) {
    final userColikesSnap = await firestore
        .collection('users')
        .doc(userId)
        .collection('co_liked')
        .get();
    userPairIdSet = userColikesSnap.docs.map((d) => d.id).toSet();
  }

  for (final newSongId in newSongIds) {
    for (final existingSong in existingLikedSongs) {
      if (existingSong == newSongId) continue;

      final pairId = generatePairId(newSongId, existingSong);
      final pairRef = firestore.collection('co_liked').doc(pairId);
      final userPairRef = firestore
          .collection('users')
          .doc(userId)
          .collection('co_liked')
          .doc(pairId);

      //only create userPair doc if user hasn't coliked this pair yet.
      if (!userPairIdSet.contains(pairId)) {
        batch.set(userPairRef, {'colikedAt': FieldValue.serverTimestamp()});
        //mark locally to avoid duplicate set within same batch
        userPairIdSet.add(pairId);
      }

      batch.set(
        pairRef,
        {
          'songA': pairId.split('__')[0],
          'songB': pairId.split('__')[1],
          'count': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  try {
    await batch.commit();
  } catch (e) {
    print('Error in updateCoLikedBatch: $e');
  }
}

}
