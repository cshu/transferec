import 'package:flutter_test/flutter_test.dart';
import 'package:self_signed_certificate_generator_fp/self_signed_certificate_generator_fp.dart';
import 'package:self_signed_certificate_generator_fp/self_signed_certificate_generator_fp_platform_interface.dart';
import 'package:self_signed_certificate_generator_fp/self_signed_certificate_generator_fp_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSelfSignedCertificateGeneratorFpPlatform
    with MockPlatformInterfaceMixin
    implements SelfSignedCertificateGeneratorFpPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SelfSignedCertificateGeneratorFpPlatform initialPlatform = SelfSignedCertificateGeneratorFpPlatform.instance;

  test('$MethodChannelSelfSignedCertificateGeneratorFp is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSelfSignedCertificateGeneratorFp>());
  });

  test('getPlatformVersion', () async {
    SelfSignedCertificateGeneratorFp selfSignedCertificateGeneratorFpPlugin = SelfSignedCertificateGeneratorFp();
    MockSelfSignedCertificateGeneratorFpPlatform fakePlatform = MockSelfSignedCertificateGeneratorFpPlatform();
    SelfSignedCertificateGeneratorFpPlatform.instance = fakePlatform;

    expect(await selfSignedCertificateGeneratorFpPlugin.getPlatformVersion(), '42');
  });
}
