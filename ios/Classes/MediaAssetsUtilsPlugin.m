#import "MediaAssetsUtilsPlugin.h"
#if __has_include(<media_assets_utils/media_assets_utils-Swift.h>)
#import <media_assets_utils/media_assets_utils-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "media_assets_utils-Swift.h"
#endif

@implementation MediaAssetsUtilsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftMediaAssetsUtilsPlugin registerWithRegistrar:registrar];
}
@end
