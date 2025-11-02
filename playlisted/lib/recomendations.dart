// beginning development of recommendations algorithm, making file
import 'spotify.dart';


//when building a recomendation system, we will begin with content-based filtering
//which uses track attributes to recommend similar tracks
//later we can implement collaborative filtering which uses user behavior and preferences
//to recommend the next track, we pass in the entire list of top songs and filter based on likes.

class RecommendService {

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

  //final SpotifyService _spotifyService = SpotifyService();

  //Future: Function to get liked songs, then find patterns in the user's liked songs
  void getRec(List<Track> likedSongs) async {
    //filtering and recommendation logic can be added here
  }
  //function to add a track to liked songs and increment recommendation count
  void addToLiked(Track track, List<Track> likedSongs) {
    recCount++;
    likedSongs.add(track);
    print('Added to liked songs: ${track.name} by ${track.artists}');
  }

  int getRecCount() {
    return recCount;
  }

}