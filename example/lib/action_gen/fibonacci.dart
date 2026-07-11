// generated from rosidl_generator_dart (test harness)
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:rcldart_utils/rcldart_utils.dart';

final class rosidl_runtime_c__int32__Sequence extends ffi.Struct {
  external ffi.Pointer<ffi.Int32> data;
  @ffi.Size()
  external int size;
  @ffi.Size()
  external int capacity;
}

// ---- example_interfaces__action__Fibonacci_Goal ----
base class example_interfaces__action__Fibonacci_Goal extends ffi.Struct {
  @ffi.Int32()
  external int order;
}

class ExampleInterfacesFibonacci_Goal extends BaseRosMessage<example_interfaces__action__Fibonacci_Goal> {
  @override
  String get typeName => 'Fibonacci_Goal';
  @override
  String get packageName => 'example_interfaces';

  ExampleInterfacesFibonacci_Goal() {
    data = calloc<example_interfaces__action__Fibonacci_Goal>();
  }

  int get order =>
      data.ref.order;
  set order(int val) =>
      data.ref.order = val;
}

// ---- example_interfaces__action__Fibonacci_Result ----
base class example_interfaces__action__Fibonacci_Result extends ffi.Struct {
  external rosidl_runtime_c__int32__Sequence sequence;
}

class ExampleInterfacesFibonacci_Result extends BaseRosMessage<example_interfaces__action__Fibonacci_Result> {
  @override
  String get typeName => 'Fibonacci_Result';
  @override
  String get packageName => 'example_interfaces';

  ExampleInterfacesFibonacci_Result() {
    data = calloc<example_interfaces__action__Fibonacci_Result>();
  }

  List<int> get sequence {
    final s = data.ref.sequence;
    return List.generate(s.size, (i) => s.data[i]);
  }
  set sequence(List<int> value) {
    final a = calloc<ffi.Int32>(value.length);
    for (var i = 0; i < value.length; i++) {
      a[i] = value[i];
    }
    data.ref.sequence.data = a;
    data.ref.sequence.size = value.length;
    data.ref.sequence.capacity = value.length;
  }
}

// ---- example_interfaces__action__Fibonacci_Feedback ----
base class example_interfaces__action__Fibonacci_Feedback extends ffi.Struct {
  external rosidl_runtime_c__int32__Sequence sequence;
}

class ExampleInterfacesFibonacci_Feedback extends BaseRosMessage<example_interfaces__action__Fibonacci_Feedback> {
  @override
  String get typeName => 'Fibonacci_Feedback';
  @override
  String get packageName => 'example_interfaces';

  ExampleInterfacesFibonacci_Feedback() {
    data = calloc<example_interfaces__action__Fibonacci_Feedback>();
  }

  List<int> get sequence {
    final s = data.ref.sequence;
    return List.generate(s.size, (i) => s.data[i]);
  }
  set sequence(List<int> value) {
    final a = calloc<ffi.Int32>(value.length);
    for (var i = 0; i < value.length; i++) {
      a[i] = value[i];
    }
    data.ref.sequence.data = a;
    data.ref.sequence.size = value.length;
    data.ref.sequence.capacity = value.length;
  }
}

// ---- ExampleInterfacesFibonacci (action) ----
class ExampleInterfacesFibonacci
    extends BaseRosAction<ExampleInterfacesFibonacci_Goal, ExampleInterfacesFibonacci_Result, ExampleInterfacesFibonacci_Feedback> {
  @override
  String get typeName => 'Fibonacci';
  @override
  String get packageName => 'example_interfaces';

  @override
  ExampleInterfacesFibonacci_Goal createGoal() => ExampleInterfacesFibonacci_Goal();

  @override
  ExampleInterfacesFibonacci_Result createResult() => ExampleInterfacesFibonacci_Result();

  @override
  ExampleInterfacesFibonacci_Feedback createFeedback() => ExampleInterfacesFibonacci_Feedback();
}
