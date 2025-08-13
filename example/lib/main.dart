// example/lib/main.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

import 'package:ffi/ffi.dart' as ffi;
import 'package:rcldart/rcldart.dart' as rcldart;
import 'package:rcldart/src/publisher.dart' as publish;
import 'package:rcldart/src/subscriber.dart' as rclsubscriber;

import 'package:rcldart/src/node.dart';
import "package:rcldart_utils/rcldart_utils.dart";
import "package:std_msgs/std_msgs.dart";

// Global subscriber reference for UI updates

late rclsubscriber.Subscriber globalStringSubscriber;
late rclsubscriber.Subscriber globalFloat32Subscriber;
late rclsubscriber.Subscriber globalFloat64Subscriber;

late StreamController<dynamic> stringMessageStreamController;

void main() {
  // ROS2 initialization
  rcldart.RclDart().init();
  var node = rcldart.RclDart().createNode("flutter_node", "examples");
  
  // Initialize stream controller for received messages
  stringMessageStreamController = StreamController<String>.broadcast();

  // Create subscriber with callback
   globalStringSubscriber = node.createSubscriber<StdMsgsString>(
      topic_name: "/chatter",
      messageType: StdMsgsString(""),
      callback: (msg) {
        // print("📨 Received message: ${msg.data}");

        print("📦 Raw message data: ${msg.value}"); // Access the data field directly
        // Add message to stream for UI updates
        stringMessageStreamController.add(msg.value);
      }
    );


  // Create FLOAT32 subscriber
  globalFloat32Subscriber = node.createSubscriber<StdMsgsFloat32>(
    topic_name: "/std_msgs/float32",
    messageType: StdMsgsFloat32(0.0),
    callback: (msg) {
      try {
        // Direct access to float32 data from native memory
        double receivedFloat = msg.value;
        print("📊 Float32 message: $receivedFloat");
        stringMessageStreamController.add(receivedFloat.toString());
      } catch (e) {
        print("Error reading float32 message: $e");
      }
    }
  );

  // Create FLOAT64 subscriber
  globalFloat64Subscriber = node.createSubscriber<StdMsgsFloat64>(
    topic_name: "/std_msgs/float64",
    messageType: StdMsgsFloat64(0.0),
    callback: (msg) {
      try {
        // Direct access to float64 data from native memory
        double receivedDouble = msg.value;
        print("📈 Float64 message: $receivedDouble");
        // float64MessageStreamController.add(receivedDouble);

        stringMessageStreamController.add(receivedDouble.toString());
      } catch (e) {
        print("Error reading float64 message: $e");
      }
    }
  );
  
  // Subscribe to all topics
  globalStringSubscriber.subscribe();
  globalFloat32Subscriber.subscribe();
  globalFloat64Subscriber.subscribe();
  

  print("Subscriber created and listening on /chatter");

  // Start background polling - mais menos frequently to avoid crash
  _startBackgroundPolling();

  // Create publishers for all std_msgs types
  var publishers = StdMsgsPublishers(node);
  
  runApp(StdMsgsApp(publishers: publishers));
}

// Background polling with reduced frequency and error handling
void _startBackgroundPolling() {
  Timer.periodic(Duration(milliseconds: 500), (timer) { // Reduced frequency from 100ms to 500ms
    try {
      // Check if globalStringSubscriber is still valid
      if (globalStringSubscriber != null) {
        var message = globalStringSubscriber.take();
        var message1 = globalFloat32Subscriber.take();
        var message2 = globalFloat64Subscriber.take();
        // Message handling is done via callback, no need to do anything here
        // if (message != null) {
        //   print("Polling caught message: ${message.data}");
        // }
      }
    } catch (e) {
      print("Error in polling: $e");
      // Don't cancel timer on error, just log it
    }
  });
}

class StdMsgsApp extends StatelessWidget {
  final StdMsgsPublishers publishers;
  
  const StdMsgsApp({super.key, required this.publishers});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROS2 Flutter App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StdMsgsHomePage(publishers: publishers),
    );
  }
}

class StdMsgsHomePage extends StatefulWidget {
  final StdMsgsPublishers publishers;
  
  const StdMsgsHomePage({super.key, required this.publishers});

  @override
  State<StdMsgsHomePage> createState() => _StdMsgsHomePageState();
}

class _StdMsgsHomePageState extends State<StdMsgsHomePage> with TickerProviderStateMixin {
  // Message values for all types
  final MessageValues _values = MessageValues();
  
  // UI state
  int _messageCounter = 0;
  Timer? _autoTimer;
  bool _isAutoPublishing = false;
  late TabController _tabController;
  
  // Received messages display
  List<dynamic> _receivedMessages = [];
  late StreamSubscription<dynamic> _messageSubscription;

  // Random generator
  final Random _random = Random();
  final List<String> _sampleMessages = [
    "Hello from Flutter to ROS2!",
    "Dart language is awesome!",
    "ROS2 integration successful",
    "std_msgs test message",
    "Robots are coming!",
    "Cross-platform publishing",
    "Real-time data stream",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // Added one more tab for received messages
    
    // Listen to received messages stream
    _messageSubscription = stringMessageStreamController.stream.listen((message) {
      if (mounted) {
        setState(() {
          _receivedMessages.insert(0, "${DateTime.now().toString().substring(11, 19)}: ${message.toString()}"); // Add timestamp
          // Keep only last 10 messages
          if (_receivedMessages.length > 10) {
            _receivedMessages.removeLast();
          }
        });
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print("ROS2 std_msgs Publisher UI loaded successfully");
      }
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _autoTimer = null;
    _isAutoPublishing = false;
    _tabController.dispose();
    _messageSubscription.cancel();
    
    print("StdMsgsApp disposed - timers stopped");
    super.dispose();
  }

  // Publishing methods for each category
  void _publishPrimitives() {
    if (!mounted) return;
    
    try {
      widget.publishers.publishBool(_values.boolValue);
      widget.publishers.publishByte(_values.byteValue);
      widget.publishers.publishChar(_values.charValue);
      
      setState(() => _messageCounter++);
      _showSnackBar("Primitive types published successfully");
      print("Published primitives: bool=${_values.boolValue}, byte=${_values.byteValue}, char=${_values.charValue}");
    } catch (e) {
      _showSnackBar("Error publishing primitives: $e", isError: true);
    }
  }

  void _publishIntegers() {
    if (!mounted) return;
    
    try {
      widget.publishers.publishInt8(_values.int8Value);
      widget.publishers.publishInt16(_values.int16Value);
      widget.publishers.publishInt32(_values.int32Value);
      widget.publishers.publishInt64(_values.int64Value);
      widget.publishers.publishUInt8(_values.uint8Value);
      widget.publishers.publishUInt16(_values.uint16Value);
      widget.publishers.publishUInt32(_values.uint32Value);
      widget.publishers.publishUInt64(_values.uint64Value);
      
      setState(() => _messageCounter++);
      _showSnackBar("Integer types published successfully");
      print("Published integers: int8=${_values.int8Value}, int16=${_values.int16Value}, int32=${_values.int32Value}, int64=${_values.int64Value}");
      print("Published uints: uint8=${_values.uint8Value}, uint16=${_values.uint16Value}, uint32=${_values.uint32Value}, uint64=${_values.uint64Value}");
    } catch (e) {
      _showSnackBar("Error publishing integers: $e", isError: true);
    }
  }

  void _publishFloats() {
    if (!mounted) return;
    
    try {
      widget.publishers.publishFloat32(_values.float32Value);
      widget.publishers.publishFloat64(_values.float64Value);
      
      setState(() => _messageCounter++);
      _showSnackBar("Float types published successfully");
      print("Published floats: float32=${_values.float32Value}, float64=${_values.float64Value}");
    } catch (e) {
      _showSnackBar("Error publishing floats: $e", isError: true);
    }
  }

  void _publishComplex() {
    if (!mounted) return;
    
    try {
      widget.publishers.publishString(_values.stringValue);
      widget.publishers.publishColorRGBA(_values.colorR, _values.colorG, _values.colorB, _values.colorA);
      widget.publishers.publishTime(_values.timeSec, _values.timeNanosec);
      widget.publishers.publishDuration(_values.durationSec, _values.durationNanosec);
      widget.publishers.publishHeader(_values.frameId);
      widget.publishers.publishEmpty();
      
      setState(() => _messageCounter++);
      _showSnackBar("Complex types published successfully");
      print("Published complex: string='${_values.stringValue}', color=(${_values.colorR},${_values.colorG},${_values.colorB},${_values.colorA})");
      print("Published time: ${_values.timeSec}.${_values.timeNanosec}, duration: ${_values.durationSec}.${_values.durationNanosec}");
    } catch (e) {
      _showSnackBar("Error publishing complex types: $e", isError: true);
    }
  }

  void _publishAllTypes() {
    if (!mounted) return;
    
    _publishPrimitives();
    _publishIntegers();
    _publishFloats();
    _publishComplex();
    _showSnackBar("All std_msgs types published!");
    print("=== ALL std_msgs TYPES PUBLISHED ===");
  }

  void _randomizeValues() {
    if (!mounted) return;
    
    setState(() {
      // Primitives
      _values.boolValue = _random.nextBool();
      _values.byteValue = _random.nextInt(256);
      _values.charValue = _random.nextInt(128);
      
      // Integers
      _values.int8Value = _random.nextInt(256) - 128;
      _values.int16Value = _random.nextInt(65536) - 32768;
      _values.int32Value = _random.nextInt(1000000);
      _values.int64Value = _random.nextInt(1000000);
      _values.uint8Value = _random.nextInt(256);
      _values.uint16Value = _random.nextInt(65536);
      _values.uint32Value = _random.nextInt(1000000);
      _values.uint64Value = _random.nextInt(1000000);
      
      // Floats
      _values.float32Value = _random.nextDouble() * 100;
      _values.float64Value = _random.nextDouble() * 1000;
      
      // Complex
      _values.stringValue = _sampleMessages[_random.nextInt(_sampleMessages.length)];
      _values.colorR = _random.nextDouble();
      _values.colorG = _random.nextDouble();
      _values.colorB = _random.nextDouble();
      _values.colorA = _random.nextDouble();
      _values.timeSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _values.timeNanosec = (_random.nextInt(1000000));
      _values.durationSec = _random.nextInt(60);
      _values.durationNanosec = _random.nextInt(1000000);
      _values.frameId = ["base_link", "odom", "map", "camera", "laser"][_random.nextInt(5)];
    });
    
    _publishAllTypes();
  }

  void _toggleAutoPublish() {
    if (!mounted) return;
    
    setState(() {
      _isAutoPublishing = !_isAutoPublishing;
    });

    if (_isAutoPublishing) {
      _autoTimer = Timer.periodic(Duration(seconds: 2), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        _randomizeValues();
      });
      _showSnackBar("Auto-publishing started (2s interval)");
    } else {
      _autoTimer?.cancel();
      _showSnackBar("Auto-publishing stopped");
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    try {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isError ? Colors.red : Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        print("SnackBar: $message");
      }
    } catch (e) {
      print("SnackBar Error: $message (${e.toString()})");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ROS2 Flutter Apps'),
        backgroundColor: Colors.blue,
        actions: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Sent: $_messageCounter | Received: ${_receivedMessages.length}',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(icon: Icon(Icons.data_object), text: "Primitives"),
            Tab(icon: Icon(Icons.numbers), text: "Integers"),
            Tab(icon: Icon(Icons.abc), text: "Floats"),
            Tab(icon: Icon(Icons.layers), text: "Complex"),
            Tab(icon: Icon(Icons.message), text: "Received"),
          ],
        ),
      ),
      body: Column(
        children: [
          // Quick action buttons
          Container(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _publishAllTypes,
                    icon: Icon(Icons.send_and_archive),
                    label: Text('Publish All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _randomizeValues,
                    icon: Icon(Icons.shuffle),
                    label: Text('Random & Send'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleAutoPublish,
                    icon: Icon(_isAutoPublishing ? Icons.stop : Icons.play_arrow),
                    label: Text(_isAutoPublishing ? 'Stop Auto' : 'Auto Pub'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAutoPublishing ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPrimitivesTab(),
                _buildIntegersTab(),
                _buildFloatsTab(),
                _buildComplexTab(),
                _buildReceivedMessagesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // New tab for received messages
  Widget _buildReceivedMessagesTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.message, color: Colors.green, size: 24),
                      SizedBox(width: 8),
                      Text('Received Messages', style: Theme.of(context).textTheme.titleLarge),
                      Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _receivedMessages.clear();
                          });
                        },
                        icon: Icon(Icons.clear),
                        label: Text('Clear'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    height: 400,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _receivedMessages.isEmpty
                        ? Center(
                            child: Text(
                              'No messages received yet.\nTry publishing to /chatter topic.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _receivedMessages.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.green,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(fontSize: 10, color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  _receivedMessages[index],
                                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          _buildTopicInfo([
            "Listening on: /chatter - std_msgs/String",
            "Use 'ros2 topic pub /chatter std_msgs/String \"data: 'test'\"' to test",
          ]),
        ],
      ),
    );
  }

  Widget _buildPrimitivesTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildTypeCard(
            "Primitive Types",
            Icons.data_object,
            Colors.blue,
            [
              _buildBoolControl(),
              _buildByteControl(),
              _buildCharControl(),
            ],
            _publishPrimitives,
          ),
          SizedBox(height: 16),
          _buildTopicInfo([
            "/std_msgs/bool - std_msgs/Bool",
            "/std_msgs/byte - std_msgs/Byte", 
            "/std_msgs/char - std_msgs/Char",
          ]),
        ],
      ),
    );
  }

  Widget _buildIntegersTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildTypeCard(
            "Signed Integers",
            Icons.numbers,
            Colors.green,
            [
              _buildIntSlider("Int8", _values.int8Value.toDouble(), -128, 127, (v) => setState(() => _values.int8Value = v.round())),
              _buildIntSlider("Int16", _values.int16Value.toDouble(), -32768, 32767, (v) => setState(() => _values.int16Value = v.round())),
              _buildIntSlider("Int32", _values.int32Value.toDouble(), -1000000, 1000000, (v) => setState(() => _values.int32Value = v.round())),
              _buildIntInput("Int64", _values.int64Value, (v) => setState(() => _values.int64Value = v)),
            ],
            _publishIntegers,
          ),
          SizedBox(height: 16),
          _buildTypeCard(
            "Unsigned Integers",
            Icons.add_box,
            Colors.purple,
            [
              _buildIntSlider("UInt8", _values.uint8Value.toDouble(), 0, 255, (v) => setState(() => _values.uint8Value = v.round())),
              _buildIntSlider("UInt16", _values.uint16Value.toDouble(), 0, 65535, (v) => setState(() => _values.uint16Value = v.round())),
              _buildIntSlider("UInt32", _values.uint32Value.toDouble(), 0, 1000000, (v) => setState(() => _values.uint32Value = v.round())),
              _buildIntInput("UInt64", _values.uint64Value, (v) => setState(() => _values.uint64Value = v)),
            ],
            _publishIntegers,
          ),
          SizedBox(height: 16),
          _buildTopicInfo([
            "/std_msgs/int8 - std_msgs/Int8",
            "/std_msgs/int16 - std_msgs/Int16",
            "/std_msgs/int32 - std_msgs/Int32",
            "/std_msgs/int64 - std_msgs/Int64",
            "/std_msgs/uint8 - std_msgs/UInt8",
            "/std_msgs/uint16 - std_msgs/UInt16",
            "/std_msgs/uint32 - std_msgs/UInt32",
            "/std_msgs/uint64 - std_msgs/UInt64",
          ]),
        ],
      ),
    );
  }

  Widget _buildFloatsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildTypeCard(
            "Floating Point Types",
            Icons.abc,
            Colors.orange,
            [
              _buildFloatSlider("Float32", _values.float32Value, 0, 100, (v) => setState(() => _values.float32Value = v)),
              _buildFloatSlider("Float64", _values.float64Value, 0, 1000, (v) => setState(() => _values.float64Value = v)),
            ],
            _publishFloats,
          ),
          SizedBox(height: 16),
          _buildTopicInfo([
            "/std_msgs/float32 - std_msgs/Float32",
            "/std_msgs/float64 - std_msgs/Float64",
          ]),
        ],
      ),
    );
  }

  Widget _buildComplexTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildTypeCard(
            "String & Color",
            Icons.text_fields,
            Colors.indigo,
            [
              _buildStringControl(),
              _buildColorControl(),
            ],
            _publishComplex,
          ),
          SizedBox(height: 16),
          _buildTypeCard(
            "Time & Frame",
            Icons.access_time,
            Colors.teal,
            [
              _buildTimeControl(),
              _buildDurationControl(),
              _buildFrameControl(),
            ],
            _publishComplex,
          ),
          SizedBox(height: 16),
          _buildTopicInfo([
            "/std_msgs/string - std_msgs/String",
            "/std_msgs/color_rgba - std_msgs/ColorRGBA",
            "/std_msgs/time - std_msgs/Time",
            "/std_msgs/duration - std_msgs/Duration",
            "/std_msgs/header - std_msgs/Header",
            "/std_msgs/empty - std_msgs/Empty",
          ]),
        ],
      ),
    );
  }

  Widget _buildTypeCard(String title, IconData icon, Color color, List<Widget> children, VoidCallback onPublish) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            SizedBox(height: 16),
            ...children,
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPublish,
                icon: Icon(Icons.send),
                label: Text('Publish $title'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoolControl() {
    return SwitchListTile(
      title: Text('Bool Value'),
      subtitle: Text('Current: ${_values.boolValue}'),
      value: _values.boolValue,
      onChanged: (value) => setState(() => _values.boolValue = value),
    );
  }

  Widget _buildByteControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Byte Value: ${_values.byteValue}'),
        Slider(
          value: _values.byteValue.toDouble(),
          min: 0,
          max: 255,
          divisions: 255,
          onChanged: (value) => setState(() => _values.byteValue = value.round()),
        ),
      ],
    );
  }

  Widget _buildCharControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Char Value: ${_values.charValue} (${String.fromCharCode(_values.charValue)})'),
        Slider(
          value: _values.charValue.toDouble(),
          min: 32,
          max: 126,
          divisions: 94,
          onChanged: (value) => setState(() => _values.charValue = value.round()),
        ),
      ],
    );
  }

  Widget _buildIntSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.round()}'),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildIntInput(String label, int value, Function(int) onChanged) {
    return TextField(
      decoration: InputDecoration(
        labelText: '$label Value',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onChanged: (val) => onChanged(int.tryParse(val) ?? value),
      controller: TextEditingController(text: value.toString()),
    );
  }

  Widget _buildFloatSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(3)}'),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildStringControl() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'String Message',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.text_fields),
      ),
      onChanged: (value) => _values.stringValue = value,
      controller: TextEditingController(text: _values.stringValue),
    );
  }

  Widget _buildColorControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color RGBA'),
        Row(
          children: [
            Expanded(child: _buildColorSlider('R', _values.colorR, Colors.red, (v) => setState(() => _values.colorR = v))),
            Expanded(child: _buildColorSlider('G', _values.colorG, Colors.green, (v) => setState(() => _values.colorG = v))),
            Expanded(child: _buildColorSlider('B', _values.colorB, Colors.blue, (v) => setState(() => _values.colorB = v))),
            Expanded(child: _buildColorSlider('A', _values.colorA, Colors.grey, (v) => setState(() => _values.colorA = v))),
          ],
        ),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Color.fromRGBO(
              (_values.colorR * 255).round(),
              (_values.colorG * 255).round(),
              (_values.colorB * 255).round(),
              _values.colorA,
            ),
            border: Border.all(color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildColorSlider(String label, double value, Color color, Function(double) onChanged) {
    return Column(
      children: [
        Text('$label: ${value.toStringAsFixed(2)}'),
        Slider(
          value: value,
          min: 0,
          max: 1,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTimeControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time: ${_values.timeSec}.${_values.timeNanosec}'),
        ElevatedButton(
          onPressed: () => setState(() {
            _values.timeSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            _values.timeNanosec = DateTime.now().microsecondsSinceEpoch % 1000000;
          }),
          child: Text('Set Current Time'),
        ),
      ],
    );
  }

  Widget _buildDurationControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Duration: ${_values.durationSec}s ${_values.durationNanosec}ns'),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(labelText: 'Seconds'),
                keyboardType: TextInputType.number,
                onChanged: (val) => _values.durationSec = int.tryParse(val) ?? _values.durationSec,
                controller: TextEditingController(text: _values.durationSec.toString()),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: InputDecoration(labelText: 'Nanoseconds'),
                keyboardType: TextInputType.number,
                onChanged: (val) => _values.durationNanosec = int.tryParse(val) ?? _values.durationNanosec,
                controller: TextEditingController(text: _values.durationNanosec.toString()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFrameControl() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Frame ID',
        border: OutlineInputBorder(),
      ),
      value: _values.frameId,
      items: ["base_link", "odom", "map", "camera", "laser", "world"].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (value) => setState(() => _values.frameId = value ?? _values.frameId),
    );
  }

  Widget _buildTopicInfo(List<String> topics) {
    return Card(
      elevation: 2,
      color: Colors.grey[100],
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ROS2 Topics:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            ...topics.map((topic) => Text('• $topic')),
            SizedBox(height: 8),
            Text(
              'Test with: ros2 topic echo /std_msgs/<type>',
              style: TextStyle(
                fontFamily: 'monospace',
                backgroundColor: Colors.black12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Data class to hold all message values
class MessageValues {
  // Primitives
  bool boolValue = true;
  int byteValue = 65; // 'A'
  int charValue = 72; // 'H'
  
  // Signed integers
  int int8Value = -42;
  int int16Value = -1234;
  int int32Value = -123456;
  int int64Value = -123456789;
  
  // Unsigned integers
  int uint8Value = 255;
  int uint16Value = 65535;
  int uint32Value = 123456;
  int uint64Value = 123456789;
  
  // Floats
  double float32Value = 3.14159;
  double float64Value = 2.718281828;
  
  // Complex types
  String stringValue = "Hello from Flutter to ROS2!";
  double colorR = 1.0;
  double colorG = 0.5;
  double colorB = 0.0;
  double colorA = 1.0;
  int timeSec = 0;
  int timeNanosec = 0;
  int durationSec = 5;
  int durationNanosec = 500000;
  String frameId = "base_link";
}

// Publisher manager for all std_msgs types
class StdMsgsPublishers {
  final Node node;
  final Map<String, publish.Publisher> _publishers = {};

  StdMsgsPublishers(this.node) {
    _initializePublishers();
  }

  createMessageType(String type) {
    switch (type) {
      case "bool":
        return StdMsgsBool(true);
      case "byte":
        return StdMsgsByte(0);
      case "char":
        return StdMsgsChar(0);
      case "int8":
        return StdMsgsInt8(0);
      case "int16":
        return StdMsgsInt16(0);
      case "int32":
        return StdMsgsInt32(0);
      case "int64":
        return StdMsgsInt64(0);
      case "uint8":
        return StdMsgsUInt8(0);
      case "uint16":
        return StdMsgsUInt16(0);
      case "uint32":
        return StdMsgsUInt32(0);
      case "uint64":
        return StdMsgsUInt64(0);
      case "float32":
        return StdMsgsFloat32(0.0);
      case "float64":
        return StdMsgsFloat64(0.0);
      case "string":
        return StdMsgsString( '');
      case "color_rgba":
        return StdMsgsColorRGBA();
      case "time":
        return StdMsgsTime();
      case "duration":
        return StdMsgsDuration();
      case "header":
        return StdMsgsHeader();
      case "empty":
        return StdMsgsEmpty();
      default:
        throw Exception("Unknown std_msgs type: $type");
    }
  }

  void _initializePublishers() {
    final types = [
      "bool", "byte", "char",
      "int8", "int16", "int32", "int64",
      "uint8", "uint16", "uint32", "uint64",
      "float32", "float64",
      "string", "color_rgba",  "header", "empty"
    ];

    for (String type in types) {
      _publishers[type] = node.createPublisher<BaseRosMessage>(topic_name: "std_msgs/$type",messageType: createMessageType(type));
    }
  }

  // Publishing methods for each type
  void publishBool(bool value) => _publishers["bool"]?.publish(StdMsgsBool(value));
  void publishByte(int value) => _publishers["byte"]?.publish(StdMsgsByte(value));
  void publishChar(int value) => _publishers["char"]?.publish(StdMsgsChar(value));

  void publishInt8(int value) => _publishers["int8"]?.publish(StdMsgsInt8(value));
  void publishInt16(int value) => _publishers["int16"]?.publish(StdMsgsInt16(value));
  void publishInt32(int value) => _publishers["int32"]?.publish(StdMsgsInt32(value));
  void publishInt64(int value) => _publishers["int64"]?.publish(StdMsgsInt64(value));

  void publishUInt8(int value) => _publishers["uint8"]?.publish(StdMsgsUInt8(value));
  void publishUInt16(int value) => _publishers["uint16"]?.publish(StdMsgsUInt16(value));
  void publishUInt32(int value) => _publishers["uint32"]?.publish(StdMsgsUInt32(value));
  void publishUInt64(int value) => _publishers["uint64"]?.publish(StdMsgsUInt64(value));

  void publishFloat32(double value) => _publishers["float32"]?.publish(StdMsgsFloat32(value));
  void publishFloat64(double value) => _publishers["float64"]?.publish(StdMsgsFloat64(value));

  void publishString(String value) => _publishers["string"]?.publish(StdMsgsString(value));

  void publishColorRGBA(double r, double g, double b, double a) => _publishers["color_rgba"]?.publish(StdMsgsColorRGBA(r: r, g: g, b: b, a: a));
  void publishTime(int sec, int nanosec) => _publishers["time"]?.publish(StdMsgsTime(sec: sec, nanosec: nanosec));
  void publishDuration(int sec, int nanosec) => _publishers["duration"]?.publish(StdMsgsDuration(sec: sec, nanosec: nanosec));
  void publishHeader(String frameId) => _publishers["header"]?.publish(StdMsgsHeader(frameId: frameId));
  void publishEmpty() => _publishers["empty"]?.publish(StdMsgsEmpty());

  void dispose() {
    for (var publisher in _publishers.values) {
      // publisher.dispose(); // If dispose method is available
    }
    _publishers.clear();
  }
}