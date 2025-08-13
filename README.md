# rcldart

A new binding Flutter and Dart for the ROS2

## Getting Started

### Pritimitives
![primitives](./docs/images/primitives.png)

### Integers
![integers](./docs/images/integers.png)

### Floats
![floats](./docs/images/floats.png)

### Complex
![complex](./docs/images/complex.png)

### Received
![received](./docs/images/received.png)

```bash
ros2 topic pub /chatter std_msgs/String "data: Hello ROS Developers" 
```
```bash
ros2 topic pub /std_msgs/float32 std_msgs/Float32 "data: 3.14159" 
```

```bash
ros2 topic pub /std_msgs/float64 std_msgs/Float64 "data: 2.718281828"
```

logs:

```bash
flutter: 📊 Float32 message: 3.141590118408203
flutter: 📈 Float64 message: 2.718281828
flutter: 📦 Raw message data: Hello ROS Developers
flutter: 📊 Float32 message: 3.141590118408203
flutter: 📈 Float64 message: 2.718281828
flutter: 📦 Raw message data: Hello ROS Developers
flutter: 📊 Float32 message: 3.141590118408203
flutter: 📈 Float64 message: 2.718281828
flutter: 📦 Raw message data: Hello ROS Developers
flutter: 📊 Float32 message: 3.141590118408203
flutter: 📈 Float64 message: 2.718281828
flutter: 📦 Raw message data: Hello ROS Developers
flutter: 📊 Float32 message: 3.141590118408203
flutter: 📈 Float64 message: 2.718281828
```


## Supporting ROS2

- [ ] Jazzy
- [x] Humble
- [ ] Galactic (EOL)

## Supporting DDS

- [x] FastDDS

## Progress

- [x] Zero copy
- [x] Custom memory allocator
- [x] Topic (Pub/Sub)
- [ ] Service (Client/Server)
- [?] Asynchronous programming (async/await)
- [x] Callback based programming
- [x] Logging
- [x] Signal handling
- [ ] Parameter
- [x] Timer
- [ ] Action (service + topic)