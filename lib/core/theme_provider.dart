import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simple StateProvider — initial value is injected via ProviderScope override
// in main.dart after reading SharedPreferences, so the theme is persisted across
// cold starts without needing an AsyncNotifier or FutureBuilder at the root.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
