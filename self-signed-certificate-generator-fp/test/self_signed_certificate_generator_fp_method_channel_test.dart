import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_signed_certificate_generator_fp/self_signed_certificate_generator_fp_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelSelfSignedCertificateGeneratorFp platform = MethodChannelSelfSignedCertificateGeneratorFp();
  const MethodChannel channel = MethodChannel('self_signed_certificate_generator_fp');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
