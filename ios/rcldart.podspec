#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint rcldart.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'rcldart'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter FFI plugin project.'
  s.description      = <<-DESC
A new Flutter FFI plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  # ROS 2 (rmw/rcpputils/Fast-DDS) needs a modern deployment target.
  s.platform = :ios, '14.0'

  # Bundle the cross-compiled ROS 2 dylibs (staged by tool/build_ros2_apple.sh
  # into ios/ros/{device,sim}/lib) into the app bundle. CocoaPods embeds and
  # code-signs vendored dynamic libraries into Frameworks/, which is what lets
  # rcl dlopen() the rmw + typesupport plugins at runtime with NO ROS installed.
  # NOTE: device (aarch64-apple-ios) and simulator (…-sim) dylibs are separate
  # trees; pick with the LIBRARY_SEARCH_PATHS below. Vendor device libs by
  # default — for simulator builds re-point this glob to ros/sim/lib.
  s.vendored_libraries = 'ros/device/lib/*.dylib'
  s.preserve_paths = ['ros/**/*']

  # Ship the ament index (typesupport discovery) as a bundle resource; the app
  # sets AMENT_PREFIX_PATH to it at startup (see AppleRosBootstrap in the docs).
  s.resource_bundles = { 'rcldart_ros' => ['ros/device/share'] }

  # Automatic ROS 2 closure fetch (zenoh_ffi-style, at `pod install`). Downloads
  # a prebuilt closure (produced by tool/build_ros2_apple.sh + package_ros_bundle.sh)
  # into ros/ if absent and RCLDART_ROS_BUNDLE_URL_IOS is set. No-op otherwise —
  # the app still builds; bundle manually per docs/apple_ros2_architecture.md.
  s.prepare_command = <<-CMD
    set -e
    if [ -f ros/device/lib/librcl.dylib ]; then echo "rcldart: iOS ROS closure present"; exit 0; fi
    if [ -z "${RCLDART_ROS_BUNDLE_URL_IOS:-}" ]; then
      echo "rcldart: RCLDART_ROS_BUNDLE_URL_IOS not set — bundle manually (docs/apple_ros2_architecture.md)"; exit 0; fi
    echo "rcldart: fetching iOS ROS closure from $RCLDART_ROS_BUNDLE_URL_IOS"
    mkdir -p ros
    curl -sL "$RCLDART_ROS_BUNDLE_URL_IOS" -o /tmp/rcldart-ros-ios.tar.gz
    tar xzf /tmp/rcldart-ros-ios.tar.gz -C ros && rm -f /tmp/rcldart-ros-ios.tar.gz
    echo "rcldart: iOS ROS closure extracted into ros/"
  CMD

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework does not contain a i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'LIBRARY_SEARCH_PATHS[sdk=iphoneos*]'        => '$(inherited) "${PODS_TARGET_SRCROOT}/ros/device/lib"',
    'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(inherited) "${PODS_TARGET_SRCROOT}/ros/sim/lib"',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @loader_path/Frameworks',
  }
  s.swift_version = '5.0'
end
