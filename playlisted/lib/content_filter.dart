import 'package:profanity_filter/profanity_filter.dart';

class ExplicitContentFilter {
  ExplicitContentFilter._();

  static final ProfanityFilter _filter = ProfanityFilter();

  static bool contatinsExplicitContent(String text) {
    return _filter.hasProfanity(text);
  }
}