# Services, Parameters & Actions

This document covers the service/client, parameter and action support added to
`rcldart`.

---

## 1. Services (Client / Server) — ✅ implemented

Services are fully wired to `rcl` (`rcl_service_init`, `rcl_client_init`,
`rcl_send_request` / `rcl_take_response`, `rcl_take_request` /
`rcl_send_response`). A service is a Request/Response pair.

### Binding a service type

Every generated service exports a C symbol
`rosidl_typesupport_c__get_service_type_support_handle__<pkg>__srv__<Srv>`.
Subclass `BaseRosService` (from `rcldart_utils`, the service analogue of
`BaseRosMessage`) — set `typeName` + `packageName` and provide fresh
Request/Response buffers. The Request and Response are ordinary `BaseRosMessage`
structs (generated the same way `std_msgs` types are).

```dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:rcldart/rcldart.dart';
import 'package:rcldart_utils/rcldart_utils.dart';
import 'package:rcldart/src/gen/rcldart_bindings_generated.dart';

// --- generated-style message structs for example_interfaces/srv/AddTwoInts ---
base class add_two_ints__request extends Struct {
  @Int64() external int a;
  @Int64() external int b;
}
base class add_two_ints__response extends Struct {
  @Int64() external int sum;
}

class AddTwoIntsRequest extends BaseRosMessage<add_two_ints__request> {
  @override
  String get typeName => 'AddTwoInts_Request';
  AddTwoIntsRequest() { data = calloc<add_two_ints__request>(); }
  int get a => data.ref.a;       set a(int v) => data.ref.a = v;
  int get b => data.ref.b;       set b(int v) => data.ref.b = v;
}

class AddTwoIntsResponse extends BaseRosMessage<add_two_ints__response> {
  @override
  String get typeName => 'AddTwoInts_Response';
  AddTwoIntsResponse() { data = calloc<add_two_ints__response>(); }
  int get sum => data.ref.sum;   set sum(int v) => data.ref.sum = v;
}

class AddTwoInts extends BaseRosService<AddTwoIntsRequest, AddTwoIntsResponse> {
  @override
  String get typeName => 'AddTwoInts';
  @override
  String get packageName => 'example_interfaces';
  // fullTypeName -> example_interfaces__srv__AddTwoInts
  // typeSupportName + rosidlGeneratorDylib are derived automatically.
  @override
  AddTwoIntsRequest createRequest() => AddTwoIntsRequest();
  @override
  AddTwoIntsResponse createResponse() => AddTwoIntsResponse();
}
```

### Server

```dart
final node = RclDart().createNode('adder', 'examples');

final service = node.createService<AddTwoIntsRequest, AddTwoIntsResponse>(
  serviceName: '/add_two_ints',
  serviceType: AddTwoInts(),
  handler: (req) {
    final res = AddTwoIntsResponse();
    res.sum = req.a + req.b;
    return res;
  },
);

// Drive it like the subscriber polling in the example:
Timer.periodic(const Duration(milliseconds: 50), (_) => service.spin());
```

Test from a shell:

```bash
ros2 service call /add_two_ints example_interfaces/srv/AddTwoInts "{a: 2, b: 3}"
```

### Client

```dart
final client = node.createClient<AddTwoIntsRequest, AddTwoIntsResponse>(
  serviceName: '/add_two_ints',
  serviceType: AddTwoInts(),
);

final req = AddTwoIntsRequest()..a = 2..b = 3;
final res = await client.call(req);          // awaits the reply
print('2 + 3 = ${res.sum}');
```

`call()` polls `takeResponse` on a timer (the whole plugin is currently
poll-based) and matches the reply by sequence number. For manual control use
`sendRequest()` / `takeResponse()` directly.

---

## 2. Parameters — ✅ Dart-side + ROS-exposed (validate on device)

`NodeParameters` is a node-local store with full ROS 2 declare/get/set
semantics, validation callbacks, read-only + typed enforcement and a
`parameter_events`-style stream. Usable today for app configuration:

```dart
final params = NodeParameters();
params.declare(Parameter.int('max_speed', 10),
    descriptor: const ParameterDescriptor(
        name: 'max_speed', type: ParameterType.integer));

params.addOnSetParametersCallback((updates) {
  for (final p in updates) {
    if (p.name == 'max_speed' && p.asInt < 0) {
      return SetParametersResult.rejected('max_speed must be >= 0');
    }
  }
  return SetParametersResult.ok();
});

params.set([Parameter.int('max_speed', 25)]);   // validated + applied
print(params.get('max_speed').asInt);            // 25
```

### Exposing over ROS 2

`NodeParameters.attachToRos(node, executor: executor)` registers the standard
parameter services so `ros2 param ...` and other nodes can reach the store:

```dart
final executor = Executor()..addSubscription(sub);
final params = NodeParameters()
  ..declare(Parameter.int('max_speed', 10))
  ..declare(Parameter.string('mode', 'idle'));

params.attachToRos(node, executor: executor); // creates the services
executor.spin();                               // services them
```

```bash
ros2 param list /flutter_node
ros2 param get  /flutter_node max_speed
ros2 param set  /flutter_node max_speed 25
```

Implemented services: `~/get_parameters`, `~/get_parameter_types`,
`~/set_parameters`, `~/set_parameters_atomically`, `~/list_parameters`.
Backed by hand-written `rcl_interfaces` bindings
(`lib/src/msgs/_rcl_interfaces_types.dart`) and the [Service](#1-services-client--server)
infrastructure; native message content is manipulated through FFI struct views.
Scalar parameters (bool/int/double/string) are fully translated; array-valued
parameters, `~/describe_parameters` and the `~/parameter_events` publisher are
follow-ups. **This path talks to FastDDS and should be validated on a live ROS 2
system.**

---

## 3. Executor (wait_set) — ✅ implemented

`Executor` replaces the ad-hoc `Timer.periodic(... take())` polling with the
proper rcl idiom: it asks `rcl_wait` which entities actually have work pending
and dispatches only those.

```dart
final executor = Executor(); // uses the default context
executor.addSubscription(mySubscriber);
executor.addService(myService);
executor.addClient(myClient); // client needs an onResponse handler

executor.spin(); // non-blocking, safe on the Flutter UI isolate
// ... later:
executor.stop();
```

`spin()` drives `spinOnce(timeout: Duration.zero)` from a `Timer.periodic` so it
never blocks the Dart isolate. For a dedicated background isolate you can call
`spinOnce(timeout: ...)` with a real (blocking) timeout. Timers are not yet
wrapped as rcl entities, so they are not added to the wait_set.

---

## 4. Actions — 🔜 model ready, native wiring pending

`lib/src/action.dart` provides the complete goal lifecycle model
(`GoalStatus`, `GoalUUID`, `GoalHandle` with feedback stream + result future)
and the `ActionClient` / `ActionServer` API surface.

The native `rcl_action` functions are **not** in the generated bindings yet —
`rcl_action` ships in the `ros2/rcl` repo but was not among ffigen's
entry-points. To enable actions:

1. `vcs import src < src/ros2.repos` — pulls the `rcl_action` headers.
2. The `rcl_action` entry-point is already added to `ffigen.yaml`; regenerate:
   `flutter pub run ffigen --config ffigen.yaml`.
3. Implement the `TODO(rcl_action)` sections in `action.dart` against the new
   bindings (`rcl_action_send_goal_request`, `rcl_action_take_feedback`,
   `rcl_action_take_result_response`, `rcl_action_send_cancel_request`, and the
   server-side counterparts).

An action is 3 services (send_goal, cancel_goal, get_result) + 2 topics
(feedback, status); the `GoalHandle` state machine already models all of it.
