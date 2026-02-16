import 'translations_en.dart';
import 'translations_ko.dart';

class I18n {
  static const Map<String, Map<String, String>> _translations = {
    'ko': koTranslations,
    'en': enTranslations,
  };

  static List<String> get supported => _translations.keys.toList(growable: false);

  static String tr(String lang, String key) {
    final table = _translations[lang] ?? enTranslations;
    return table[key] ?? enTranslations[key] ?? key;
  }

  static String trf(String lang, String key, Map<String, String> values) {
    var text = tr(lang, key);
    values.forEach((k, v) => text = text.replaceAll('{$k}', v));
    return text;
  }
}
