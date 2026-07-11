// src/parameter_bridge.dart
//
// Exposes a [NodeParameters] store over the standard ROS 2 parameter services
// so that `ros2 param get/set/list` and other nodes can reach it. Built on the
// [Node.createService] infrastructure + the hand-written rcl_interfaces
// bindings.
//
// Native message *content* (strings, sequences) is manipulated through FFI
// struct views (read/write the same native memory the message owns) plus
// `calloc` for element storage — no field-offset math and no generated
// setters required. The top-level request/response messages are still
// allocated via their generated `__create` so rcl/rmw see a valid, fully
// initialized message.
//
// STATUS: implemented; validate on a live ROS 2 system (talks to FastDDS).
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:rcldart_utils/rcldart_utils.dart';

import 'executor.dart';
import 'node.dart';
import 'parameter.dart';
import 'service.dart';
import 'msgs/_rcl_interfaces_types.dart';
import 'gen/rcldart_bindings_generated.dart';

// --- rosidl String helpers (operate on struct views) ---

String _readStr(rosidl_runtime_c__String s) {
  if (s.data == nullptr || s.size == 0) return '';
  return s.data.cast<Utf8>().toDartString(length: s.size);
}

void _setStr(rosidl_runtime_c__String s, String value) {
  final bytes = value.toNativeUtf8(); // null-terminated UTF-8
  s.data = bytes.cast<Char>();
  s.size = bytes.length; // excludes the null terminator
  s.capacity = bytes.length + 1;
}

/// Reads every element of a `rosidl_runtime_c__String__Sequence`.
List<String> _readStringSeq(rosidl_runtime_c__String__Sequence seq) {
  final out = <String>[];
  for (var i = 0; i < seq.size; i++) {
    out.add(_readStr(seq.data[i]));
  }
  return out;
}

/// Allocates and fills a `rosidl_runtime_c__String__Sequence` view.
void _writeStringSeq(
    rosidl_runtime_c__String__Sequence seq, List<String> values) {
  final arr = calloc<rosidl_runtime_c__String>(values.length);
  seq.data = arr;
  seq.size = values.length;
  seq.capacity = values.length;
  for (var i = 0; i < values.length; i++) {
    _setStr(arr[i], values[i]);
  }
}

// --- ParameterValue <-> Dart Parameter ---

Object? _decodeValue(ParameterValueC v) {
  switch (v.type) {
    case 1: // BOOL
      return v.bool_value;
    case 2: // INTEGER
      return v.integer_value;
    case 3: // DOUBLE
      return v.double_value;
    case 4: // STRING
      return _readStr(v.string_value);
    default:
      // Array-valued parameters are not yet translated.
      return null;
  }
}

void _encodeValue(ParameterValueC v, Parameter p) {
  v.type = p.type.value;
  switch (p.type) {
    case ParameterType.boolean:
      v.bool_value = p.asBool;
      break;
    case ParameterType.integer:
      v.integer_value = p.asInt;
      break;
    case ParameterType.double_:
      v.double_value = p.asDouble;
      break;
    case ParameterType.string:
      _setStr(v.string_value, p.asString);
      break;
    default:
      // notSet / array types: leave zero-initialized (type carries notSet).
      break;
  }
}

/// Wires a [NodeParameters] store to the ROS 2 parameter services on [node].
///
/// Implements: `~/get_parameters`, `~/get_parameter_types`,
/// `~/set_parameters`, `~/set_parameters_atomically`, `~/list_parameters`.
/// `~/describe_parameters` and the `~/parameter_events` publisher are left as
/// follow-ups (the store already emits [NodeParameters.onParameterEvent]).
class RosParameterServer {
  final NodeParameters store;
  final Node node;
  final List<Service> services = [];

  RosParameterServer._(this.store, this.node);

  /// Creates the parameter services under `<node>/...` and, if an [executor]
  /// is given, registers them so they are serviced automatically.
  factory RosParameterServer.attach(
    NodeParameters store,
    Node node, {
    Executor? executor,
  }) {
    final server = RosParameterServer._(store, node);
    final ns = node.nodeName;

    server._getParameters(ns);
    server._getParameterTypes(ns);
    server._setParameters(ns);
    server._setParametersAtomically(ns);
    server._listParameters(ns);

    if (executor != null) {
      for (final s in server.services) {
        executor.addService(s);
      }
    }
    return server;
  }

  void _getParameters(String ns) {
    final svc = GetParametersService();
    services.add(node.createService<BaseRosMessage<GetParametersRequestC>,
        BaseRosMessage<GetParametersResponseC>>(
      serviceName: '$ns/get_parameters',
      serviceType: svc,
      handler: (req) {
        final names = _readStringSeq(req.data.ref.names);
        final resp = svc.createResponse();

        final arr = calloc<ParameterValueC>(names.length);
        resp.data.ref.values.data = arr;
        resp.data.ref.values.size = names.length;
        resp.data.ref.values.capacity = names.length;

        for (var i = 0; i < names.length; i++) {
          final p = store.get(names[i]);
          _encodeValue(arr[i], p);
        }
        return resp;
      },
    ));
  }

  void _getParameterTypes(String ns) {
    final svc = GetParameterTypesService();
    services.add(node.createService<BaseRosMessage<GetParameterTypesRequestC>,
        BaseRosMessage<GetParameterTypesResponseC>>(
      serviceName: '$ns/get_parameter_types',
      serviceType: svc,
      handler: (req) {
        final names = _readStringSeq(req.data.ref.names);
        final resp = svc.createResponse();

        final arr = calloc<Uint8>(names.length);
        resp.data.ref.types.data = arr;
        resp.data.ref.types.size = names.length;
        resp.data.ref.types.capacity = names.length;

        for (var i = 0; i < names.length; i++) {
          arr[i] = store.get(names[i]).type.value;
        }
        return resp;
      },
    ));
  }

  void _setParameters(String ns) {
    final svc = SetParametersService();
    services.add(node.createService<BaseRosMessage<SetParametersRequestC>,
        BaseRosMessage<SetParametersResponseC>>(
      serviceName: '$ns/set_parameters',
      serviceType: svc,
      handler: (req) {
        final params = req.data.ref.parameters;
        final resp = svc.createResponse();

        final arr = calloc<SetParametersResultC>(params.size);
        resp.data.ref.results.data = arr;
        resp.data.ref.results.size = params.size;
        resp.data.ref.results.capacity = params.size;

        for (var i = 0; i < params.size; i++) {
          final pc = params.data[i];
          final name = _readStr(pc.name);
          final value = _decodeValue(pc.value);
          final result = store.set([Parameter.from(name, value)]);
          arr[i].successful = result.successful;
          _setStr(arr[i].reason, result.reason);
        }
        return resp;
      },
    ));
  }

  void _setParametersAtomically(String ns) {
    final svc = SetParametersAtomicallyService();
    services.add(node.createService<
        BaseRosMessage<SetParametersAtomicallyRequestC>,
        BaseRosMessage<SetParametersAtomicallyResponseC>>(
      serviceName: '$ns/set_parameters_atomically',
      serviceType: svc,
      handler: (req) {
        final params = req.data.ref.parameters;
        final resp = svc.createResponse();

        final updates = <Parameter>[];
        for (var i = 0; i < params.size; i++) {
          final pc = params.data[i];
          updates.add(Parameter.from(_readStr(pc.name), _decodeValue(pc.value)));
        }
        final result = store.set(updates); // all-or-nothing
        resp.data.ref.result.successful = result.successful;
        _setStr(resp.data.ref.result.reason, result.reason);
        return resp;
      },
    ));
  }

  void _listParameters(String ns) {
    final svc = ListParametersService();
    services.add(node.createService<BaseRosMessage<ListParametersRequestC>,
        BaseRosMessage<ListParametersResponseC>>(
      serviceName: '$ns/list_parameters',
      serviceType: svc,
      handler: (req) {
        final prefixes = _readStringSeq(req.data.ref.prefixes);
        final resp = svc.createResponse();

        final names = store
            .list()
            .map((p) => p.name)
            .where((n) => prefixes.isEmpty ||
                prefixes.any((pre) => n == pre || n.startsWith('$pre.')))
            .toList();

        _writeStringSeq(resp.data.ref.result.names, names);
        _writeStringSeq(resp.data.ref.result.prefixes, prefixes);
        return resp;
      },
    ));
  }

  void dispose() {
    for (final s in services) {
      s.dispose();
    }
    services.clear();
  }
}
