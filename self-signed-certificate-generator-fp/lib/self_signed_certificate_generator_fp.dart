import 'dart:typed_data';

import 'self_signed_certificate_generator_fp_platform_interface.dart';

class SelfSignedCertificateGeneratorFp {
  Future<String?> getPlatformVersion() {
    return SelfSignedCertificateGeneratorFpPlatform.instance.getPlatformVersion();
  }
  Future<Uint8List?> gen() {
    return SelfSignedCertificateGeneratorFpPlatform.instance.gen();
  }
}
