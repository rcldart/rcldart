// src/action.dart
//
// ROS 2 action support (Goal / Feedback / Result).
//
// STATUS: model + API scaffold. The native `rcl_action` functions are NOT yet
// in the generated bindings — `rcl_action` lives in the ros2/rcl repo but is
// not part of ffigen's entry-points until the sources are imported. To enable
// the FFI wiring:
//
//   1. `vcs import src < src/ros2.repos`   (pulls rcl_action headers)
//   2. The rcl_action entry-point is already listed in `ffigen.yaml`;
//      regenerate: `flutter pub run ffigen --config ffigen.yaml`
//   3. Implement the `TODO(rcl_action)` sections below against the new
//      bindings (rcl_action_client/rcl_action_server, send_goal_request,
//      take_feedback, take_result_response, etc.).
//
// An action = 3 services (send_goal, cancel_goal, get_result) + 2 topics
// (feedback, status). This file models the goal lifecycle and the public API;
// the state machine here is complete and reusable regardless of transport.
import 'dart:async';
import 'dart:ffi';

import 'package:rcldart_utils/rcldart_utils.dart';

/// Mirrors `action_msgs/msg/GoalStatus`.
enum GoalStatus {
  unknown(0),
  accepted(1),
  executing(2),
  canceling(3),
  succeeded(4),
  canceled(5),
  aborted(6);

  final int value;
  const GoalStatus(this.value);

  bool get isTerminal =>
      this == succeeded || this == canceled || this == aborted;
}

/// 16-byte goal identifier (`unique_identifier_msgs/msg/UUID`).
class GoalUUID {
  final List<int> bytes; // length 16
  GoalUUID(this.bytes)
      : assert(bytes.length == 16, 'UUID must be 16 bytes');

  @override
  String toString() =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Describes a concrete ROS 2 action type: its type-support symbol plus the
/// Goal / Feedback / Result message factories.
///
/// The rosidl symbol for an action is:
///   `rosidl_typesupport_c__get_action_type_support_handle__<pkg>__action__<Action>`
abstract class RosActionType<Goal extends BaseRosMessage,
    Feedback extends BaseRosMessage, Result extends BaseRosMessage> {
  String get typeSupportName;
  DynamicLibrary get typeSupportLibrary;
  Goal createGoal();
  Feedback createFeedback();
  Result createResult();
}

/// Handle returned when a goal is accepted by a server; tracks its lifecycle.
class GoalHandle<Feedback extends BaseRosMessage,
    Result extends BaseRosMessage> {
  final GoalUUID uuid;
  GoalStatus _status = GoalStatus.accepted;
  GoalStatus get status => _status;

  final _feedback = StreamController<Feedback>.broadcast();
  final _result = Completer<Result>();

  GoalHandle(this.uuid);

  /// Feedback stream published by the server while executing.
  Stream<Feedback> get onFeedback => _feedback.stream;

  /// Completes when the goal reaches a terminal state.
  Future<Result> get result => _result.future;

  // --- Server-side transitions (used by ActionServer) ---
  void markExecuting() => _status = GoalStatus.executing;

  void publishFeedback(Feedback fb) {
    if (!_status.isTerminal) _feedback.add(fb);
  }

  void succeed(Result r) => _complete(GoalStatus.succeeded, r);
  void abort(Result r) => _complete(GoalStatus.aborted, r);
  void canceled(Result r) => _complete(GoalStatus.canceled, r);

  void _complete(GoalStatus terminal, Result r) {
    if (_status.isTerminal) return;
    _status = terminal;
    if (!_result.isCompleted) _result.complete(r);
    _feedback.close();
  }
}

/// Action *client*: sends goals, streams feedback, awaits results.
///
/// TODO(rcl_action): back these calls with rcl_action_send_goal_request,
/// rcl_action_take_feedback, rcl_action_send_result_request /
/// rcl_action_take_result_response, and rcl_action_send_cancel_request.
class ActionClient<Goal extends BaseRosMessage,
    Feedback extends BaseRosMessage, Result extends BaseRosMessage> {
  final RosActionType<Goal, Feedback, Result> actionType;
  final String actionName;

  ActionClient(this.actionType, this.actionName);

  /// Sends [goal]; resolves to a [GoalHandle] once the server accepts it.
  Future<GoalHandle<Feedback, Result>> sendGoal(
    Goal goal, {
    void Function(Feedback)? onFeedback,
  }) {
    throw UnimplementedError(
        'ActionClient.sendGoal needs rcl_action bindings — see file header.');
  }

  Future<void> cancelGoal(GoalUUID uuid) {
    throw UnimplementedError(
        'ActionClient.cancelGoal needs rcl_action bindings — see file header.');
  }
}

/// Action *server*: accepts/rejects goals and runs an execution callback.
///
/// TODO(rcl_action): back these calls with rcl_action_take_goal_request,
/// rcl_action_send_goal_response, rcl_action_publish_feedback,
/// rcl_action_publish_status and rcl_action_send_result_response.
class ActionServer<Goal extends BaseRosMessage,
    Feedback extends BaseRosMessage, Result extends BaseRosMessage> {
  final RosActionType<Goal, Feedback, Result> actionType;
  final String actionName;

  /// Decides whether to accept an incoming goal.
  final bool Function(Goal goal) goalCallback;

  /// Runs an accepted goal to completion, publishing feedback via [handle].
  final Future<void> Function(
      Goal goal, GoalHandle<Feedback, Result> handle) executeCallback;

  ActionServer(
    this.actionType,
    this.actionName, {
    required this.goalCallback,
    required this.executeCallback,
  });

  /// Processes pending action traffic (goal/cancel/result requests).
  bool spinOnce() {
    throw UnimplementedError(
        'ActionServer.spinOnce needs rcl_action bindings — see file header.');
  }
}
