import 'dart:math';
import 'package:flutter/material.dart';
import 'package:indoor_nav2/SelectBondedDevicePage.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:collection';
import 'dart:io';


void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: FutureBuilder(
            future: FlutterBluetoothSerial.instance.requestEnable(),
            builder: (context, future) {
              if (future.connectionState == ConnectionState.waiting)
                MyApp();
              else if (future.connectionState == ConnectionState.done)
                return SelectBondedDevicePage();
            }));
  }
}

class Pair {
  final int first;
  final int second;

  Pair(this.first, this.second);

  @override
  int get hashCode => first.hashCode ^ second.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pair &&
          runtimeType == other.runtimeType &&
          first == other.first &&
          second == other.second;
}

class Home extends StatefulWidget {
  final BluetoothDevice server;

  const Home({this.server});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static final clientID = 0;
  BluetoothConnection connection;
  String arduinoData = "";

  bool isConnecting = true;
  bool get isConnected => connection != null && connection.isConnected;

  bool isDisconnecting = false;

  @override
  void initState() {
    super.initState();

    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');

      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection.input.listen(_onDataReceived).onDone(() {
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      // _controller.pause();
      // _controller2.pause();
      // _controller3.pause();
      connection.dispose();
      connection = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {

    return SafeArea(
        child: Scaffold(
            backgroundColor: Color.fromRGBO(226, 215, 228, 1.0),
            body: Container(
                width: double.infinity,
                child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              isConnecting
                                  ? Text("Connecting to HC-05...",
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold))
                                  : isConnected
                                      ? Text("Connected to HC-05",
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold))
                                      : Text("Disconnected to HC-05",
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: Icon(Icons.start, size: 40),
                                onPressed: () {
                                  // _sendMessage("1");
                                  // print(arduinoData);
                                },
                              )]))));
                         
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);
    print("Data: " + dataString);
    // _sendMessage("1");

    /* 
    Recieve code
    a = areator  t = temp  h = heater   r = arm  s = syr_pump  f = feeding  m = treatment   p = pH
    s
    0 12345  6 7 8 9 10  11 12 13 14
    a tt.tt h r s f m   p.pp

    */
    setState(() {
      arduinoData = dataString;
      // print(arduinoData.length);
      
    });
    // setState(()=>arduinoData=>dataString;);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      setState(() {});
    } else {}
  }

  void _sendMessage(String text) async {
    text = text.trim();

    if (text.length > 0) {
      try {
        connection.output.add(utf8.encode(text + "\r\n"));
        await connection.output.allSent;

        setState(() {});

        Future.delayed(Duration(milliseconds: 333)).then((_) {});
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }
}
