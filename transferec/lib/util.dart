import 'dart:convert';
import 'package:convert/convert.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as ppath;
import 'package:basic_utils/basic_utils.dart';

String? wifiIP = '';
String certHash = '';
String secret = '';

String fileDir = Directory.current.path;
String infoDir = Directory.current.path;

Future<void> writeStreamToFile(String suffix, Stream<List<int>> req) async {
  final infoPath = infoDir + suffix;
  final filePath = fileDir + suffix;
  final infoFile = File(infoPath);
  final fileFile = File(filePath);
  if (await infoFile.exists() && await infoFile.length() == 0) {
    return;
  }
  IOSink? sink = null;
  try {
    await for (final chunk in req) {
      if (null == sink) {
        if (chunk.isEmpty) continue;
        if (await fileFile.exists()) {
          await fileFile.delete(recursive: true); //note even folder is deleted
        }
        if (await infoFile.exists()) {
          await infoFile.delete(recursive: true); //note even folder is deleted
        }
        //info MUST be created BEFORE file!!
        await infoFile.create(recursive: true, exclusive: true);
        await fileFile.create(recursive: true, exclusive: true);
        sink = fileFile.openWrite(mode: FileMode.writeOnly);
      }
      sink!.add(chunk);
      await sink!.flush();
    }
  } finally {
    if (sink != null) await sink!.close();
  }
  if (sink != null) {
    await infoFile.writeAsString("{}");
  }
}

String mkFileDataQR(String dispPath) {
  return '{"ch":${jsonEncode(certHash)},"ip":${jsonEncode(wifiIP)},"sec":${jsonEncode(secret)},"file":${jsonEncode(dispPath)} }';
}

String calcCertHashForPem(String pem) {
  X509CertificateData cert = X509Utils.x509CertificateFromPem(pem);
  var blob = hex.decode(cert.tbsCertificate!.subjectPublicKeyInfo.bytes!);
  var digest = sha256.convert(blob);
  return base64Encode(digest.bytes);
}

QrData mkQrData(String data) {
  final dyn = jsonDecode(data);
  var retval = QrData();
  retval.ch = dyn['ch'];
  retval.ip = dyn['ip'];
  retval.sec = dyn['sec'];
  retval.file = dyn['file'] ?? '';
  retval.dir = dyn['dir'] ?? '';
  return retval;
}

class QrData {
  String ch = '';
  String ip = '';
  String sec = '';
  String file = '';
  String dir = '';
}

Future<void> downloadFile(QrData qrdata, String dirDispPath) async {
  final suffix = ppath.join(dirDispPath, ppath.basename(qrdata.file));
  final httpsUri = Uri(
    scheme: 'https',
    host: qrdata.ip,
    port: 1111,
    path: qrdata.file,
  );
  var client = HttpClient();
  try {
    final remoteCertHash = qrdata.ch;
    client.badCertificateCallback = (cert, host, port) {
      var hashOfCert = calcCertHashForPem(cert.pem);
      //var digest = sha256.convert(cert.der);
      //var hashOfCert = base64Encode(digest.bytes);
      //print('REMOTE CERT: $hashOfCert');
      return remoteCertHash == hashOfCert;
    };
    HttpClientRequest request = await client.postUrl(httpsUri);
    request.headers.contentLength = 0;
    request.headers.set('x-sec', qrdata.sec);
    HttpClientResponse response = await request.close();
    if (200 != response.statusCode) return;
    //print('WRITING FILE TO DIR');
    await writeStreamToFile(suffix, response);
  } finally {
    client.close();
  }
}
