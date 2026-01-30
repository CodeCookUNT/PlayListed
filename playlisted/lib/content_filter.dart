import 'package:profanity_filter/profanity_filter.dart';

class ExplicitContentFilter {
  ExplicitContentFilter._();

  static final ProfanityFilter _filter = ProfanityFilter();

  static bool containsExplicitContent(String text) {
    
    if (_filter.hasProfanity(text)) {
      return true;
    }

    final standardText = text.toLowerCase();
    final cleanText = standardText.replaceAll(RegExp(r'[^a-z0-9\s]+'), '');
    final textChunks = cleanText.split(RegExp(r'\s+'));

    for (final chunk in textChunks) {
      if (chunk.isEmpty) {
        continue;
      }
      if (_filter.hasProfanity(chunk)) {
        return true;
      }

    for (var start = 0; start < chunk.length; start++) {
      for (var end = start + 2; end <= chunk.length; end++) {
        final substring = chunk.substring(start, end);
        if (_filter.hasProfanity(substring)) {
          return true;
        }
      }
    }
  }
  
  return false;
}
}