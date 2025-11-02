// beginning development of recommendations algorithm, making file
import 'spotify.dart';


//when building a recomendation system, we will begin with content-based filtering
//which uses track attributes to recommend similar tracks
//later we can implement collaborative filtering which uses user behavior and preferences
//to recommend the next track, we pass in the entire list of top songs and filter based on likes.

class RecommendService {
  int recCount = 0;
  //final SpotifyService _spotifyService = SpotifyService();

  //Future: Function to get liked songs, then find patterns in the user's liked songs
  void getRec(List<Track> likedsongs) async {
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