import 'dart:math';
import 'package:flutter/material.dart';
import 'package:indoor_nav2/SelectBondedDevicePage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:collection';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:downloads_path_provider/downloads_path_provider.dart';

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

  String current_pos = "1 1";
  String destination = "none";
  String route = "";
  bool isNav = false;
  bool isHold = false;

  List<List<String>> gridState = [
    // ['#', '#', '#', '#', '#', '#', '#', '#', '#', '#', '#', '#'],
    // ['#', 'C', ' ', ' ', '#', ' ', ' ', '4', '4', ' ', '5', '#'],
    // ['#', ' ', ' ', ' ', '#', ' ', ' ', ' ', ' ', ' ', ' ', '#'],
    // ['#', ' ', ' ', ' ', '#', ' ', ' ', ' ', ' ', ' ', ' ', '#'],
    // ['#', ' ', ' ', ' ', ' ', '#', ' ', ' ', ' ', '3', ' ', '#'],
    // ['#', ' ', ' ', ' ', ' ', '#', ' ', ' ', ' ', '3', ' ', '#'],
    // ['#', ' ', ' ', ' ', ' ', '#', ' ', ' ', '3', '3', ' ', '#'],
    // ['#', '2', '2', '2', ' ', '#', ' ', ' ', '3', '3', ' ', '#'],
    // ['#', '2', '2', '2', ' ', ' ', ' ', ' ', ' ', ' ', ' ', '#'],
    // ['#', '1', '1', ' ', ' ', '#', ' ', ' ', ' ', ' ', ' ', '#'],
    // ['#', '1', '1', ' ', ' ', '#', ' ', ' ', ' ', ' ', ' ', '#'],
    // ['#', '#', '#', '#', '#', '#', '#', '#', '#', '#', '#', '#'],

    ['#', '#', '#', '#', '#', '#', '#', '#'],
    ['#', 'C', ' ', ' ', ' ', ' ', ' ', '#'],
    ['#', ' ', ' ', '#', ' ', '#', '3', '#'],
    ['#', ' ', ' ', '4', ' ', ' ', ' ', '#'],
    ['#', ' ', '#', ' ', ' ', '#', ' ', '#'],
    ['#', ' ', '#', '1', ' ', '#', ' ', '#'],
    ['#', ' ', '#', ' ', '#', ' ', '2', '#'],
    ['#', '#', '#', '#', '#', '#', '#', '#']
  ];



  void bfs(int start_x, int start_y, String dest, int n, int m) {
    // print(destination);
    int flag = 1;
    List<int> dx = [-1, 0, 0, 1];
    List<int> dy = [0, 1, -1, 0];
    String dz = "NEWS";
    List<List<bool>> vis = List.generate(
        n + 2, (i) => List.filled(m + 2, false, growable: false),
        growable: false);
    Map<String, String> mp = {};
    vis[start_x][start_y] = true;
    mp['$start_x $start_y'] = "";
    Queue<String> v = new Queue<String>();
    v.add('$start_x $start_y');

    while (!v.isEmpty) {
      List<String> parts = v.first.split(' ');
      start_x = int.parse(parts[0]);
      start_y = int.parse(parts[1]);
      v.removeFirst();

      for (int i = 0; i < 4; ++i) {
        if ((gridState[start_x + dx[i]][start_y + dy[i]] == ' ' ||
                gridState[start_x + dx[i]][start_y + dy[i]] == 'D') &&
            !vis[start_x + dx[i]][start_y + dy[i]]) {
          vis[start_x + dx[i]][start_y + dy[i]] = true;
          v.add('${start_x + dx[i]} ${start_y + dy[i]}');
          mp['${start_x + dx[i]} ${start_y + dy[i]}'] = mp['$start_x $start_y'];

          String modi = mp['${start_x + dx[i]} ${start_y + dy[i]}'] + dz[i];

          mp['${start_x + dx[i]} ${start_y + dy[i]}'] = modi;
        }
      }
    }

    // print(mp[Pair(end_x, end_y)]);
    // print(route.length);

    // for (int i = 0; i < n; i++) {
    //   for (int j = 0; j < m; j++) {
    //     if(gridState[i][j] == ' ')
    //       {print(mp["${i} ${j}"]);
          
    //       if(mp["${i} ${j}"] == null)
    //       print("$i $j");
    //       }

          
    //   }
    //   }


    for (int i = 0; i < n; i++) {
      for (int j = 0; j < m; j++) {
        if (gridState[i][j] == dest) {
          if (gridState[i + 1][j] == " " && mp["${i + 1} ${j}"] != null) {
            if (route == "" || route.length > mp["${i + 1} ${j}"].length) {
              route = mp["${i + 1} ${j}"];
            }
          }

          if (gridState[i][j + 1] == " " && mp["${i} ${j + 1}"] != null) {
            if (route == "" || route.length > mp["${i} ${j + 1}"].length) {
              route = mp["${i} ${j + 1}"];
            }
          }

          if (gridState[i - 1][j] == " " && mp["${i - 1} ${j}"] != null) {
            if (route == "" || route.length > mp["${i - 1} ${j}"].length) {
              route = mp["${i - 1} ${j}"];
            }
          }

          if (gridState[i][j - 1] == " " && mp["${i} ${j - 1}"] != null) {
            if (route == "" || route.length > mp["${i} ${j - 1}"].length) {
              route = mp["${i} ${j - 1}"];
            }
          }
        }
      }
    }

    print(route);
    // return route;
  }

  void _write(String text) async{
    final Directory dir = await DownloadsPathProvider.downloadsDirectory;
    
    File file = File("${dir.path}/mo.txt");
    await file.writeAsString(text);
  }
  void bfsRun(int n)
  {
    // print(n);
    gridState = List.generate(
        n, (i) => List.filled(n, ' ', growable: false),
        growable: false);

    
    for(int j = 0; j < gridState.length; j++)
    {
      gridState[0][j] = '#';
      gridState[gridState.length - 1][j] = '#'; 
    }

    for(int i = 0; i < gridState.length; i++)
    {
      gridState[i][0] = '#';
      gridState[i][gridState.length - 1] = '#'; 
    }

    gridState[gridState.length - 2][gridState.length - 2] = '1'; 

    
    final stopwatch = Stopwatch();
    stopwatch.start();
    // print(gridState);
    bfs(1, 1, '1', n-2, n-2);
    stopwatch.stop();
    
    int a7o = stopwatch.elapsedMilliseconds;
    
    print('$n, ${a7o}');
    
    _write('$n, ${a7o}\n');
    
  }

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

  Widget _buildGridItem(int x, int y) {
    if (gridState[x][y] == destination) {
      return Container(
        color: Colors.red,
      );
    }

    switch (gridState[x][y]) {
      case 'C':
        return Container(
          color: Colors.blue,
        );
        break;
      case '':
        return Text('');
        break;
      case 'O':
        return Container(
          color: Colors.yellow,
        );
        break;
      case '#':
        return Container(
          color: Colors.black,
        );
        break;
      case 'R':
        return Container(
          color: isHold ? Colors.grey : Colors.green,
        );
        break;
      case 'B':
        return Icon(Icons.remove_red_eye, size: 40.0);
        break;
      default:
        return Text(gridState[x][y].toString());
    }
  }

  Widget _buildGridItems(BuildContext context, int index) {
    int gridStateLength = gridState.length;
    int x, y = 0;
    x = (index / gridStateLength).floor();
    y = (index % gridStateLength);
    return GestureDetector(
      onTap: () {
        // print(bfs(1, 1, x, y, 10, 10));

        List<String> parts = current_pos.split(' ');
        int start_x = int.parse(parts[0]);
        int start_y = int.parse(parts[1]);

        if (start_x == x && start_y == y) {
        } else if (!isNav) {
          if (gridState[x][y] != "#" &&
              gridState[x][y] != " " &&
              gridState[x][y] != "C") {
            // if (destination == "none") {
            //   gridState[x][y] = "D";
            //   destination = "$x $y";
            // } else {
            //   parts = destination.split(' ');
            //   start_x = int.parse(parts[0]);
            //   start_y = int.parse(parts[1]);

            //   gridState[start_x][start_y] = " ";
            //   gridState[x][y] = "D";
            //   destination = "$x $y";
            // }

            route = "";
            destination = gridState[x][y];

            parts = current_pos.split(' ');
            start_x = int.parse(parts[0]);
            start_y = int.parse(parts[1]);

            // parts = destination.split(' ');
            // int end_x = int.parse(parts[0]);
            // int end_y = int.parse(parts[1]);

            // print(bfs(start_x, start_y, end_x, end_y, 10, 10));
            // route = bfs(start_x, start_y, end_x, end_y, 10, 10);
          }
        }

        // if (start_x == x && start_y == y || gridState[x][y] != " " || isNav) {
        // } else {
        //   if (destination == "") {
        //     gridState[x][y] = "D";
        //     destination = "$x $y";
        //   } else {
        //     parts = destination.split(' ');
        //     start_x = int.parse(parts[0]);
        //     start_y = int.parse(parts[1]);

        //     gridState[start_x][start_y] = " ";
        //     gridState[x][y] = "D";
        //     destination = "$x $y";
        //   }

        //   parts = current_pos.split(' ');
        //   start_x = int.parse(parts[0]);
        //   start_y = int.parse(parts[1]);

        //   parts = destination.split(' ');
        //   int end_x = int.parse(parts[0]);
        //   int end_y = int.parse(parts[1]);

        // }

        print('${x} ${y}');
        setState(() {
          // print(bfs(1, 1, x, y, 10, 10));
          // gridState[x][y] = 'P1';
          print(destination);
          // print(bfs(start_x, start_y, gridState[x][y], 10, 10));
          bfs(start_x, start_y, destination, 6, 6);
        });

        // _gridItemTapped(x, y)
      },
      child: GridTile(
        child: Container(
          decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 0.5)),
          child: Center(
            child: _buildGridItem(x, y),
          ),
        ),
      ),
    );
  }

  Widget _buildGameBody() {
    int gridStateLength = gridState.length;
    return Column(children: <Widget>[
      AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          padding: const EdgeInsets.all(8.0),
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2.0),
              color: Colors.white),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridStateLength,
            ),
            itemBuilder: _buildGridItems,
            itemCount: gridStateLength * gridStateLength,
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext ctx) {
    double relHeight = MediaQuery.of(ctx).size.height;
    double relWidth = MediaQuery.of(ctx).size.width;

    return SafeArea(
        child: Scaffold(
            backgroundColor: Color.fromRGBO(226, 215, 228, 1.0),
            body: Container(
                width: double.infinity,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: relHeight * 0.03),
                      Container(
                          height: relHeight * 0.05,
                          child: Text(
                            "AUTOCAR Indoor Navigator",
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold),
                          )),
                      Container(
                        width: relWidth * 0.88,
                        height: relHeight * 0.1,
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

                                  // for(int i = 4; i <= 10000; i++)
                                  // {
                                  //   bfsRun(i);
                                  // }
                                },
                              )
                            ]),
                      ),
                      SizedBox(height: relHeight * 0.01),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        width: relWidth * 0.9,
                        height: relHeight * 0.5,
                        decoration: BoxDecoration(
                            color: Color.fromRGBO(87, 5, 137, 1.0),
                            borderRadius: BorderRadius.circular(40)),
                        child: Column(children: [
                          SizedBox(
                            height: 18,
                          ),
                          Text("Route...",
                              style: TextStyle(
                                  color: Color.fromRGBO(226, 215, 228, 1.0),
                                  fontSize: 18)),
                          SizedBox(
                            height: 18,
                          ),
                          Container(
                              height: relHeight * 0.35,
                              width: relWidth * 0.74,
                              child: _buildGameBody()),
                          SizedBox(
                            height: 5,
                          ),
                          ElevatedButton(
                              onPressed: () {
                                if (isNav) {
                                  isNav = false;
                                  isHold = false;
                                  route = "";
                                  destination = "";
                                  for (int i = 0; i < gridState.length; i++) {
                                    for (int j = 0;
                                        j < gridState[i].length;
                                        j++) {
                                      gridState[i][j] == "R"
                                          ? gridState[i][j] = " "
                                          : null;
                                    }
                                  }

                                  _sendMessage("F");
                                  setState(() {});
                                } else if (route != "") {
                                  List<String> parts = current_pos.split(' ');
                                  int start_x = int.parse(parts[0]);
                                  int start_y = int.parse(parts[1]);

                                  for (int i = 0; i < route.length; i++) {
                                    if (route[i] == "N") {
                                      start_x--;
                                      gridState[start_x][start_y] = "R";
                                    } else if (route[i] == "S") {
                                      start_x++;
                                      gridState[start_x][start_y] = "R";
                                    } else if (route[i] == "E") {
                                      start_y++;
                                      gridState[start_x][start_y] = "R";
                                    } else if (route[i] == "W") {
                                      start_y--;
                                      gridState[start_x][start_y] = "R";
                                    }
                                  }

                                  isNav = true;

                                  _sendMessage(route);
                                  setState(() {});
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                  primary: Color.fromRGBO(226, 215, 228, 1.0),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20))),
                              child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                  child: Text(isNav ? "Stop" : "Navigate",
                                      style: TextStyle(
                                          color:
                                              Color.fromRGBO(87, 5, 137, 1.0),
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold))))
                        ]),
                      ),
                      SizedBox(
                        height: relHeight * 0.01,
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () {
                          isNav ? isHold = !isHold : null;

                          isNav
                              ? isHold
                                  ? _sendMessage("H")
                                  : _sendMessage("C")
                              : null;
                          setState(() {});
                        },
                        child: Ink(
                            width: relWidth * 0.9,
                            height: relHeight * 0.07,
                            decoration: BoxDecoration(
                                color: Color.fromRGBO(87, 5, 137, 1.0),
                                borderRadius: BorderRadius.circular(30)),
                            child: Center(
                                child: Text(isHold ? "Continue" : "Hold",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)))),
                      ),
                      SizedBox(
                        height: relHeight * 0.01,
                      ),
                      Container(
                        width: relWidth * 0.9,
                        height: relHeight * 0.15,
                        decoration: BoxDecoration(
                            color: Color.fromRGBO(87, 5, 137, 1.0),
                            borderRadius: BorderRadius.circular(40)),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 15),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text("Nearest destination: Bed1",
                              //     style: TextStyle(
                              //         color: Colors.redAccent,
                              //         fontSize: 15,
                              //         fontWeight: FontWeight.bold)),
                              // SizedBox(height: 10),
                              Text("Navigating to: $destination",
                                  style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 10),
                              Text("Voice msg: Keep going straight",
                                  style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold))
                            ],
                          ),
                        ),
                      ),
                    ]))));
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
      if (arduinoData.length == 7) {
        print("True");

        List<String> parts = arduinoData.split(' ');
        String obstacle = parts[0];
        int start_x = int.parse(parts[1]);
        int start_y = int.parse(parts[2]);

        gridState[start_x][start_y] = 'C';

        if (obstacle == "N") {
          gridState[start_x-1][start_y] = "O";
        } else if (obstacle == "S") {
          gridState[start_x+1][start_y] = "O";
        } else if (obstacle == "E") {
          gridState[start_x][start_y+1] = "O";
        } else if (obstacle == "W") {
          gridState[start_x][start_y-1] = "O";
        }

        parts = current_pos.split(' ');
        gridState[int.parse(parts[0])][int.parse(parts[1])] = ' ';

        current_pos = '$start_x $start_y';
      }
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
