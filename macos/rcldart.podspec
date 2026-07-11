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
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  # ROS 2 needs a modern macOS deployment target.
  s.platform = :osx, '11.0'

  # Bundle the cross-compiled ROS 2 dylibs (staged by tool/build_ros2_apple.sh
  # into macos/ros/lib) into the .app so rcl can dlopen the rmw + typesupport
  # plugins with NO ROS installed. On macOS you can alternatively point at a
  # system ROS install and drop this — see docs/ios_macos_support.md.
  s.vendored_libraries = 'ros/lib/*.dylib'
  s.preserve_paths = ['ros/**/*']
  s.resource_bundles = { 'rcldart_ros' => ['ros/share'] }

  # Automatic ROS 2 closure fetch (zenoh_ffi-style, at `pod install`). Downloads
  # a prebuilt closure into ros/ if absent and RCLDART_ROS_BUNDLE_URL_MACOS is set.
  # No-op otherwise (dev Macs typically use a system ROS instead).
  s.prepare_command = <<-CMD
    set -e
    if [ -f ros/lib/librcl.dylib ]; then echo "rcldart: macOS ROS closure present"; exit 0; fi
    if [ -z "${RCLDART_ROS_BUNDLE_URL_MACOS:-}" ]; then
      echo "rcldart: RCLDART_ROS_BUNDLE_URL_MACOS not set — using system ROS or bundle manually"; exit 0; fi
    echo "rcldart: fetching macOS ROS closure from $RCLDART_ROS_BUNDLE_URL_MACOS"
    mkdir -p ros
    curl -sL "$RCLDART_ROS_BUNDLE_URL_MACOS" -o /tmp/rcldart-ros-macos.tar.gz
    tar xzf /tmp/rcldart-ros-macos.tar.gz -C ros && rm -f /tmp/rcldart-ros-macos.tar.gz
    echo "rcldart: macOS ROS closure extracted into ros/"
  CMD

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'LIBRARY_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/ros/lib"',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/../Frameworks @loader_path/Frameworks',
  }
  s.swift_version = '5.0'
end
