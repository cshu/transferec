import 'dart:convert';
import 'package:convert/convert.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as ppath;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:file_picker/file_picker.dart';
//import 'package:pem/pem.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:self_signed_certificate_generator_fp/self_signed_certificate_generator_fp.dart';

import 'util.dart';

//note that info files have a mirror-like structure. And info file is always created first before actual file is created. And info file is always written after actual file is written. There are 2 reasons: info files can be indicator of incomplete (corrupt) file (uploading aborted halfway); info file may also help avoid concurrent writing to same file.

const int logSizeLimit = 8; //65536; //debug
const int portThatIsEasyToType = 1111;
Directory appSuppDir = Directory.current;
Directory appDocsDir = Directory.current;
File? secFile;
IOSink? logFile;
List<FileSystemEntity> filelist = <FileSystemEntity>[];
Uint8List cerBytes = Uint8List(0);
Uint8List keyBytes = Uint8List(0);
MyHomePageState myhome = MyHomePageState();
bool initialized = false;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Transfer EC'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() {
    return myhome;
  }
}

class MyHomePageState extends State<MyHomePage> {
  //String _logFileSize = '';
  int _selectedIndex = 0;
  Map<String, bool> fileQR = <String, bool>{};
  Map<String, bool> dirScan = <String, bool>{};
  bool getFileQR(String dispPath) {
    return fileQR[dispPath] ?? false;
  }

  void setFileQR(String dispPath) {
    setState(() {
      fileQR[dispPath] = true;
    });
  }

  void unsetFileQR(String dispPath) {
    setState(() {
      fileQR[dispPath] = false;
    });
  }

  bool getDirScan(String dispPath) {
    return dirScan[dispPath] ?? false;
  }

  void setDirScan(String dispPath) {
    setState(() {
      dirScan[dispPath] = true;
    });
  }

  void unsetDirScan(String dispPath) {
    setState(() {
      dirScan[dispPath] = false;
    });
  }

  void setStatePublic() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) {
      initialized = true;
      () async {
        final info = NetworkInfo();
        wifiIP = await info.getWifiIP();
        setState(() {});
      }();
      () async {
        appSuppDir = await getApplicationSupportDirectory();
        appDocsDir = await getApplicationDocumentsDirectory();
        File lfile = getLogFile();
        if (!await lfile.exists()) await lfile.create(recursive: true);
        var lfilelen = await lfile.length();
        if (lfilelen > logSizeLimit) {
          var oldLog = ppath.join(appSuppDir.path, 'oldlog');
          //var oldLogFile = File(oldLog);
          //if (await oldLogFile.exists()) await oldLogFile.delete();
          //note `rename` can overwrite file
          await lfile.rename(oldLog);
          lfile = getLogFile();
          await lfile.create(recursive: true);
          //_logFileSize = '0';
        } else {
          //_logFileSize = lfilelen.toString();
        }
        logFile = lfile.openWrite(mode: FileMode.append);
        final sec = File(ppath.join(appSuppDir.path, 'secret'));
        if (await sec.exists()) {
          secret = await sec.readAsString();
        }
        //
        infoDir = ppath.join(appSuppDir.path, 'info');
        fileDir = ppath.join(appDocsDir.path, 'file');
        await Directory(infoDir).create(recursive: true);
        await Directory(fileDir).create(recursive: true);
        //final ckFilenm = ppath.join(appSuppDir.path, 'cert_and_key');
        //final ckFile = File(ckFilenm);
        final cerFilenm = ppath.join(appSuppDir.path, 'cer.pem');
        final keyFilenm = ppath.join(appSuppDir.path, 'key.pem');
        final cerFile = File(cerFilenm);
        final keyFile = File(keyFilenm);
        if (await keyFile.exists()) {
          cerBytes = await cerFile.readAsBytes();
          keyBytes = await keyFile.readAsBytes();
        } else {
          var sscgf = SelfSignedCertificateGeneratorFp();
          Uint8List? certnkey = await sscgf.gen();
          if (null == certnkey) {
            //print("cert gen failed"); //fixme
            return;
          }
          int len =
              ByteData.sublistView(certnkey, 0, 4).getUint32(0, Endian.little);
          cerBytes = Uint8List.sublistView(certnkey, 4, 4 + len);
          keyBytes = Uint8List.sublistView(certnkey, 4 + len);
          cerFile.writeAsBytes(cerBytes, flush: true);
          keyFile.writeAsBytes(keyBytes, flush: true);
        }
        var serverContext = SecurityContext();
        serverContext.useCertificateChainBytes(cerBytes);
        serverContext.usePrivateKeyBytes(keyBytes);
        calcCertHash();
        await deleteCorruptFiles();
        //var listOfInt = PemCodec(PemLabel.certificate).decode(utf8.decode(cerBytes));
        //var digest = sha256.convert(listOfInt);
        //certHash = base64Encode(digest.bytes);
        //
        //
        HttpServer boundResult = await HttpServer.bindSecure(
            InternetAddress.anyIPv4, portThatIsEasyToType, serverContext);
        //print("ready for listening"); //debug
        inLog(DateTime.now().toIso8601String());
        secFile = sec;
        setState(() {});
        /*await*/ refrFileList();
        boundResult.listen(defOnData);
      }();
    }
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: //Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          /*child:*/ Row(
        //mainAxisAlignment: MainAxisAlignment.center,
        children: mkNavAndFlex(),
      ),
      //),
      //floatingActionButton: FloatingActionButton(
      //  onPressed: _incrementCounter,
      //  tooltip: 'Increment',
      //  child: const Icon(Icons.add),
      //), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  List<Widget> mkNavAndFlex() {
    var retval = <Widget>[];
    if (null != secFile) {
      retval.add(
        NavigationRail(
          selectedIndex: _selectedIndex,
          groupAlignment: -1,
          onDestinationSelected: (int index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          labelType: NavigationRailLabelType.all,
          destinations: const <NavigationRailDestination>[
            NavigationRailDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: Text('Status'),
            ),
            //NavigationRailDestination(
            //  icon: Icon(Icons.qr_code_outlined),
            //  selectedIcon: Icon(Icons.qr_code),
            //  label: Text('Scan QR'),
            //),
            NavigationRailDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: Text('Files'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.password_outlined),
              selectedIcon: Icon(Icons.password),
              label: Text('Secret'),
            ),
          ],
        ),
      );
      retval.add(
        const VerticalDivider(thickness: 1, width: 1),
      );
    }
    retval.add(
      Flexible(
        //without flexible you get "Vertical viewport was given unbounded width"
        child: mkMainList(context, _selectedIndex), // mkHome(context),
      ),
    );
    return retval;
  }

  ListView mkHome(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        Text(
          null == wifiIP ? 'Wi-Fi IP is unavailable' : 'Wi-Fi IP: ${wifiIP!}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Divider(),
        const Text(
          'Port number for HTTPS: $portThatIsEasyToType',
        ),
        const Divider(),
        Text(
          'Cert hash: $certHash',
        ),
        const Divider(),
        Text(secret == ''
            ? 'All your files are publicly available on Wi-Fi because there is no secret set yet. (If you want to prevent other people under the same Wi-Fi from reading/writing your files, set a secret)'
            : 'You have set a secret. Any client trying to connect to this device needs to know the secret for any reading/writing.'),
        const Divider(),
        //new ElevatedButton(
        //  onPressed: () async {
        //    await logFile!.close();
        //    await getLogFile().writeAsBytes(<int>[]);
        //    _logFileSize = '0';
        //    setState(() {});
        //  },
        //  child: Text(
        //    'Tap to DELETE app log. Current app log file size is: ' +
        //        _logFileSize +
        //        '.',
        //  ),
        //),
        ////Text(
        ////  'App internal log file size is: '+_logFileSize,
        ////),
        //Divider(),
        const Text(
          'Example command for upload/download with curl can be found on README.md of github.com/cshu/transferec',
        ),
      ],
    );
  }

  ListView mkMainList(BuildContext context, int selidx) {
    //if (null == secFile) return mkHome(context);
    switch (selidx) {
      case 0:
        return mkHome(context);
        break;
      //case 1:
      //  return mkQR(context);
      //  break;
      case 1:
        return mkFileList(context);
        break;
      case 2:
        return mkSec(context);
        break;
      default:
        return mkHome(context);
        break;
    }
  }
}

//ListView mkQR(BuildContext context) {
//  return ListView(
//      //padding: const EdgeInsets.all(8),
//    children: <Widget>[
//      Container(
//        //padding: const EdgeInsets.all(12.0),
//        child: ElevatedButton(
//          onPressed: () async {
//            //
//          },
//          child: Text(
//            'Scan QR code',
//          ),
//        ),
//      ),
//      Text(
//          'Note scanning a QR code from another device means you trust that device will not give you malicious content or abuse what you provide to them. Only scan a QR code from devices that you trust.'),
//      //ExpansionTile(
//      //  title: Text('Show QR code'),
//      //  subtitle: Text('This reveals IP and secret to allow connection'),
//      //  children: <Widget>[],
//      //),
//    ],
//  );
//}

Future<void> refrFileList() async {
  var newlist = <FileSystemEntity>[];
  await for (final entity
      in Directory(infoDir).list(recursive: true, followLinks: false)) {
    if (entity is Link) continue;
    if (entity is Directory) {
      newlist.add(entity);
      continue;
    }
    File ifile = entity as File;
    File ffile = getFileFromInfo(ifile);
    if (await ifile.length() == 0) {
      continue;
    }
    if (!await ffile.exists()) {
      continue;
    }
    newlist.add(entity);
  }
  filelist = newlist;
  myhome.setStatePublic();
}

//Future<void> newFolder(String titleStr) async {
//  //
//}

ExpansionTile mkETDir(String dispPath) {
  return ExpansionTile(
    onExpansionChanged: (change) {
      myhome.unsetDirScan(dispPath);
    },
    title: Text(dispPath),
    subtitle: Text('DIR'),
    children: <Widget>[
      //ElevatedButton(
      //  onPressed: () async {
      //    //
      //  },
      //  child: Text(
      //    'Create new folder',
      //  ),
      //),
      ElevatedButton(
        onPressed: dispPath == '/'
            ? null
            : () async {
                //fixme ? handle possible concurrent modification?
                await Directory(fileDir + dispPath).delete(recursive: true);
                await Directory(infoDir + dispPath).delete(recursive: true);
                await refrFileList();
              },
        child: Text(
          'Delete DIR',
        ),
      ),
      myhome.getDirScan(dispPath)
          ? LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SizedBox(
                  height: constraints.maxWidth,
                  child: MobileScanner(
                    onDetect: (capture) {
                      final lst = capture.barcodes;
                      myhome.unsetDirScan(dispPath);
                      if (lst.isEmpty) return;
                      final codeData = lst.first.rawValue ?? '';
                      if ('' == codeData) return;
                      final qrdata = mkQrData(codeData);
                      () async {
                        await downloadFile(qrdata, dispPath);
                        await refrFileList();
                      }();
                    },
                  ),
                );
              },
            )
          : ElevatedButton(
              onPressed: () async {
                myhome.setDirScan(dispPath);
              },
              child: Text(
                'Scan QR code to fetch file into this DIR',
              ),
            ),
      ElevatedButton(
        onPressed: () async {
          FilePickerResult? result = await FilePicker.platform
              .pickFiles(withData: false, withReadStream: true);
          if (null == result || result.files.isEmpty) return;
          final file = result!.files.first;
          final stre = file.readStream;
          if (null == stre) return;
          await writeStreamToFile(ppath.join(dispPath, file.name), stre!);
          await refrFileList();
        },
        child: Text(
          'Get file from device storage',
        ),
      ),
    ],
  );
}

ListView mkFileList(BuildContext context) {
  var wlst = <Widget>[];
  wlst.add(mkETDir('/'));
  for (FileSystemEntity fse in filelist) {
    Widget newWg;
    if (fse is Directory) {
      newWg = mkETDir(getInfoDisplayPath(fse));
    } else {
      final dpath = getInfoDisplayPath(fse);
      //bool showQR = false;
      newWg = ExpansionTile(
        onExpansionChanged: (change) {
          myhome.unsetFileQR(dpath);
        },
        key: ValueKey(dpath),
        title: Text(dpath),
        subtitle: Text('FILE'),
        children: <Widget>[
          ElevatedButton(
            onPressed: () async {
              await File(fileDir + dpath).delete();
              await File(infoDir + dpath).delete();
              await refrFileList();
            },
            child: Text(
              'Delete',
            ),
          ),
          //showQR
          myhome.getFileQR(dpath)
              ? QrImageView(
                  data: mkFileDataQR(dpath),
                  version: QrVersions.auto,
                )
              : ElevatedButton(
                  onPressed: () async {
                    //showQR = true;
                    //myhome.setStatePublic();
                    myhome.setFileQR(dpath);
                  },
                  child: Text(
                    'Show QR code for this file',
                  ),
                ),
          ElevatedButton(
            onPressed: () async {
              String? selectedDirectory =
                  await FilePicker.platform.getDirectoryPath();
              if (selectedDirectory == null) return;
              await File(fileDir + dpath)
                  .copy(ppath.join(selectedDirectory, ppath.basename(dpath)));
            },
            child: Text(
              'Copy file to device storage',
            ),
          ),
        ],
      );
    }
    wlst.add(newWg);
    //wlst.add(Text(fse.path));
  }
  return ListView(
    children: wlst,
  );
}

void defOnData(HttpRequest req) async {
  try {
    //if(serverDisabled) {
    //  req.response.close();
    //  return;
    //}
    //++numOfReq;
    //todo if too many requests within a period of time, lock the app
    bool xsecProblem = false;
    switch (req.method) {
      case 'GET':
        if ('' != secret) {
          xsecProblem = true;
          final xsec = req.headers['x-sec'];
          if (xsec == null) break;
          if (xsec.isEmpty) break;
          if (xsec[0] != secret) break;
          xsecProblem = false;
        }
        ////pathSegments
        ////note req.requestUri calls req.uri
        //switch (req.uri.path) {
        //  case '/':
        //    req.response.headers.contentType = ContentType.html;
        //    req.response.write(
        //        '<!DOCTYPE html><html><head><meta charset="utf-8" /><title>Test conn</title></head><body>Test connection</body></html>');
        //    break;
        //  case '/cer':
        //    req.response.headers.contentType = ContentType.binary;
        //    req.response.add(cerBytes);
        //    break;
        //  default:
        //    break; //throw CommonException('Unexpected path');
        //}
        req.response.headers.contentType = ContentType.text;
        req.response.add(await readOldLogAsBytes());
        req.response.add(await readLogAsBytes());
        break;
      case 'POST':
        final rpath = ppath.canonicalize(req.uri.path);
        switch (rpath) {
          case '/':
            req.response.headers.contentType = ContentType.json;
            req.response.write('{"ch":${jsonEncode(certHash)} }');
            break;
          default:
            if ('' != secret) {
              xsecProblem = true;
              final xsec = req.headers['x-sec'];
              if (xsec == null) break;
              if (xsec.isEmpty) break;
              if (xsec[0] != secret) break;
              xsecProblem = false;
            }
            if ('/' != rpath[0]) break;
            //req.uri.path.split('/')
            //req.uri.path.substring(1)
            final infoPath = infoDir + rpath;
            final filePath = fileDir + rpath;
            final infoFile = File(infoPath);
            final fileFile = File(filePath);
            if (await infoFile.exists() && await infoFile.length() == 0) {
              req.response.headers.contentType = ContentType.text;
              req.response.write(
                  'Conflict of 2 requests doing concurrent writing into one file.');
              break;
            }
            //bool oldFileDeleted = false;
            IOSink? sink = null;
            try {
              await for (final chunk in req) {
                if (null == sink) {
                  if (chunk.isEmpty) continue;
                  if (await fileFile.exists()) {
                    await fileFile.delete(
                        recursive: true); //note even folder is deleted
                  }
                  if (await infoFile.exists()) {
                    await infoFile.delete(
                        recursive: true); //note even folder is deleted
                  }
                  //info MUST be created BEFORE file!!
                  await infoFile.create(recursive: true, exclusive: true);
                  await fileFile.create(recursive: true, exclusive: true);
                  sink = fileFile.openWrite(mode: FileMode.writeOnly);
                  //oldFileDeleted = true;
                }
                sink!.add(chunk);
                await sink!.flush();
              }
            } finally {
              if (sink != null) await sink!.close();
            }
            if (sink != null) {
              await infoFile.writeAsString("{}");
              req.response.headers.contentType = ContentType.text;
              req.response.write('OK');
              /*await*/ refrFileList();
            } else {
              if (await fileFile.exists()) {
                //? should use some kind of locking/RWLock/mutex to prevent other requests to touch the file? necessary?
                final stre = fileFile.openRead();
                req.response.headers.contentType = ContentType.binary;
                await for (final chunk in stre) {
                  req.response.add(chunk);
                }
              } else {
                req.response.statusCode = 404;
                req.response.headers.contentType = ContentType.text;
              }
            }
            break;
        }
        break;
      default:
        break;
      //throw CommonException('Unexpected method');
    }
    if (xsecProblem) {
      req.response.statusCode = 403;
    }
    await req.response.flush();
  } catch (err, stackTrace) {
    //writeErrorToResp(req.response);
    inLog('Caught error: $err');
    inLog(stackTrace);
  }
  await req.response.close();
}

void calcCertHash() {
  X509CertificateData cert =
      X509Utils.x509CertificateFromPem(utf8.decode(cerBytes));
  var blob = hex.decode(cert.tbsCertificate!.subjectPublicKeyInfo.bytes!);
  var digest = sha256.convert(blob);
  certHash = base64Encode(digest.bytes);
//	utf8.decode(cerBytes)
//	var digest = sha256.convert(listOfInt);
//	certHash = base64Encode(digest.bytes);
}

ListView mkSec(BuildContext context) {
  return ListView(
    padding: const EdgeInsets.all(8),
    children: <Widget>[
      TextFormField(
        initialValue: secret,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Secret',
        ),
        onChanged: (String sec) async {
          secret = sec;
          await secFile!.writeAsString(sec);
        },
      ),
      const Text(
          "A secret value set here will prevent people who do not know the secret from reading/writing your files. Please do not reuse any password you used before."),
    ],
  );
}

Future<void> deleteCorruptFiles() async {
  await for (final entity
      in Directory(infoDir).list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    File ifile = entity as File;
    File ffile = getFileFromInfo(ifile);
    if (await ifile.length() == 0) {
      if (await ffile.exists()) {
        await ffile.delete();
      }
      await ifile.delete();
    } else {
      if (!await ffile.exists()) {
        await ifile.delete();
      }
    }
  }
}

String getInfoDisplayPath(FileSystemEntity fse) {
  return fse.path.substring(infoDir.length);
}

Widget getInfoDisplayPathWg(FileSystemEntity fse) {
  return Text(getInfoDisplayPath(fse));
}

File getFileFromInfo(File ifile) {
  return File(fileDir + ifile.path.substring(infoDir.length));
}

File getLogFile() {
  return File(ppath.join(appSuppDir.path, 'log'));
}

File getOldLogFile() {
  return File(ppath.join(appSuppDir.path, 'oldlog'));
}

Future<Uint8List> readLogAsBytes() async {
  final obj = getLogFile();
  if (await obj.exists()) {
    return await obj.readAsBytes();
  }
  return Uint8List(0);
}

Future<Uint8List> readOldLogAsBytes() async {
  final obj = getOldLogFile();
  if (await obj.exists()) {
    return await obj.readAsBytes();
  }
  return Uint8List(0);
}

void inLog(Object object) {
  if (null == logFile) return;
  logFile!.writeln(object);
  /*await*/ logFile!.flush();
}
