//
//  AppDelegate.h
//
//

#import <UIKit/UIKit.h>

@class VNCViewController;
@class SCWifiConnection;

@interface AppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    VNCViewController *viewController;
    
    SCWifiConnection *wifiLogConnection; // nil unless LOG_TO_WIFI is set
    NSString *syslogHost;
}
@property (nonatomic, retain) NSString *syslogHost;

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet VNCViewController *viewController;

#if LOG_TO_WIFI
- (void)wifiLog:(NSString *)str;
#endif

@end

