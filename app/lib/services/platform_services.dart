import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

typedef PickedFile = ({String name, Uint8List bytes});

/// Plugin-backed actions, behind one seam so widgets stay platform-free and testable.
abstract interface class PlatformServices {
  Future<PickedFile?> pickKeyFile();

  Future<void> sharePublicKey(String publicLine, {required String subject});
}

/// Larger files cannot be SSH private keys.
const int maxKeyFileBytes = 64 * 1024;

final class PluginPlatformServices implements PlatformServices {
  const PluginPlatformServices();

  @override
  Future<PickedFile?> pickKeyFile() async {
    final file = await openFile(confirmButtonText: 'Import');
    if (file == null) return null;
    if (await file.length() > maxKeyFileBytes) {
      throw const FormatException('The file is too large to be a key.');
    }
    return (name: file.name, bytes: await file.readAsBytes());
  }

  @override
  Future<void> sharePublicKey(String publicLine, {required String subject}) =>
      SharePlus.instance.share(ShareParams(text: publicLine, subject: subject));
}
