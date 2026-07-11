// src/parameter.dart
//
// ROS 2 parameter support.
//
// In ROS 2 there is no "parameter" primitive at the rcl level: parameters are
// implemented on top of ordinary services (`rcl_interfaces/srv/*`) plus the
// `/<node>/parameter_events` topic. This file provides:
//
//   1. The parameter *value model* (`ParameterType`, `Parameter`,
//      `ParameterDescriptor`, `SetParametersResult`) — mirrors
//      `rcl_interfaces/msg`.
//   2. A node-local `NodeParameters` store (declare / get / set / list /
//      callbacks) that is fully usable today for app-internal configuration.
//
// Exposing the store over the standard ROS 2 parameter services (so that
// `ros2 param get/set/list` and other nodes can reach it) is the remaining
// step; it requires `rcl_interfaces` type-support bindings — see
// `attachToRos()` below.
import 'dart:async';

import 'executor.dart';
import 'node.dart';
import 'parameter_bridge.dart';

/// Mirrors `rcl_interfaces/msg/ParameterType`.
enum ParameterType {
  notSet(0),
  boolean(1),
  integer(2),
  double_(3),
  string(4),
  byteArray(5),
  boolArray(6),
  integerArray(7),
  doubleArray(8),
  stringArray(9);

  final int value;
  const ParameterType(this.value);
}

/// A single named parameter with a typed value.
class Parameter {
  final String name;
  final ParameterType type;
  final Object? value;

  const Parameter._(this.name, this.type, this.value);

  factory Parameter.bool(String name, bool value) =>
      Parameter._(name, ParameterType.boolean, value);
  factory Parameter.int(String name, int value) =>
      Parameter._(name, ParameterType.integer, value);
  factory Parameter.double(String name, double value) =>
      Parameter._(name, ParameterType.double_, value);
  factory Parameter.string(String name, String value) =>
      Parameter._(name, ParameterType.string, value);
  factory Parameter.intArray(String name, List<int> value) =>
      Parameter._(name, ParameterType.integerArray, value);
  factory Parameter.doubleArray(String name, List<double> value) =>
      Parameter._(name, ParameterType.doubleArray, value);
  factory Parameter.stringArray(String name, List<String> value) =>
      Parameter._(name, ParameterType.stringArray, value);
  factory Parameter.boolArray(String name, List<bool> value) =>
      Parameter._(name, ParameterType.boolArray, value);

  /// Infers the parameter type from a Dart [value].
  factory Parameter.from(String name, Object? value) {
    if (value == null) return Parameter._(name, ParameterType.notSet, null);
    if (value is bool) return Parameter.bool(name, value);
    if (value is int) return Parameter.int(name, value);
    if (value is double) return Parameter.double(name, value);
    if (value is String) return Parameter.string(name, value);
    if (value is List<int>) return Parameter.intArray(name, value);
    if (value is List<double>) return Parameter.doubleArray(name, value);
    if (value is List<String>) return Parameter.stringArray(name, value);
    if (value is List<bool>) return Parameter.boolArray(name, value);
    throw ArgumentError('Unsupported parameter value type: ${value.runtimeType}');
  }

  bool get asBool => value as bool;
  int get asInt => value as int;
  double get asDouble => value as double;
  String get asString => value as String;

  @override
  String toString() => 'Parameter($name: ${type.name} = $value)';
}

/// Mirrors `rcl_interfaces/msg/ParameterDescriptor`.
class ParameterDescriptor {
  final String name;
  final ParameterType type;
  final String description;
  final bool readOnly;
  final bool dynamicTyping;

  const ParameterDescriptor({
    required this.name,
    required this.type,
    this.description = '',
    this.readOnly = false,
    this.dynamicTyping = false,
  });
}

/// Mirrors `rcl_interfaces/msg/SetParametersResult`.
class SetParametersResult {
  final bool successful;
  final String reason;
  const SetParametersResult(this.successful, [this.reason = '']);

  factory SetParametersResult.ok() => const SetParametersResult(true);
  factory SetParametersResult.rejected(String reason) =>
      SetParametersResult(false, reason);
}

/// Callback invoked before parameters are applied. Returning a rejected result
/// vetoes the whole batch (ROS 2 "on set parameters" semantics).
typedef OnSetParametersCallback = SetParametersResult Function(
    List<Parameter> parameters);

/// Thrown when a parameter operation violates declaration/type rules.
class ParameterException implements Exception {
  final String message;
  ParameterException(this.message);
  @override
  String toString() => 'ParameterException: $message';
}

/// Node-local parameter store with ROS 2 declare/get/set semantics.
///
/// Usage:
/// ```dart
/// final params = NodeParameters();
/// params.declare(Parameter.int('max_speed', 10));
/// params.addOnSetParametersCallback((updates) {
///   for (final p in updates) {
///     if (p.name == 'max_speed' && p.asInt < 0) {
///       return SetParametersResult.rejected('max_speed must be >= 0');
///     }
///   }
///   return SetParametersResult.ok();
/// });
/// params.set([Parameter.int('max_speed', 25)]);
/// print(params.get('max_speed').asInt); // 25
/// ```
class NodeParameters {
  final Map<String, Parameter> _params = {};
  final Map<String, ParameterDescriptor> _descriptors = {};
  final List<OnSetParametersCallback> _callbacks = [];

  /// Emits every accepted parameter change (feeds the `parameter_events`
  /// topic once [attachToRos] is implemented).
  final StreamController<List<Parameter>> _events =
      StreamController<List<Parameter>>.broadcast();
  Stream<List<Parameter>> get onParameterEvent => _events.stream;

  /// Whether unknown parameters may be set without prior [declare].
  final bool allowUndeclared;

  NodeParameters({this.allowUndeclared = false});

  /// Declares a parameter with an initial value; throws if already declared.
  Parameter declare(Parameter parameter, {ParameterDescriptor? descriptor}) {
    if (_params.containsKey(parameter.name)) {
      throw ParameterException('Parameter "${parameter.name}" already declared');
    }
    _params[parameter.name] = parameter;
    _descriptors[parameter.name] = descriptor ??
        ParameterDescriptor(name: parameter.name, type: parameter.type);
    return parameter;
  }

  bool has(String name) => _params.containsKey(name);

  /// Returns the parameter, or a `notSet` parameter when undeclared.
  Parameter get(String name) =>
      _params[name] ?? Parameter._(name, ParameterType.notSet, null);

  /// Returns the value or [orElse] when unset.
  T getOr<T>(String name, T orElse) {
    final p = _params[name];
    if (p == null || p.type == ParameterType.notSet) return orElse;
    return p.value as T;
  }

  List<Parameter> list() => List.unmodifiable(_params.values);

  ParameterDescriptor? describe(String name) => _descriptors[name];

  /// Registers a validation/veto callback (ROS 2 semantics).
  void addOnSetParametersCallback(OnSetParametersCallback cb) =>
      _callbacks.add(cb);

  /// Atomically sets a batch of parameters after running all callbacks.
  ///
  /// If any callback rejects, nothing is applied and the rejection is
  /// returned (matches `set_parameters_atomically`).
  SetParametersResult set(List<Parameter> updates) {
    for (final p in updates) {
      if (!allowUndeclared && !_params.containsKey(p.name)) {
        return SetParametersResult.rejected(
            'Parameter "${p.name}" is not declared');
      }
      final desc = _descriptors[p.name];
      if (desc != null && desc.readOnly) {
        return SetParametersResult.rejected(
            'Parameter "${p.name}" is read-only');
      }
      if (desc != null &&
          !desc.dynamicTyping &&
          desc.type != ParameterType.notSet &&
          p.type != desc.type) {
        return SetParametersResult.rejected(
            'Parameter "${p.name}" expects ${desc.type.name}, got ${p.type.name}');
      }
    }

    for (final cb in _callbacks) {
      final result = cb(updates);
      if (!result.successful) return result;
    }

    for (final p in updates) {
      _params[p.name] = p;
      _descriptors.putIfAbsent(
          p.name, () => ParameterDescriptor(name: p.name, type: p.type));
    }
    _events.add(updates);
    return SetParametersResult.ok();
  }

  void undeclare(String name) {
    _params.remove(name);
    _descriptors.remove(name);
  }

  void dispose() => _events.close();

  /// Exposes this store over the standard ROS 2 parameter services so that
  /// `ros2 param get/set/list` and other nodes can reach it.
  ///
  /// Creates `~/get_parameters`, `~/get_parameter_types`, `~/set_parameters`,
  /// `~/set_parameters_atomically` and `~/list_parameters` on [node], backed by
  /// this store (see [RosParameterServer]). If an [executor] is supplied the
  /// services are registered with it and serviced automatically; otherwise spin
  /// the returned services yourself.
  ///
  /// Requires the `rcl_interfaces` runtime libraries (present in any ROS 2
  /// install). `~/describe_parameters` and the `~/parameter_events` publisher
  /// are not wired yet.
  RosParameterServer attachToRos(Node node, {Executor? executor}) =>
      RosParameterServer.attach(this, node, executor: executor);
}
