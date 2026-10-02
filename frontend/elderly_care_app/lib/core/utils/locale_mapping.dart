/// Maps the app's own language codes ('en', 'hi' — see AppUser.preferredLanguage and the
/// backend's voice language packs) to the locale formats the speech_to_text and flutter_tts
/// plugins expect. Anything not explicitly mapped falls back to English, matching the
/// backend's own fallback behavior for unsupported languages.
String speechToTextLocale(String languageCode) {
  switch (languageCode) {
    case 'hi':
      return 'hi_IN';
    default:
      return 'en_US';
  }
}

String ttsLocale(String languageCode) {
  switch (languageCode) {
    case 'hi':
      return 'hi-IN';
    default:
      return 'en-US';
  }
}
