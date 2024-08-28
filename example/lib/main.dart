import 'package:flutter/material.dart';
import 'dart:async';

import 'package:rcldart/rcldart.dart' as rcldart;
import 'package:rcldart/rcldart.dart';
import 'package:rcldart/src/publisher.dart' as publish;

void main() {
  RclDart().init();
  var node = RclDart().createNode("rcldart_to_ros2", "rcldart");

  publish.Publisher publis = node.createPublisher(topic_name: "dart2ros");
  // pub.publish();
  runApp( MyApp(publisher: publis));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.publisher});
  final publish.Publisher? publisher;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late int sumResult;
  late Future<int> sumAsyncResult;

  @override
  void initState() {
    super.initState();
    // sumResult = rcldart.sum(1, 2);
    // sumAsyncResult = rcldart.sumAsync(3, 4);
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 25);
    const spacerSmall = SizedBox(height: 10);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('RCLDart for Ros2 Packages'),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                spacerSmall,
                // Text(
                //   'sum(1, 2) = $sumResult',
                //   style: textStyle,
                //   textAlign: TextAlign.center,
                // ),
                Center(child: 
                FloatingActionButton(child: Center(child: Icon(Icons.add),),onPressed: () {
                  widget.publisher!.publish();
                }),),
                //spacerSmall,
                // FutureBuilder<int>(
                //   future: sumAsyncResult,
                //   builder: (BuildContext context, AsyncSnapshot<int> value) {
                //     final displayValue =
                //         (value.hasData) ? value.data : 'loading';
                //     return Text(
                //       'await sumAsync(3, 4) = $displayValue',
                //       style: textStyle,
                //       textAlign: TextAlign.center,
                //     );
                //   },
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
