import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:rcldart/src/publisher.dart';
import 'package:rcldart/src/rcldart.dart';
import 'package:rcldart/src/util/dynamic_library_loader.dart';

import './context.dart';
import 'gen/rcldart_bindings_generated.dart';
import 'node_options.dart';

class Node {
  late final Pointer<rcl_node_s> nativeNode;
  final String nodeName;
  final String nameSpace;
  final NodeOptions nodeOptions;

  static final dylib = dynamiclibraryloader("std_msgs__rosidl_typesupport_c");

  Node._(this.nativeNode, this.nodeName, this.nameSpace, Context context,
      this.nodeOptions);

  factory Node(String nodeName, String nameSpace, Context context) {
    var nodeOptions = NodeOptions();
    return Node.withOptions(nodeName, nameSpace, context, nodeOptions);
  }

  factory Node.withOptions(String nodeName, String nameSpace, Context context,
      NodeOptions nodeOptions) {
    var nativeNode = malloc<rcl_node_s>()
      ..ref = rcldartbindings.rcl_get_zero_initialized_node();

    var rc = rcldartbindings.rcl_node_init(
        nativeNode,
        nodeName.toNativeUtf8().cast<Char>(),
        nameSpace.toNativeUtf8().cast<Char>(),
        context.nativeContext,
        nodeOptions.nativeNodeOptions);
    if (rc != RCL_RET_OK) {
      throw Exception("unable to init node");
    }
    return Node._(nativeNode, nodeName, nameSpace, context, nodeOptions);
  }

  Publisher createPublisher({required String topic_name, }) {
    var publisher = malloc<rcl_publisher_s>()
      ..ref = rcldartbindings.rcl_get_zero_initialized_publisher();

    var options = malloc<rcl_publisher_options_s>()
      ..ref = rcldartbindings.rcl_publisher_get_default_options();

    final ttt = dylib
        .lookup<NativeFunction<_typesupportMsgFunc>>(
            'rosidl_typesupport_c__get_message_type_support_handle__std_msgs__msg__Float32')
        .asFunction<_typesupportMsgFunc>();
    
    

    var rc = rcldartbindings.rcl_publisher_init(publisher, nativeNode, ttt(),
        topic_name.toNativeUtf8().cast<Char>(), options);
    if (rc != RCL_RET_OK) {
      throw Exception("unable to create publisher");
    }

    return Publisher(publisher);
  }
}

typedef _typesupportMsgFunc = Pointer<rosidl_message_type_support_t> Function();
typedef _typesupportSrvFunc = Pointer<rosidl_service_type_support_t> Function();