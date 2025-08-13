// rcldart.dart

import 'dart:ffi';
import 'dart:io';

import 'package:rcldart/src/context.dart';
import 'package:rcldart/src/initOptions.dart';
import 'package:rcldart/src/logger.dart';
import 'package:rcldart/src/node.dart';

import './src/gen/rcldart_bindings_generated.dart';
import 'src/rcldart.dart';


const String _libName = 'rcldart';

/// The dynamic library in which the symbols for [RcldartBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final RcldartBindings _bindings = RcldartBindings(_dylib);


class RclDart {
  static final RclDart _instance = RclDart._internal();

  Context? _defaultContext;

  factory RclDart() {
    return _instance;
  }

  RclDart._internal() {
    initLogger();
  }

  /// Initialize RCL bindings
  init() {
    if (_defaultContext != null) {
      return;
    }

    rclDartLogger.info("Start initlization RCL bindings"); 

    var initOptions = InitOptions();

    _defaultContext = Context();
    var initResult = rcldartbindings.rcl_init(0, nullptr,
        initOptions.nativeInitOptions, getDefaultContext().nativeContext);
    if (initResult != RCL_RET_OK) {
      throw Exception("Unable to init rcl");
    }
    rclDartLogger.info("Successfully initialize RCL bindings");
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
