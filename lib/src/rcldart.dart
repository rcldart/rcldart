import 'package:rcldart/src/initOptions.dart';
import 'package:rcldart/src/logger.dart';
import 'dart:ffi';
import 'package:rcldart/src/util/dynamic_library_loader.dart';

import 'context.dart';
import 'gen/rcldart_bindings_generated.dart';
import 'node.dart';

final RcldartBindings rcldartbindings = RcldartBindings(dynamiclibraryloader("rcl"));

// singleton class
class RclDart {
  static final RclDart _instance = RclDart._internal();

  Context? _defaultContext;

  factory RclDart() {
    return _instance;
  }

  RclDart._internal() {
    initLogger();
  }

  init() {
    if (_defaultContext != null) {
      return;
    }

    // rclDartLogger.info("start initializing rcl");

    var initOptions = InitOptions();

    _defaultContext = Context();
    var initResult = rcldartbindings.rcl_init(0, nullptr,
        initOptions.nativeInitOptions, getDefaultContext().nativeContext);
    if (initResult != RCL_RET_OK) {
      throw Exception("unable to init rcl");
    }
    rclDartLogger.info("successfully initialize rcl");
  }

  // createNode create new Node with defaultcontext
  Node createNode(String nodeName, String nameSpace) {
    var node = Node(nodeName, nameSpace, getDefaultContext());
    rclDartLogger.info(
        "created node \nnodeName: $nodeName, \nnameSpace: $nameSpace");
    return node;
  }

  Context getDefaultContext() {
    if (_defaultContext == null) {
      throw Exception("initialize rcldart before doing something!");
    }
    return _defaultContext!;
  }
}
