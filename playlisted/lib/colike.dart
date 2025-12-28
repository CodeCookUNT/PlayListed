import 'package:cloud_firestore/cloud_firestore.dart';

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

  //update co-liked counts when a new song is liked
Future<void> updateCoLiked({
  required String newSongId,
  required List<String> existingLikedSongs,
}) async {
  final firestore = FirebaseFirestore.instance;
  final batch = firestore.batch();

  for (final existingSong in existingLikedSongs) {
    if (existingSong == newSongId) continue;

    final pairId = generatePairId(newSongId, existingSong);
    final docRef = firestore.collection('co_liked').doc(pairId);

    batch.set(
      docRef,
      {
        'songA': pairId.split('__')[0],
        'songB': pairId.split('__')[1],
        'count': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  await batch.commit();
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


}

