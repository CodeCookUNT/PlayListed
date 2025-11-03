// beginning development of recommendations algorithm, making file
import 'spotify.dart';


//when building a recomendation system, we will begin with content-based filtering
//which uses track attributes to recommend similar tracks
//later we can implement collaborative filtering which uses user behavior and preferences
//to recommend the next track, we pass in the entire list of top songs and filter based on likes.

class RecommendService {
  List<Track>? likedTracks = [];
  // counter for number of recommendations made, making available tracks list respectively  
  int recCount = 0;
  List<Track> availableTracks = const [];
  
  // setter for available tracks towards recommendation
  void setAvailableTracks(List<Track> tracks) {
    availableTracks = tracks;
  }
  
  // callback to update liked songs in UI when recommendations are generated 
  void Function(List<Track>)? onUpdate;

  // setter for update callback
  void setUpdate(void Function(List<Track>) callback) {
    onUpdate = callback;
  }

  // helper function to pull artist names from a track
  Set<String> artistNames(Track track) {
    // establishing variables to hold artist names
    final names = <String>{};
    final artists = (track.artists as List?) ?? const[];

    // looping through artists to extract names from maps and/or strings
    for (final a in artists){
      // checking if artist is a map with a name key
      if (a is Map && a['name'] != null) {
        final s = a['name'].toString().trim().toLowerCase();
        if (s.isNotEmpty) names.add(s);
      }
      // checking if artist is a string
      else{
        final s = a.toString().trim().toLowerCase();
        if (s.isNotEmpty) names.add(s);
      }
    }
    return names; // returning set of artist names
  }

  //final SpotifyService _spotifyService = SpotifyService();

  //Future: Function to get liked songs, then find patterns in the user's liked songs
  //! Recomendation algorithm goes here!
  void getRec(List<Track> likedSongs) async {
    print("I have called getRec");
    //filtering and recommendation logic can be added here
  }
  //function to add a track to liked songs and increment recommendation count
  void addToLiked(Track track, List<Track> likedSongs) {
    recCount++;
    likedSongs.add(track);
    print('Added to liked songs: ${track.name} by ${track.artists}');
  }


  //helper function to check if recommendation count has reached threshold
  //called in appstate
  void checkRecCount() {
    if (recCount >= 10) {
      getRec(likedTracks!);
      recCount = 0; //reset count after getting recommendations
    }
  }

  int getRecCount() {
    return recCount;
  }

}