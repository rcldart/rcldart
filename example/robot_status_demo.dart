// End-to-end demo of a CUSTOM package built in rcldart_ws:
// publishes rcldart_msgs/msg/RobotStatus (nested Header, string, bool,
// float64[] sequence) with a proper ROS timestamp + frame_id.
//
// Verify from ROS 2:
//   ros2 topic echo /robot_status rcldart_msgs/msg/RobotStatus
import 'dart:ffi';
import 'dart:io';
import 'package:rcldart/rcldart.dart' as rcldart;
import 'package:rcldart/src/node.dart';
import 'package:std_msgs/std_msgs.dart';
import 'package:rcldart_msgs/rcldart_msgs.dart';

void main() {
  rcldart.RclDart().init();
  final node = rcldart.RclDart().createNode('robot_status', 'examples');

  final pub = node.createPublisher<RcldartMsgsRobotStatus>(
    topic_name: '/robot_status',
    messageType: RcldartMsgsRobotStatus(),
  );
  print('publishing rcldart_msgs/msg/RobotStatus on /robot_status');

  for (var i = 0; i < 40; i++) {
    final now = rcldart.Clock.systemNow(); // ROS time (not tf-drifting wall time)

    final msg = RcldartMsgsRobotStatus()
      ..robotName = 'rcldart_bot'
      ..batteryPercentage = 90 - (i % 40)
      ..isCharging = i.isEven
      ..jointPositions = [0.1 * i, -0.2 * i, 0.05 * i];

    // Header with a correct stamp + frame_id (matters for tf lookups).
    final header = StdMsgsHeader(frameId: 'base_link');
    header.data.ref.stamp.sec = now.sec;
    header.data.ref.stamp.nanosec = now.nanosec;
    msg.data.ref.header = header.data.ref;

    pub.publish(msg);
    print('battery=${msg.batteryPercentage} charging=${msg.isCharging} '
        'joints=${msg.jointPositions} stamp=${now.sec}');
    sleep(const Duration(milliseconds: 250));
  }
}
