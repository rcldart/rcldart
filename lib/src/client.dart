// src/client.dart
//
// A ROS 2 service *client*: sends a Request to a service server and receives
// the matching Response.
//
// Low-level rcl flow:
//   rcl_send_request(client, request, &sequence_number)   // async send
//   ... server processes ...
//   rcl_take_response(client, &request_header, response)   // poll for reply
//
// Responses are correlated with requests through the `sequence_number`
// returned by `rcl_send_request` and echoed back in the response header.
// Pending requests are tracked in [_pending] so that both the [Executor]
// (event-driven) and the standalone self-polling [call] complete the correct
// future.
import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;
import 'package:rcldart_utils/rcldart_utils.dart';

import 'rcldart.dart';
import 'gen/rcldart_bindings_generated.dart';

class Client<Req extends BaseRosMessage, Resp extends BaseRosMessage> {
  final Pointer<rcl_client_t> nativeClient;
  final BaseRosService<Req, Resp> serviceType;
  final String serviceName;

  /// Optional callback for executor-driven, callback-style usage. Fired for
  /// every response taken (in addition to completing any pending [call]).
  void Function(Resp response)? onResponse;

  /// Outstanding requests awaiting their response, keyed by sequence number.
  final Map<int, Completer<Resp>> _pending = {};

  Client(this.nativeClient, this.serviceType, this.serviceName,
      {this.onResponse});

  bool get hasPending => _pending.isNotEmpty;

  /// Sends [request] and returns the sequence number assigned by rcl.
  int sendRequest(Req request) {
    if (request.data == nullptr) {
      throw ArgumentError('Request message data cannot be null');
    }

    final sequenceNumber = ffi.calloc<Int64>();
    try {
      final rc = rcldartbindings.rcl_send_request(
          nativeClient, request.data.cast<Void>(), sequenceNumber);
      if (rc != RCL_RET_OK) {
        throw Exception('rcl_send_request failed with code: $rc');
      }
      return sequenceNumber.value;
    } finally {
      ffi.calloc.free(sequenceNumber);
    }
  }

  /// Attempts to take one available response into [response].
  ///
  /// Returns the sequence number of the response taken, or `null` when none is
  /// available (`RCL_RET_CLIENT_TAKE_FAILED`).
  int? takeResponse(Resp response) {
    if (response.data == nullptr) {
      throw ArgumentError('Response message data cannot be null');
    }

    final header = ffi.calloc<rmw_request_id_t>();
    try {
      final rc = rcldartbindings.rcl_take_response(
          nativeClient, header, response.data.cast<Void>());
      if (rc == RCL_RET_OK) {
        return header.ref.sequence_number;
      } else if (rc == RCL_RET_CLIENT_TAKE_FAILED) {
        return null; // no response ready yet
      } else {
        throw Exception('rcl_take_response failed with code: $rc');
      }
    } finally {
      ffi.calloc.free(header);
    }
  }

  /// Drains all currently available responses, completing matching [call]
  /// futures and invoking [onResponse]. Called by the [Executor] when this
  /// client's slot is ready; also used by [call]'s self-polling.
  void processReady() {
    while (true) {
      final response = serviceType.createResponse(); // fresh buffer per take
      final seq = takeResponse(response);
      if (seq == null) break;

      final completer = _pending.remove(seq);
      if (completer != null && !completer.isCompleted) {
        completer.complete(response);
      }
      onResponse?.call(response);
    }
  }

  /// Sends [request] and returns a [Future] that completes with the matching
  /// response.
  ///
  /// When an [Executor] is driving this client, set [autoSpin] to `false` and
  /// let the executor call [processReady]. Otherwise (the default) the future
  /// self-polls on a timer, so it works without any executor.
  Future<Resp> call(
    Req request, {
    Duration pollInterval = const Duration(milliseconds: 20),
    Duration timeout = const Duration(seconds: 5),
    bool autoSpin = true,
  }) {
    final seq = sendRequest(request);
    final completer = Completer<Resp>();
    _pending[seq] = completer;

    Timer? poller;
    if (autoSpin) {
      poller = Timer.periodic(pollInterval, (_) {
        if (completer.isCompleted) {
          poller?.cancel();
          return;
        }
        try {
          processReady();
        } catch (e) {
          poller?.cancel();
          _pending.remove(seq);
          if (!completer.isCompleted) completer.completeError(e);
        }
      });
    }

    return completer.future.timeout(timeout, onTimeout: () {
      poller?.cancel();
      _pending.remove(seq);
      throw TimeoutException(
          'Service "$serviceName" did not respond', timeout);
    });
  }

  /// Returns true once a server for this service has been discovered.
  bool get isValid => rcldartbindings.rcl_client_is_valid(nativeClient);

  void dispose() {
    // rcl_client_fini requires the owning node; left to the Node lifecycle.
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(StateError('Client disposed'));
      }
    }
    _pending.clear();
  }
}
