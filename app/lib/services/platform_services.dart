import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config_file.dart';

typedef PickedFile = ({String name, Uint8List bytes});

/// Plugin-backed actions, behind one seam so widgets stay platform-free and testable.
abstract interface class PlatformServices {
  Future<PickedFile?> pickKeyFile();

  Future<void> sharePublicKey(String publicLine, {required String subject});

  /// Null when cancelled; throws [FormatException] for oversized files.
  Future<PickedFile?> pickConfigFile();

  /// Save dialog on desktop, share sheet on mobile; false when cancelled.
  Future<bool> saveConfigFile(String fileName, Uint8List bytes);

  /// Opens [url] in the browser; false when nothing on the device can.
  Future<bool> openLink(Uri url);
}

/// Larger files cannot be SSH private keys.
const int maxKeyFileBytes = 64 * 1024;

final class PluginPlatformServices implements PlatformServices {
  const PluginPlatformServices();

  @override
  Future<PickedFile?> pickKeyFile() =>
      _pick(maxKeyFileBytes, 'The file is too large to be a key.');

  @override
  Future<void> sharePublicKey(String publicLine, {required String subject}) =>
      SharePlus.instance.share(ShareParams(text: publicLine, subject: subject));

  @override
  Future<PickedFile?> pickConfigFile() => _pick(
    maxConfigFileBytes,
    'The file is too large to be a configuration export.',
  );

  @override
  Future<bool> saveConfigFile(String fileName, Uint8List bytes) async {
    // file_selector has no save dialog on Android and iOS.
    if (Platform.isAndroid || Platform.isIOS) {
      final result = await SharePlus.instance.share(
        ShareParams(
          subject: 'LUKS Remote Unlocker configuration',
          files: [
            XFile.fromData(bytes, mimeType: 'application/json', name: fileName),
          ],
          fileNameOverrides: [fileName],
        ),
      );
      return result.status != ShareResultStatus.dismissed;
    }
    final location = await getSaveLocation(
      suggestedName: fileName,
      confirmButtonText: 'Export',
    );
    if (location == null) return false;
    await File(location.path).writeAsBytes(bytes, flush: true);
    return true;
  }

  @override
  Future<bool> openLink(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } on PlatformException {
      return false;
    }
  }

  static Future<PickedFile?> _pick(int maxBytes, String tooLarge) async {
    final file = await openFile(confirmButtonText: 'Import');
    if (file == null) return null;
    if (await file.length() > maxBytes) throw FormatException(tooLarge);
    return (name: file.name, bytes: await file.readAsBytes());
  }
}
