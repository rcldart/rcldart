// src/time_source.dart
//
// Simulated-time support for tf-correct stamping. When the graph runs on sim
// time (a `/clock` publisher, e.g. Gazebo/Nav2), message headers must be
// stamped with SIM time, not wall time, or tf lookups fail with
// extrapolation errors.
//
// [TimeSource] subscribes to `/clock` (rosgraph_msgs/msg/Clock) and caches the
// latest sim time. Drive it with an [Executor] (or poll its subscriber), then
// call [now] to stamp headers: it returns sim time when available and falls
// back to wall-clock [Clock.systemNow] otherwise.
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:rcldart_utils/rcldart_utils.dart';

import 'clock.dart';
import 'executor.dart';
import 'node.dart';
import 'subscriber.dart';

// --- rosgraph_msgs/msg/Clock = { builtin_interfaces/Time clock } ---

base class builtin_interfaces__msg__Time extends Struct {
  @Int32()
  external int sec;
  @Uint32()
  external int nanosec;
}

base class rosgraph_msgs__msg__Clock extends Struct {
  external builtin_interfaces__msg__Time clock;
}

class ClockMsg extends BaseRosMessage<rosgraph_msgs__msg__Clock> {
  @override
  String get typeName => 'Clock';
  @override
  String get packageName => 'rosgraph_msgs';

  ClockMsg() {
    data = calloc<rosgraph_msgs__msg__Clock>();
    nativeData = nullptr;
  }

  RosTime get time =>
      RosTime(data.ref.clock.sec, data.ref.clock.nanosec);
}

class TimeSource {
  RosTime? _simTime;
  Subscriber? _sub;

  /// Whether a `/clock` message has been received yet.
  bool get hasSimTime => _simTime != null;

  /// The current time: sim time if `/clock` is active, else wall-clock.
  RosTime now() => _simTime ?? Clock.systemNow();

  /// The latest sim time (null until the first `/clock` message).
  RosTime? get simTime => _simTime;

  /// Subscribes to `/clock` on [node]. Register with an [executor] (or poll the
  /// returned subscriber) so the cached time keeps updating.
  Subscriber attach(Node node, {Executor? executor}) {
    _sub = node.createSubscriber<ClockMsg>(
      topic_name: '/clock',
      messageType: ClockMsg(),
      callback: (msg) => _simTime = msg.time,
    );
    executor?.addSubscription(_sub!);
    return _sub!;
  }
}
