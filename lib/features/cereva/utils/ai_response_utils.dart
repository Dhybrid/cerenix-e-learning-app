import '../../../core/utils/latex_render_utils.dart';

class AiResponseUtils {
  static const Duration requestTimeout = Duration(seconds: 90);

  static String sanitizeForSpeech(String text) {
    var cleaned = LatexRenderUtils.sanitizeStoredMathTags(text);

    cleaned = cleaned.replaceAll(
      RegExp(r'```[\s\S]*?```'),
      ' A code example is shown on your screen. ',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'!\[[^\]]*\]\([^)]+\)'),
      ' An illustration is shown on your screen. ',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'<img[^>]*>', caseSensitive: false),
      ' An illustration is shown on your screen. ',
    );
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]+>', caseSensitive: false), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'`([^`]+)`'), ' code ');
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (match) => match.group(1) ?? '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'https?://\S+', caseSensitive: false),
      ' ',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\$\$[\s\S]*?\$\$', dotAll: true),
      ' The formula is shown on your screen. ',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\$[^$\n]*?\$'),
      ' The formula is shown on your screen. ',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\\\((.*?)\\\)'),
      ' The formula is shown on your screen. ',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\\\[(.*?)\\\]'),
      ' The formula is shown on your screen. ',
    );
    cleaned = cleaned.replaceAll(RegExp(r'#+\s*'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\*\*|\*|__|_|~~'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[*+-]\s+', multiLine: true), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), ' ');
    cleaned = cleaned.replaceAll(
      RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true),
      ' ',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'[\u{2600}-\u{27BF}]', unicode: true),
      ' ',
    );
    cleaned = cleaned.replaceAll(RegExp(r'[|•●■◆★☆◦▪▶►]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'[{}<>[\]]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'[#$%^*_+=~`]+'), ' ');
    cleaned = cleaned.replaceAll('&', ' and ');
    cleaned = cleaned.replaceAll('@', ' at ');
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(?:diagram|illustration|figure|image|chart|graph|visual)\b\s*:?',
        caseSensitive: false,
      ),
      ' visual ',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\n{2,}'), '. ');
    cleaned = cleaned.replaceAll('\n', ' ');
    cleaned = cleaned.replaceAll(';', '. ');
    cleaned = cleaned.replaceAll(':', '. ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.trim();
  }
}
