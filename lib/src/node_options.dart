import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'package:rcldart/src/rcldart.dart';

import 'gen/rcldart_bindings_generated.dart';

class NodeOptions {
  
  final Pointer<rcl_node_options_t> nativeNodeOptions;

  NodeOptions._internal(this.nativeNodeOptions);

  final Pointer<rcl_node_options_t> rclNodeOptions = nullptr;
  final List<String> _arguments = [];
  set arguments(List<String> args) {
    _arguments
      ..clear()
      ..addAll(args);
  }

  factory NodeOptions() {
    var nodeOptions = malloc<rcl_node_options_s>()
      ..ref = rcldartbindings.rcl_node_get_default_options();
    return NodeOptions._internal(nodeOptions);
  }
}
