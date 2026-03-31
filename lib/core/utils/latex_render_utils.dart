class LatexRenderUtils {
  const LatexRenderUtils._();

  static String _decodeBasicEntities(String content) {
    return content
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  static String normalizeDelimitedMath(String content) {
    return content
        .replaceAll(r'\\(', r'\(')
        .replaceAll(r'\\)', r'\)')
        .replaceAll(r'\\[', r'\[')
        .replaceAll(r'\\]', r'\]');
  }

  static String replaceBracketMathWithCustomTags(
    String content,
    String Function(String) escapeHtml,
  ) {
    String result = normalizeDelimitedMath(content);

    result = result.replaceAllMapped(
      RegExp(r'\\\[(.+?)\\\]', dotAll: true),
      (match) =>
          '<tex-block>${escapeHtml(match.group(1)?.trim() ?? '')}</tex-block>',
    );

    result = result.replaceAllMapped(
      RegExp(r'\\\((.+?)\\\)', dotAll: true),
      (match) =>
          '<tex-inline>${escapeHtml(match.group(1)?.trim() ?? '')}</tex-inline>',
    );

    return result;
  }

  static String restoreCustomTexTagsToLatex(String content) {
    String result = _decodeBasicEntities(content);

    result = result.replaceAllMapped(
      RegExp(
        r'<span[^>]*class="[^"]*math-tex[^"]*"[^>]*>([\s\S]*?)</span>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) => match.group(1)?.trim() ?? '',
    );

    result = result.replaceAllMapped(
      RegExp(
        r'<script[^>]*type="math/tex;\s*mode=display"[^>]*>([\s\S]*?)</script>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) => '\$\$${match.group(1)?.trim() ?? ''}\$\$',
    );

    result = result.replaceAllMapped(
      RegExp(
        r'<script[^>]*type="math/tex"[^>]*>([\s\S]*?)</script>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) => '\$${match.group(1)?.trim() ?? ''}\$',
    );

    result = result.replaceAllMapped(
      RegExp(
        r'<\s*tex\s*-\s*block\s*>([\s\S]*?)<\s*/\s*tex\s*-\s*block\s*>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) => '\$\$${match.group(1)?.trim() ?? ''}\$\$',
    );

    result = result.replaceAllMapped(
      RegExp(
        r'<\s*tex\s*-\s*inline\s*>([\s\S]*?)<\s*/\s*tex\s*-\s*inline\s*>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) => '\$${match.group(1)?.trim() ?? ''}\$',
    );

    result = result.replaceAll(
      RegExp(r'<\s*/?\s*tex\s*-\s*(?:inline|block)\s*>', caseSensitive: false),
      '',
    );

    return result;
  }

  static String sanitizeStoredMathTags(String content) {
    if (content.isEmpty) {
      return content;
    }

    return normalizeDelimitedMath(restoreCustomTexTagsToLatex(content));
  }

  static String normalizeMathExpression(String expression) {
    String clean = expression.trim();

    clean = clean
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&times;', r'\times')
        .replaceAll('&divide;', r'\div')
        .replaceAll('&plusmn;', r'\pm');

    clean = normalizeDelimitedMath(clean);
    clean = clean.replaceAllMapped(
      RegExp(r'\\\\([A-Za-z]+)'),
      (match) => '\\${match.group(1)}',
    );

    if (clean.startsWith(r'\(') && clean.endsWith(r'\)')) {
      clean = clean.substring(2, clean.length - 2);
    } else if (clean.startsWith(r'\[') && clean.endsWith(r'\]')) {
      clean = clean.substring(2, clean.length - 2);
    } else if (clean.startsWith(r'$$') && clean.endsWith(r'$$')) {
      clean = clean.substring(2, clean.length - 2);
    } else if (clean.startsWith(r'$') && clean.endsWith(r'$')) {
      clean = clean.substring(1, clean.length - 1);
    }

    clean = clean
        .replaceAll(r'\displaystyle', '')
        .replaceAll(r'\textstyle', '');

    return clean.trim();
  }

  static String fallbackMathText(String expression) {
    return normalizeMathExpression(expression)
        .replaceAll(r'\frac', 'frac')
        .replaceAll(r'\sqrt', 'sqrt')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\div', '÷')
        .replaceAll(r'\pm', '±')
        .replaceAll(r'\leq', '≤')
        .replaceAll(r'\geq', '≥')
        .replaceAll(r'\neq', '≠')
        .replaceAll(r'\approx', '≈');
  }
}
