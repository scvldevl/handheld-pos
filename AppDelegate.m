//
//  AppDelegate.m
//
//

#import "AppDelegate.h"
#import "VNCViewController.h"
#import "VStore.h"

#import "SCServerProtocolController.h"

#if !LOG_TO_WIFI
#undef LOG_TO_WIFI
#define LOG_TO_WIFI 0
#endif

#if LOG_TO_WIFI
#import "SCWifiConnection.h"
#import "WiFiSessionController.h"
#endif

#if SEND_SYSLOG
#import "GCDAsyncUdpSocket.h"
#define SYSLOG_PORT 514


#endif

@implementation AppDelegate

@synthesize window;
@synthesize viewController;
@synthesize syslogHost;


#if SEND_SYSLOG
void SCLogToSyslog(NSString *fmt, ...) {
    static GCDAsyncUdpSocket *sock = nil;
    
    if(sock==nil) {
        sock = [[GCDAsyncUdpSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];
    }
    
    va_list ap;
    va_start(ap, fmt);
    NSString *output = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    
    const char *outputC = [output cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *payload = [NSData dataWithBytes:outputC length:strlen(outputC)];
    
    NSString *host = [(AppDelegate *)[[UIApplication sharedApplication] delegate] syslogHost];
    //[sock sendData:payload toHost:host port:SYSLOG_PORT withTimeout:45.0 tag:0];
    [sock sendData:payload toHost:@"192.168.1.8" port:SYSLOG_PORT withTimeout:45.0 tag:0];
}
#endif

#if LOG_TO_WIFI
- (void)wifiLog:(NSString *)str
{
    [[WiFiSessionController sharedController] wifiLog:str];
}
#endif

//MARK: -

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{    
#if LOG_TO_WIFI
    wifiLogConnection = [[SCWifiConnection alloc] init];
    [wifiLogConnection startBrowsing];
#endif

	[application setStatusBarHidden:YES]; // Make some more space onscreen for the VNC view
	
    application.applicationSupportsShakeToEdit = YES;

    [window setMultipleTouchEnabled:YES];
    [window setRootViewController:viewController];
    //[window addSubview:viewController.view];
    [window makeKeyAndVisible];
        

    [[SCServerProtocolController sharedController] start];

    return YES;
}


- (void)dealloc 
{
    [viewController release];
    [window release];
    [wifiLogConnection release];
	
    [super dealloc];
}


//MARK: 
#define USE_VERIFONE_BACKGROUND_NOTIFICATIONS (0)

- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
    
    
#if USE_VERIFONE_BACKGROUND_NOTIFICATIONS
    // abort scanning so button won't be in dumb flashlight mode after ipod is sleeping...

    [[VStore sharedVStore] barcodeScanOffWhileSleeping];
	
    DLog(@"%@", @"willResignActive: call disconnect vx600...");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DisconnectVX600" object:nil];
	
    
	//    [[[VStore sharedVStore] pinPad] closeDevice]; 
	//    [[[VStore sharedVStore] barcode] closeDevice]; 
	//    [[[VStore sharedVStore] payControl] closeDevice]; 
#endif
    
#if LOG_TO_WIFI
    [wifiLogConnection stopBrowsing];
#endif

}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
    
    [[SCServerProtocolController sharedController] stop];
	
}



- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
    
    [[SCServerProtocolController sharedController] start];

}

- (void) barcodeTurnOnTimerFired :(NSTimer *)timer  
{
	//    [[[VStore sharedVStore] pinPad] initDevice]; 
	//    [[[VStore sharedVStore] barcode] initDevice]; 
	//    [[[VStore sharedVStore] payControl] initDevice]; 
	
    [[VStore sharedVStore] barcodeScanOnAfterSleeping]; 
}

- (void)applicationDidBecomeActive:(UIApplication *)application 
{
    //Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
#if USE_VERIFONE_BACKGROUND_NOTIFICATIONS
    [[VStore sharedVStore] barcodeScanOnAfterSleeping];  
    
    DLog(@"%@", @"applicationDidBecomeActive: Wake up barcode in DidBecomeActive...");
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ConnectVX600Notification object:nil];
    
	// Monk: could replace with performSelector...after delay and get rid of all this...
	
	[self performSelector:@selector(barcodeTurnOnTimerFired:) withObject:nil afterDelay:0.5];	
#endif
    
#if LOG_TO_WIFI
    [wifiLogConnection startBrowsing];
#endif
    
    static BOOL oneShot = YES;
   if (!oneShot)
    {
        oneShot = NO;
        [[SCServerProtocolController sharedController] performSelector:@selector(start) withObject:nil afterDelay:0.5];
    }

}


- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
    [[VStore sharedVStore] enablePassthroughXCodeDebugging:NO];
	/*    [[[VStore sharedVStore] barcode] closeDevice]; 
	 [[[VStore sharedVStore] pinPad] closeDevice]; 
	 [[[VStore sharedVStore] payControl] closeDevice]; 
	 
	 [[[VStore sharedVStore] barcode] release]; 
	 [[[VStore sharedVStore] pinPad] release]; 
	 [[[VStore sharedVStore] payControl] release]; 
	 
	 [[[VStore sharedVStore] barcode] dealloc]; 
	 [[[VStore sharedVStore] pinPad] dealloc]; 
	 [[[VStore sharedVStore] payControl] dealloc]; 
	 
	 */
}

@end
