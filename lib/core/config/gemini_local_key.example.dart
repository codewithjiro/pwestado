// TEMPLATE for the private-demo Gemini API key. This file is tracked; the
// real key file is not.
//
// Setup (PowerShell, from the project root):
//
//   Copy-Item lib/core/config/gemini_local_key.example.dart `
//             lib/core/config/gemini_local_key.dart
//
// Then paste your key between the quotes in gemini_local_key.dart.
// `lib/core/config/gemini_local_key.dart` is listed in .gitignore; check with
// `git check-ignore -v lib/core/config/gemini_local_key.dart` before any
// commit. The app does not compile until that file exists.
//
// PRIVATE DEMONSTRATIONS ONLY. A key compiled into an APK can be extracted
// by anyone who has the APK. Do not share APKs built with your key, use a
// key restricted to the Gemini API with a low quota, and rotate it in Google
// AI Studio if an APK leaves your hands. Never paste the key into README
// files, issues, screenshots or logs.

/// Gemini API key from Google AI Studio. Empty means AI Insights shows
/// "not set up" and everything else keeps working.
const geminiApiKey = '';
