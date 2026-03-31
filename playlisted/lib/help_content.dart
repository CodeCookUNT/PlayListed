import 'package:flutter/material.dart';
import 'help_overlay.dart';

// This file defines the content for each help page in the app. Then  
// the HelpOverlay widget then takes this content and builds the UI automatically based on it.

// Data models for the help content structure
abstract final class HelpContent {
  static Widget iconButton(BuildContext context, HelpPageContent content) {
    return IconButton(
      icon: const Icon(Icons.help_outline),
      tooltip: 'Help',
      onPressed: () => Navigator.of(context).push(HelpOverlay.route(content)),
    );
  }

  // Home page -------------------------------------------------
  static const HelpPageContent home = HelpPageContent(
    appBarTitle: 'How It Works',
    heroIcon: Icons.home_rounded,
    heroTitle: 'The Home Feed',
    heroSubtitle:
        'Discover, rate, and review songs all in one place. ',
    tipText:
        'Tip: The more you like and rate songs, the better your '
        'personalised feed becomes!',
    sections: [
      HelpSection(
        heading: 'Reading the Card',
        items: [
          HelpItem(
            icon: Icons.album,
            iconColor: Color(0xFF1583B7),
            title: 'Album Art & Vinyl',
            body:
                'The album cover is displayed. Behind it, a vinyl that changes colour based on the community rating. The colour tiers are:\n\n'
                'Black — no rating yet\n'
                'Bronze — rated 2 ★ or above\n'
                'Silver — rated 3 ★ or above\n'
                'Gold — rated 4 ★ or above\n'
                'Platinum — rated 4.8 ★ or above',
          ),
          HelpItem(
            icon: Icons.title,
            iconColor: Color(0xFF1DB954),
            title: 'Song & Artist Info',
            body:
                'The song title and artist name appear in the blue card below the art. '
                'Tap the green Spotify button (↗) to open the track directly in Spotify.',
          ),
        ],
      ),
      HelpSection(
        heading: 'Rating & Liking',
        items: [
          HelpItem(
            icon: Icons.star,
            iconColor: Colors.amber,
            title: 'Star Rating',
            body:
                'Tap a star to give the song 1 – 5 stars. Tap the same star again '
                'to reduce it by half a star. Setting a rating also saves the song ',
          ),
          HelpItem(
            icon: Icons.favorite,
            iconColor: Colors.redAccent,
            title: 'Like Button',
            body:
                'Tapping the Like button adds a song to your Liked list without giving it a '
                'star rating. Tap again to unlike it.',
          ),
        ],
      ),
      HelpSection(
        heading: 'Navigating Songs',
        items: [
          HelpItem(
            icon: Icons.swipe,
            iconColor: Color(0xFF8E24AA),
            title: 'Swipe to Navigate',
            body:
                'Swipe left to go to the next song, swipe right to go back to the '
                'previous one. You can also tap the Next and Back buttons at the bottom.',
          ),
          HelpItem(
            icon: Icons.auto_awesome,
            iconColor: Color(0xFF1583B7),
            title: 'Smart Feed',
            body:
                'The app updates your feed using your '
                'likes, ratings, and what your friends enjoy as well.',
          ),
        ],
      ),
      HelpSection(
        heading: 'Reviews',
        items: [
          HelpItem(
            icon: Icons.rate_review,
            iconColor: Color(0xFF1583B7),
            title: 'Write a Review',
            body:
                'Tap Write Review to leave up to 300 characters of thoughts about '
                'the song. Your review is saved to your profile and shown '
                'alongside your star rating.',
          ),
          HelpItem(
            icon: Icons.reviews,
            iconColor: Color(0xFF1DB954),
            title: 'See All Reviews',
            body:
                'Tap Reviews to read what other users have written about the '
                'song, sorted by most recent. Each card shows the reviewer\'s '
                'username, rating, and when they posted.',
          ),
          HelpItem(
            icon: Icons.public,
            iconColor: Colors.amber,
            title: 'Community Rating',
            body:
                'At the bottom of the page you\'ll see the current community average rating for that song. ',
          ),
        ],
      ),
    ],
  );


  // My Songs page ----------------------------------------------------------------
  static const HelpPageContent mySongs = HelpPageContent(
    appBarTitle: 'My Songs – Help',
    heroIcon: Icons.library_music,
    heroTitle: 'My Songs',
    heroSubtitle:
        'All the songs you\'ve liked or rated, organised into two tabs.',
    sections: [
      HelpSection(
        heading: 'Tabs',
        items: [
          HelpItem(
            icon: Icons.favorite,
            iconColor: Colors.redAccent,
            title: 'Liked Tab',
            body:
                'Shows every song you\'ve liked, sorted by most recently liked. '
                'These songs influence your recommendations even without a star rating.',
          ),
          HelpItem(
            icon: Icons.star,
            iconColor: Colors.amber,
            title: 'Rated Tab',
            body:
                'Shows every song you\'ve given at least one star, sorted by most '
                'recently updated. Your personal star rating is shown beneath each title.',
          ),
        ],
      ),
      HelpSection(
        heading: 'Actions',
        items: [
          HelpItem(
            icon: Icons.swipe_left,
            iconColor: Color(0xFF8E24AA),
            title: 'Swipe to Remove',
            body:
                'Swipe any song to the left to reveal the red remove button. '
                'Tap it to unlike / unrate the song and remove it from the list.',
          ),
          HelpItem(
            icon: Icons.star_half,
            iconColor: Colors.amber,
            title: 'Edit Your Rating',
            body:
                'Tap the stars directly in the list to update your rating without '
                'leaving this page. Changes sync instantly.',
          ),
        ],
      ),
    ],
  );


  // Search page ----------------------------------------------------------------
  static const HelpPageContent search = HelpPageContent(
    appBarTitle: 'Search – Help',
    heroIcon: Icons.search_rounded,
    heroTitle: 'Song Search',
    heroSubtitle:
        'Find any song or artist and jump straight to their info, ratings, and reviews.',
    tipText:
        'Tip: Can\'t find the song by title? Try searching the artist\'s name instead or vice versa!',
    sections: [
      HelpSection(
        heading: 'Searching',
        items: [
          HelpItem(
            icon: Icons.music_note,
            iconColor: Color(0xFF1583B7),
            title: 'Search by Song Title',
            body:
                'Type part of a song\'s name and matching tracks appear automatically. '
                'Results show the track title, artist, and album art.',
          ),
          HelpItem(
            icon: Icons.person,
            iconColor: Color(0xFF8E24AA),
            title: 'Search by Artist',
            body:
                'If no song matches are found, the app automatically falls back to '
                'searching artists and returns their top tracks.',
          ),
        ],
      ),
      HelpSection(
        heading: 'Results',
        items: [
          HelpItem(
            icon: Icons.touch_app,
            iconColor: Color(0xFF1DB954),
            title: 'Tap a Result',
            body:
                'Tap any result to open the Song where you can '
                'rate it, like it, write a review, and see community reviews.',
          ),
          HelpItem(
            icon: Icons.open_in_new,
            iconColor: Color(0xFF1DB954),
            title: 'Open in Spotify',
            body:
                'You also have the option to tap the green ↗ button on any result to open that track directly '
                'in Spotify.',
          ),
        ],
      ),
    ],
  );


  // Friends Page ------------------------------------------------------------------
  static const HelpPageContent friends = HelpPageContent(
    appBarTitle: 'Friends – Help',
    heroIcon: Icons.people,
    heroTitle: 'Friends',
    heroSubtitle:
        'Connect with other listeners, chat, and shape each other\'s recommendations.',
    tipText:
        'Tip: Friends\' listening habits boost songs in your feed — add people with similar taste!',
    sections: [
      HelpSection(
        heading: 'Adding Friends',
        items: [
          HelpItem(
            icon: Icons.person_add,
            iconColor: Color(0xFF1583B7),
            title: 'Send a Friend Request',
            body:
                'Type a username or email address in the text field and tap the '
                'add-person icon. A request is sent to that user.',
          ),
          HelpItem(
            icon: Icons.account_box,
            iconColor: Color(0xFF8E24AA),
            title: 'Incoming & Outgoing Requests',
            body:
                'Tap the requests icon to see pending requests you\'ve received '
                'or sent. Accept, decline, or cancel them from there.',
          ),
        ],
      ),
      HelpSection(
        heading: 'Friend Actions',
        items: [
          HelpItem(
            icon: Icons.chat,
            iconColor: Color(0xFF1DB954),
            title: 'Chat',
            body:
                'Tap a friend\'s name to open a direct message chat. '
                'Messages are filtered, so behave.',
          ),
          HelpItem(
            icon: Icons.account_box,
            iconColor: Color(0xFF1583B7),
            title: 'View Profile',
            body:
                'Tap the profile icon on a friend\'s tile to see their stats, '
                'favourite songs, and public reviews.',
          ),
          HelpItem(
            icon: Icons.person_remove,
            iconColor: Colors.redAccent,
            title: 'Remove Friend',
            body:
                'Tap the red remove icon and confirm to unfriend someone. ',
          ),
        ],
      ),
    ],
  );


  // Collections page -----------------------------------------------------------------
  static const HelpPageContent collections = HelpPageContent(
    appBarTitle: 'Collections – Help',
    heroIcon: Icons.library_music_outlined,
    heroTitle: 'Collections',
    heroSubtitle:
        'Browse curated song collections by decade and era. '
        'Tap any album to rate and review it.',
    tipText: 'Tip: Liking songs from Collections improves your feed recommendations as well.',
    sections: [
      HelpSection(
        heading: 'Browsing',
        items: [
          HelpItem(
            icon: Icons.view_carousel,
            iconColor: Color(0xFF1583B7),
            title: 'Rows information',
            body:
                'Songs are organised into horizontal rows by decade — Popular Now, '
                'Scroll left or right using the chevron arrows or by swiping.',
          ),
          HelpItem(
            icon: Icons.touch_app,
            iconColor: Color(0xFF1DB954),
            title: 'Tap an Album',
            body:
                'Tap any album cover to open the Song for that track. '
                'From there you can rate, like, review, and open it in Spotify.',
          ),
        ],
      ),
    ],
  );


  // Profile page
  static const HelpPageContent profile = HelpPageContent(
    appBarTitle: 'Profile – Help',
    heroIcon: Icons.person,
    heroTitle: 'Your Profile',
    heroSubtitle:
        'See your listening stats, favourite songs, and all the reviews you\'ve written.',
    sections: [
      HelpSection(
        heading: 'Statistics',
        items: [
          HelpItem(
            icon: Icons.bar_chart,
            iconColor: Color(0xFF1583B7),
            title: 'Total Songs Rated',
            body: 'The total number of songs you\'ve given a star.',
          ),
          HelpItem(
            icon: Icons.star,
            iconColor: Colors.amber,
            title: 'Average Rating',
            body:
                'Your personal average star rating across all the songs you\'ve rated, ',
          ),
        ],
      ),
      HelpSection(
        heading: 'Favourites & Reviews',
        items: [
          HelpItem(
            icon: Icons.star,
            iconColor: Colors.amber,
            title: 'Favourite Songs',
            body:
                'Any song you\'ve rated 5 stars appears here with its album art.',
          ),
          HelpItem(
            icon: Icons.rate_review,
            iconColor: Color(0xFF1DB954),
            title: 'Your Reviews',
            body:
                'All songs with a written review are listed here showing the album art, '
                'title, artist, your review text, and star rating.',
          ),
        ],
      ),
      HelpSection(
        heading: 'Customisation',
        items: [
          HelpItem(
            icon: Icons.edit,
            iconColor: Color(0xFF8E24AA),
            title: 'Edit Avatar',
            body:
                'Tap Edit avatar to choose a new colour and icon for your profile picture. '
                'The change is reflected in friend lists immediately.',
          ),
        ],
      ),
    ],
  );
}