import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Checks Firebase Remote Config and shows a force / optional update dialog.
class UpdateChecker {
  UpdateChecker._();

  // Keys are per-platform: ios_min_version, android_min_version, ...
  static String _k(String name) =>
      '${Platform.isIOS ? 'ios' : 'android'}_$name';

  static const _dismissedKey = 'dismissed_update_version';

  /// Call before navigating from the splash.
  /// - Force update: dialog can't be dismissed, so this never returns.
  /// - Optional update: returns when the user taps "Later".
  /// - Any error / offline: fails open (the app just continues).
  static Future<void> check(BuildContext context) async {
    String minVersion = '0.0.0';
    String latestVersion = '0.0.0';
    String message = '';
    String storeUrl = '';
    String current = '0.0.0';

    try {
      final rc = FirebaseRemoteConfig.instance;

      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 5),
          // 0 in debug so you can test instantly; 15 min in release
          minimumFetchInterval:
              kDebugMode ? Duration.zero : const Duration(minutes: 15),
        ),
      );

      // Defaults = no update prompt if the fetch fails
      await rc.setDefaults({
        _k('min_version'): '0.0.0',
        _k('latest_version'): '0.0.0',
        _k('store_url'): '',
        'update_message':
            'A new version of Closer CRM is available. Please update to continue.',
      });

      await rc.fetchAndActivate().timeout(const Duration(seconds: 6));

      minVersion = rc.getString(_k('min_version'));
      latestVersion = rc.getString(_k('latest_version'));
      storeUrl = rc.getString(_k('store_url'));
      message = rc.getString('update_message');

      current = (await PackageInfo.fromPlatform()).version; // e.g. 1.0.0
    } catch (e) {
      debugPrint('UpdateChecker failed (ignored): $e');
      return;
    }

    if (!context.mounted) return;

    // 1) Force update: current < min_version
    if (_isLower(current, minVersion)) {
      await _showDialog(context, force: true, message: message, url: storeUrl);
      return;
    }

    // 2) Optional update: current < latest_version (ask once per version)
    if (_isLower(current, latestVersion)) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_dismissedKey) == latestVersion) return;
      if (!context.mounted) return;

      await _showDialog(context, force: false, message: message, url: storeUrl);
      await prefs.setString(_dismissedKey, latestVersion);
    }
  }

  /// true if [a] < [b] (compares 1.2.10 vs 1.2.9 correctly, numerically)
  static bool _isLower(String a, String b) {
    final x = _parse(a), y = _parse(b);
    for (var i = 0; i < 3; i++) {
      if (x[i] != y[i]) return x[i] < y[i];
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('+').first.split('.');
    return List.generate(
      3,
      (i) => i < parts.length ? int.tryParse(parts[i]) ?? 0 : 0,
    );
  }

  static Future<void> _showDialog(
    BuildContext context, {
    required bool force,
    required String message,
    required String url,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // tapping outside does nothing
      builder: (ctx) => PopScope(
        canPop: !force, // blocks the Android back button on force update
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(force ? 'Update Required' : 'Update Available'),
          content: Text(message),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Later'),
              ),
            FilledButton(
              onPressed: () async {
                if (url.isNotEmpty) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
                // Force: dialog stays open so they can't skip it
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }
}