//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<flutter_ble_peripheral/FlutterBlePeripheralPlugin.h>)
#import <flutter_ble_peripheral/FlutterBlePeripheralPlugin.h>
#else
@import flutter_ble_peripheral;
#endif

#if __has_include(<permission_handler_apple/PermissionHandlerPlugin.h>)
#import <permission_handler_apple/PermissionHandlerPlugin.h>
#else
@import permission_handler_apple;
#endif

#if __has_include(<reactive_ble_mobile/ReactiveBlePlugin.h>)
#import <reactive_ble_mobile/ReactiveBlePlugin.h>
#else
@import reactive_ble_mobile;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [FlutterBlePeripheralPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterBlePeripheralPlugin"]];
  [PermissionHandlerPlugin registerWithRegistrar:[registry registrarForPlugin:@"PermissionHandlerPlugin"]];
  [ReactiveBlePlugin registerWithRegistrar:[registry registrarForPlugin:@"ReactiveBlePlugin"]];
}

@end
