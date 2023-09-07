import 'dart:typed_data';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'self_signed_certificate_generator_fp_method_channel.dart';

abstract class SelfSignedCertificateGeneratorFpPlatform extends PlatformInterface {
  /// Constructs a SelfSignedCertificateGeneratorFpPlatform.
  SelfSignedCertificateGeneratorFpPlatform() : super(token: _token);

  static final Object _token = Object();

  static SelfSignedCertificateGeneratorFpPlatform _instance = MethodChannelSelfSignedCertificateGeneratorFp();

  /// The default instance of [SelfSignedCertificateGeneratorFpPlatform] to use.
  ///
  /// Defaults to [MethodChannelSelfSignedCertificateGeneratorFp].
  static SelfSignedCertificateGeneratorFpPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SelfSignedCertificateGeneratorFpPlatform] when
  /// they register themselves.
  static set instance(SelfSignedCertificateGeneratorFpPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
  Future<Uint8List?> gen() {
    throw UnimplementedError('gen() has not been implemented.');
  }
}
