import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:image/image.dart' as image;
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:basic_utils/basic_utils.dart';

import 'package:door/doors.dart';

// ==========main==========

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setUpDoors();
  runApp(const MyApp());
}

Future<void> setUpDoors() async {
  Door door1 = Door();
  Door door2 = Door();

  door1.setName("door1");
  door1.setSecret(await loadSecret("assets/images/door1_secret.png"));
  door1.setShare1(await loadShare1("assets/images/door1_share1.png"));

  door2.setName("door2");
  door2.setSecret(await loadSecret("assets/images/door2_secret.png"));
  door2.setShare1(await loadShare1("assets/images/door2_share1.png"));

  doors.addDoor(door1);
  doors.addDoor(door2);
  currentDoor = doors.getDoor("door1")!;
}

Future<Uint8List> loadShare1(String path) async {
  Uint8List inputImg = (await rootBundle.load(path)).buffer.asUint8List();
  String binaries = image.decodeImage(inputImg)!
      .getBytes(format: image.Format.luminance)
      .map((e) => e == 0 ? 0 : 1)
      .join();

  List<int> buf = List.filled(200, 0);
  for(int i = 0; i < 200; i++){
    buf[i] = int.parse(StringUtils.reverse(binaries.substring(i * 8, i * 8 + 8)), radix: 2);
  }

  return Uint8List.fromList(buf);
}

Future<String> loadSecret(String path) async {
  Uint8List inputImg = (await rootBundle.load(path)).buffer.asUint8List();
  String binaries = image.decodeImage(inputImg)!
      .getBytes(format: image.Format.luminance)
      .map((e) => e == 0 ? 0 : 1)
      .join();

  String buf = "";
  for(int i = 0; i < 100; i++){
    buf += StringUtils.reverse(binaries.substring(i * 4, i * 4 + 4));
  }

  return buf;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: const DoorApp(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==========main==========

// ==========DoorApp==========

class DoorApp extends StatefulWidget{
  const DoorApp({super.key});

  @override
  _DoorAppState createState() => _DoorAppState();
}

class _DoorAppState extends State<DoorApp>{

  late Timer _timer;
  bool _locked = true;

  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  int currentSeed = 0;


  @override
  void initState() {
    super.initState();
    seedRefresh();
    _timer = Timer.periodic(const Duration(seconds: 60), (Timer t) => seedRefresh());

  }

  void seedRefresh() {
    setState(() {
      currentSeed = DateTime.now().millisecondsSinceEpoch;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    controller?.pauseCamera();
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
      this.controller?.resumeCamera();
      this.controller?.flipCamera();
    });
    controller.scannedDataStream.listen((scanData) {
      if(_locked && scanData.code != null &&
          isCorrectKey(base64Decode(scanData.code!))){
        setState(() {
          _locked = false;
        });
        Timer.periodic(const Duration(seconds: 3), (timer) {
          setState(() {
            _locked = true;
            timer.cancel();
          });
        });
      }
    });
  }

  bool isCorrectKey(Uint8List xorShare2) {
    Uint8List share1 = currentDoor.getShare1();
    if(xorShare2.length != share1.length){
      return false;
    }

    Random random = Random(currentSeed);
    Uint8List share2 = Uint8List(200);
    for(int i = 0; i < 200; i++){
      share2[i] = xorShare2[i] ^ random.nextInt(256);
    }

    if(currentDoor.isForbidden(to20x20Binaries(share2))){
      return false;
    }

    Uint8List covered = Uint8List(200);
    for(int i = 0; i < 200; i++){
      covered[i] = share1[i] & share2[i];
    }

    return to20x20Binaries(covered) == currentDoor.getSecret();
  }

  String to20x20Binaries(Uint8List uint8list) {
    List<String> rows = List.filled(40, "");
    for(int row = 0; row < 40; row++){
      for(int byte = 0; byte < 5; byte++){
        rows[row] += uint8list[5 * row + byte].toRadixString(2).padLeft(8, "0");
      }
    }

    String binaries = "";
    for(int i = 0; i < 20; i++){
      for(int j = 0; j < 20; j++){
        int blackCount = 0;
        blackCount += rows[i * 2][j * 2]         == "0" ? 1 : 0;
        blackCount += rows[i * 2][j * 2 + 1]     == "0" ? 1 : 0;
        blackCount += rows[i * 2 + 1][j * 2]     == "0" ? 1 : 0;
        blackCount += rows[i * 2 + 1][j * 2 + 1] == "0" ? 1 : 0;
        binaries += blackCount == 4 ? "0" : "1";
      }
    }

    return binaries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _locked
      ? AppBar(
        backgroundColor: Colors.red[400],
        title: const Text(
          "Locked",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      )
      : AppBar(
        backgroundColor: Colors.green[400],
        title: const Text(
          "Pass!",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /*Flexible(
            child: Center(
              child: Row(
                children: [
                  const Text('Door: '),
                  DropdownButton(
                    value: currentDoor.getName(),
                    items: doors.listAllDoors()
                        .map((String doorName) => DropdownMenuItem(
                          value: doorName,
                          child: Text(doorName)
                        ))
                        .toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          currentDoor = doors.getDoor(newValue)!;
                        });
                      }
                    },
                  ),
                ],
              ),
            )
          ),*/
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: QrImage(
                  data: "d=${currentDoor.getName()}&s=$currentSeed",
                  version: 10,
                  errorCorrectionLevel: QrErrorCorrectLevel.L,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                // full screen
                borderColor: Theme.of(context).primaryColor,
                borderRadius: 0,
                borderLength: 0,
                borderWidth: 0,
                cutOutWidth: MediaQuery.of(context).size.width,
                cutOutHeight: MediaQuery.of(context).size.height,
              ),
            ),
          ),
        ],
      )
    );
  }
}

// ==========DoorApp==========