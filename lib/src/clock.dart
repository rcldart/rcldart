// src/clock.dart
//
// ROS 2 time source. Correct timestamps matter for tf and any time-ordered
// pipeline — a Header.stamp that drifts from the rest of the system makes
// transforms fail to look up ("extrapolation into the future/past").
//
// [Clock.systemNow] returns wall-clock ("system") time. NOTE: when the graph
// runs on simulated time (a `/clock` publisher — e.g. Gazebo/Nav2 sim), nodes
// must stamp with SIM time, not wall time, or tf lookups mismatch. Sim time
// needs a time source driven by `/clock` (rcl_clock + a ROS time source); that
// is a follow-up. Use [systemNow] for wall-clock deployments.
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'rcldart.dart';
import 'gen/rcldart_bindings_generated.dart';

/// A ROS time split into seconds + nanoseconds (matches builtin_interfaces/Time).
class RosTime {
  final int sec;
  final int nanosec;
  const RosTime(this.sec, this.nanosec);

  int get nanoseconds => sec * 1000000000 + nanosec;

  @override
  String toString() => 'RosTime($sec.${nanosec.toString().padLeft(9, '0')})';
}

class Clock {
  /// Wall-clock system time (nanoseconds since the Unix epoch), split into
  /// sec/nanosec. Use this to stamp message headers on wall-clock systems.
  static RosTime systemNow() {
    final out = calloc<Int64>();
    try {
      final rc = rcldartbindings.rcutils_system_time_now(out);
      if (rc != RCL_RET_OK) {
        throw Exception('rcutils_system_time_now failed with code: $rc');
      }
      final ns = out.value;
      return RosTime(ns ~/ 1000000000, ns % 1000000000);
    } finally {
      calloc.free(out);
    }
  }

  /// Monotonic steady time (not wall-clock); useful for measuring durations.
  static RosTime steadyNow() {
    final out = calloc<Int64>();
    try {
      final rc = rcldartbindings.rcutils_steady_time_now(out);
      if (rc != RCL_RET_OK) {
        throw Exception('rcutils_steady_time_now failed with code: $rc');
      }
      final ns = out.value;
      return RosTime(ns ~/ 1000000000, ns % 1000000000);
    } finally {
      calloc.free(out);
    }
  }
}
