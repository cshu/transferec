import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'self_signed_certificate_generator_fp_platform_interface.dart';

/// An implementation of [SelfSignedCertificateGeneratorFpPlatform] that uses method channels.
class MethodChannelSelfSignedCertificateGeneratorFp extends SelfSignedCertificateGeneratorFpPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('self_signed_certificate_generator_fp');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
  @override
  Future<Uint8List?> gen() async {
    final retval = await methodChannel.invokeMethod<Uint8List>('gen');
    return retval;
  }
}
