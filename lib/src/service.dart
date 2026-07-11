// src/service.dart
//
// A ROS 2 service *server*: receives a Request from a client, runs a handler,
// and sends back a Response.
//
// Low-level rcl flow:
//   rcl_take_request(service, &request_header, request)      // poll for a request
//   ... run user handler to build the response ...
//   rcl_send_response(service, &request_header, response)     // reply
//
// The `request_header` (rmw_request_id_t) taken with the request MUST be passed
// back unchanged to `rcl_send_response` so rmw can route the reply to the right
// client / sequence number.
import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;
import 'package:rcldart_utils/rcldart_utils.dart';

import 'rcldart.dart';
import 'gen/rcldart_bindings_generated.dart';

class Service<Req extends BaseRosMessage, Resp extends BaseRosMessage> {
  final Pointer<rcl_service_t> nativeService;
  final BaseRosService<Req, Resp> serviceType;
  final String serviceName;

  /// User handler mapping a request to a response.
  final Resp Function(Req request) handler;

  Service(this.nativeService, this.serviceType, this.serviceName, this.handler);

  /// Processes at most one pending request.
  ///
  /// Returns `true` if a request was handled and a response was sent, `false`
  /// when no request was available (`RCL_RET_SERVICE_TAKE_FAILED`).
  ///
  /// Call this repeatedly (e.g. from a `Timer.periodic`, like the subscriber
  /// polling in the example) to serve requests.
  bool spinOnce() {
    final request = serviceType.createRequest();
    final header = ffi.calloc<rmw_request_id_t>();

    try {
      final rc = rcldartbindings.rcl_take_request(
          nativeService, header, request.data.cast<Void>());

      if (rc == RCL_RET_SERVICE_TAKE_FAILED) {
        return false; // nothing to serve right now
      } else if (rc != RCL_RET_OK) {
        throw Exception('rcl_take_request failed with code: $rc');
      }

      // Build the response via the user handler.
      final response = handler(request);
      if (response.data == nullptr) {
        throw StateError('Service handler returned a response with null data');
      }

      // The response MUST be routed with the same header we received.
      final sendRc = rcldartbindings.rcl_send_response(
          nativeService, header, response.data.cast<Void>());
      if (sendRc != RCL_RET_OK) {
        throw Exception('rcl_send_response failed with code: $sendRc');
      }
      return true;
    } finally {
      ffi.calloc.free(header);
    }
  }

  /// Drains all currently pending requests.
  ///
  /// Returns the number of requests served in this pass.
  int spin() {
    var served = 0;
    while (spinOnce()) {
      served++;
    }
    return served;
  }

  bool get isValid =>
      rcldartbindings.rcl_service_is_valid(nativeService);

  void dispose() {
    // rcl_service_fini requires the owning node; left to the Node lifecycle.
    print('Disposing service "$serviceName"');
  }
}
