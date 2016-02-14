//
//  VNCViewController.m
//
//  -Monk

#import <QuartzCore/QuartzCore.h>
#import <CoreMotion/CoreMotion.h>

// COTVNC headers
#import "VNCViewController.h"
#import "ServerBase.h"
#import "RFBConnection.h"
#import "QueuedEvent.h"

// Shoe Carnival app
#import "VStore.h"

#import "SCServerSetupViewController.h"
#import "NavViewController.h"
#import "SCServerProtocolController.h"
#import "SCServerPublicKeyDownloadController.h"
#import "SC_VX600_LCDMessageDisplayQueue.h"

// Verifone test screen // this will go away or be modified
#import "simpleCardSwipeViewController.h"

#import "AppDelegate.h"
#import "MBProgressHUD.h"
#import "UIView+Utils.h"
#import "UIButton+Utils.h"
#import "NSString+Utils.h"
#import "EAAccessoryManager+Utils.h"
#import "UIAlertView+Utils.h"

#import "DebugSheetViewController.h"


#define SENTINEL '['

@interface VNCViewController ()
@property (nonatomic, retain) CMMotionManager *motionManager;

- (void)connectToVNC;
- (void)connectWithExternalAccessory;
- (void)initVerifoneDevice;
- (void)configServer;
- (void)showVerifoneTestScreen;
- (void)revealButtonOverlayView;
- (void)hideButtonOverlayView;

- (void)signatureDataRequested:(NSNotification *)note; // temporarily here for testing via swipe gesture
- (void)getPinFromUserForAccount:(NSString *)requestedAccountNumber;
@end

@implementation VNCViewController
@synthesize vncView, signatureViewController, buttonOverlayView;

const unsigned long STATUS_BAR_OFFSET = 20; // offset vnc view so as not to overlap status bar

- (void)redirectConsoleLogToDocumentFolder
{
    // Can be useful for debugging when 30-pin blocked by Verifone unit
    
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
														 NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *logPath = [documentsDirectory
						 stringByAppendingPathComponent:@"console.log"];
	freopen([logPath cStringUsingEncoding:NSASCIIStringEncoding],"a+",stderr);
}

- (void)testTyping
{
	[vncConnection sendKey:'1' pressed:YES];
	[vncConnection sendKey:'1' pressed:NO];
	[vncConnection sendKey:'2' pressed:YES];
	[vncConnection sendKey:'2' pressed:NO];
	[vncConnection sendKey:'3' pressed:YES];
	[vncConnection sendKey:'3' pressed:NO];
	[vncConnection sendKey:'4' pressed:YES];
	[vncConnection sendKey:'4' pressed:NO];
}

#define MICROSECONDS_BETWEEN_BYTES 50000 // don't spit them out too fast - a VNC server is on the other side. Value determined by experiment

- (void)sendVNCKeypressesFromString:(NSString *)str
{
    NSMutableString *s = [[NSMutableString alloc] initWithCapacity:100];
    [s appendString:@"==== SEND TO VNC > 0x02 "];

    [vncConnection sendKey:SENTINEL pressed:YES];   // ^B start byte
	[vncConnection sendKey:SENTINEL pressed:NO];
//    usleep(MICROSECONDS_BETWEEN_BYTES); 

    for (NSInteger i = 0; i < [str length]; i++) {
        unichar c = [str characterAtIndex:i];;
        [vncConnection sendKey:c pressed:YES];
        [vncConnection sendKey:c pressed:NO];
        [s appendFormat:@"0x%2x ", c];
        usleep(MICROSECONDS_BETWEEN_BYTES);
    }
    [vncConnection sendKey:0x0d pressed:YES];   // <cr> end byte
	[vncConnection sendKey:0x0d pressed:NO];
    [s appendString:@"0x0d < ===="];

    NSLog(@"%@",s);
    [s release];
}

//MARK: Gesture recognizers

// Gsesture recognizer to forward screen taps to the VNC server as "mouse clicks"
- (IBAction)handleTapGesture:(UITapGestureRecognizer *)sender 
{
    [self hideButtonOverlayView];
    
	// do nothing if no valid connection
	if (![vncConnection frameBuffer]) {
		return;
	}
	
    CGPoint tapPoint = [sender locationInView:sender.view.superview];
	
	// Move to new location on remote VNC screen
	// and issue a VNC "mouse click"
	[vncConnection mouseAt:tapPoint buttons: 0];					// move to new point with no mouse buttons down (i.e., not a mouse drag)
	[vncConnection mouseAt:tapPoint buttons: rfbButton1Mask];       // mouse down at point
	[vncConnection mouseAt:tapPoint buttons: 0];					// mouse up at point
}

- (void)revealButtonOverlayView
{
    CGRect r = self.buttonOverlayView.frame;
    r.origin.y = self.view.frame.size.height - r.size.height;
    
    [UIView beginAnimations:@"revealButtonOverlayView" context:nil];
    self.buttonOverlayView.frame = r;
    [UIView commitAnimations];
}

- (void)hideButtonOverlayView
{
    CGRect r = self.buttonOverlayView.frame;
    r.origin.y = self.view.frame.size.height + r.size.height + 1.0;
    
    [UIView beginAnimations:@"hideButtonOverlayView" context:nil];
    self.buttonOverlayView.frame = r;
    [UIView commitAnimations];
}

// Gesture recognizer to reveal the server setup view.
// May have to experiment with direction / numberOfTouchesRequired
// once have a working SC VNC server and/or get feedback from users
- (IBAction)handleSwipeGesture:(UISwipeGestureRecognizer *)recognizer
{    
	DLog(@"Swipe gesture detected, direction is:%lu, numTouches:%lu", (unsigned long)[recognizer direction], (unsigned long)[recognizer numberOfTouches]);

	// note that self.vncView has an inverse transform, so may have to use oposite directions here...
	
	if ([recognizer direction] & UISwipeGestureRecognizerDirectionUp) {
        // Show button overlay view
        [self revealButtonOverlayView];
    }
    
    else if ([recognizer direction] & UISwipeGestureRecognizerDirectionRight) {
		// Bring out server setup panel
		[self configServer];
	}
    
    else if ([recognizer direction] & UISwipeGestureRecognizerDirectionLeft /* && [recognizer numberOfTouches] == 2*/) {
        // For easier testing, swipe shows sig view in DEBUG builds without needing to process a card purchase
#if DEBUG
        [self signatureDataRequested:nil];
#endif

    }
}

- (void) handleSecondSwipeGesture:(id)sender {
    self.dbg = [[[DebugSheetViewController alloc] initWithNibName:@"DebugSheetViewController" bundle:nil] autorelease];
    self.dbg.view.frame = self.view.frame;
    [self.view addSubview:self.dbg.view];
}


//MARK: -

- (void)configServer
{    
    SCServerSetupViewController *vc = [[[SCServerSetupViewController alloc] init] autorelease];
    [vc setDelegate:self];
    [self presentViewController:vc animated:YES completion:^{
        
        vc.serverAddressField.text = [serv host];
        
        vc.vncPortField.text = nil;
        if ([serv port]) {
            NSString *portString = [NSString stringWithFormat:@"%ld", [serv port]];
            vc.vncPortField.text = portString;
        }
        
        vc.passwordField.text = [serv password];
    }];
    
	// when SCServerSetupViewController is dismissed it calls its delegate's (us) serverSetupPanelDidEndWithIP method
}

- (void)showVerifoneTestScreen
{
    if (!verifoneTestScreenViewController) {
        verifoneTestScreenViewController = [[simpleCardSwipeViewController alloc] init];
    }
    
#if 0
    NavViewController *rootVC = [[[NavViewController alloc] init] autorelease];
    navVC = [[UINavigationController alloc] initWithRootViewController:rootVC];
    
    [self.view addSubview:navVC.view];
    navVC.navigationItem.title = @"Verifone Test";
    
    [navVC pushViewController:vc animated:YES];
#else
    
    UIButton *doneButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[doneButton setTitle:@"Done" forState:UIControlStateNormal];
	[doneButton addTarget:verifoneTestScreenViewController action:@selector(verifoneTestScreenDoneButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    CGRect r = CGRectMake(240.0, 416.0, 20.0, 20.0);
    doneButton.frame = r;
    [doneButton sizeToFit];
    
    [verifoneTestScreenViewController.view addSubview:doneButton];
	[self presentViewController:verifoneTestScreenViewController animated:YES completion:nil];
#endif
}

- (void)serverSetupPanelDidEndWithIP:(NSString *)IPAddress vncPort:(NSString *)vncPort password:(NSString *)password
{
    //[vncConnection setDelegate:nil]; // don't want didTerminate delegate messages when we're deliberately terminating

	[vncConnection terminateConnection:@""];

	[serv setName:@"SCVL"];
    [serv setHost:IPAddress];
	[serv setPort:[vncPort integerValue]];
    [serv setPassword:password];
    
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    //[d setObject:@"SCVL" forKey:@"SCHostNameString"];
    [d setObject:IPAddress forKey:@"SCHostAddrString"];
    
    NSNumber *port = nil;
    if ([vncPort integerValue]) {
        port = [NSNumber numberWithInteger:[vncPort integerValue]];
    }
    [d setObject:port forKey:@"SCHostPort"];
    
    [d setObject:password forKey:@"SCHostPasswordString"];
    
    [d synchronize];
    
    [vncConnection setDelegate:nil];
	[vncConnection release]; vncConnection = nil;
	
	[self performSelector:@selector(connectToVNC) withObject:nil afterDelay:0.0];
}

//MARK: -

- (void)fixScale
{
    UIScrollView *sv = (UIScrollView *)self.view;
    DLog(@"sv:%@ v:%@", NSStringFromCGRect([sv frame]), NSStringFromCGSize(_contentSize));

    CGSize vncsize = _contentSize;
    CGRect bounds = [sv bounds];

    double xmax = bounds.size.width, ymax = bounds.size.height;
    double xscale = xmax/vncsize.width, yscale = ymax/vncsize.height;
    double minscale = (xscale < yscale) ? xscale : yscale;
    [sv setMaximumZoomScale:1.0];
	
	// Original COTVNC code
    //[sv setMinimumZoomScale:minscale];
	// Shoe Carnival app does not zoom or scale (wouldn't make sense for a POS remote screen)
    [sv setMinimumZoomScale:1.0];

    [sv setZoomScale:minscale animated:YES];
}


// Should never happen in Shoe Carnival app
- (void)connection:(RFBConnection *)conn sizeChanged:(CGSize)vncsize
{
    UIScrollView *sv = (UIScrollView *)self.view;
    _contentSize = vncsize;
    [sv setContentSize:vncsize];
    [self fixScale];
}

//MARK: - View

- (void)loadView 
{
    [super loadView];

#if DEBUG & SPEAK_DEBUG_STRINGS
	[[GSKFlite sharedSpeechEngine] setVoice:@"cmu_us_kal"];
	[[GSKFlite sharedSpeechEngine] speakText:@"Audible logging enabled"]; //prime the speech engine to avoid delay on first speech
#endif
	
	//self.wantsFullScreenLayout = YES;
	
	// NOTE: Although a UIScrollView is used below as part of the COTVNC setup code,
	// the Shoe Carnival app currently does not scroll - it is assumed that it
	// will connect to VNC screens that match the device's screen size (or smaller).
	// Scrolling and scaling large screen could be added, but doesn't really make
	// sense for a small handheld point-of-sale device.
	
	//
	//original COTVNC setup code
	//
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7)
        self.automaticallyAdjustsScrollViewInsets = NO;
    
    CGRect rect = [[UIScreen mainScreen] bounds]; //CGRectMake(0,0,100,100);
    UIScrollView *sv = [[[UIScrollView alloc] initWithFrame:rect] autorelease];
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7) {
        // Needed to prevent overlapping status bar is iOS 7 & higher
        [sv setScrollIndicatorInsets:UIEdgeInsetsMake(STATUS_BAR_OFFSET, 0.0f, 0.0f, 0.0f)];
        [sv setContentInset:UIEdgeInsetsMake(STATUS_BAR_OFFSET, 0.0f, 0.0f, 0.0f)];
    }
        
    [sv setBackgroundColor:[UIColor grayColor]];
    [sv setDelegate:self];
	
	[sv setDirectionalLockEnabled:YES];
	[sv setScrollEnabled:NO];
	
    [sv setContentOffset:CGPointMake(0.0, 0.0) animated:NO];

    [sv setMultipleTouchEnabled:NO];
	
    [sv setAutoresizingMask:(UIViewAutoresizingFlexibleWidth |
			     UIViewAutoresizingFlexibleHeight)];
    [sv setAutoresizesSubviews:NO];
    
    //[sv setScrollsToTop:NO];
	
#if 0 // unneeded in SC app
    [sv setBouncesZoom:YES];
    [sv setAlwaysBounceHorizontal:YES];
    [sv setAlwaysBounceVertical:YES];
#endif
	
    self.view = sv;
    
    VNCContentView *v = [[[VNCContentView alloc] initWithFrame:[sv bounds]] autorelease];
	[v setBackgroundColor:[UIColor blueColor]];
    [v setDelegate:self];
    [sv addSubview:v];
    self.vncView = v;

	//
	// end original COTVNC setup code
	//

}
   
- (void)connection:(RFBConnection *)connection hasTerminatedWithReason:(NSString *)reason
{
    DLog(@"VNC connection terminated %@", reason);

    [[VStore sharedVStore] enableCardScanner:NO];  // no card scan if no VNC connection

    NSString *msg = @"";
    if (!isEmptyString(reason)) {
        msg = [NSString stringWithFormat:@"Termination reason:\r%@", reason];
    }
    [UIAlertView displayAlertOnNextRunLoopInvocationWithTitle:@"VNC Connection Terminated"
                                                      message:msg
                                                     delegate:self
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitle:nil];
    
    [self.vncView setNeedsDisplay];
    
    [vncConnection setDelegate:nil];
    [vncConnection release];
    vncConnection = nil;
    
    // Good idea from Jim, but in practice is an infinite loop of requesting VNC loging and failing if no server exists
    //[self performSelector:@selector(configServer) withObject:nil afterDelay:1.0];
}

- (void)connectToVNC
{	
	hudView = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
	[hudView setLabelText:@"Connecting to Server..."];
	NSString *detailLabel = [NSString stringWithFormat:@"%@:%ld", [serv host], [serv port]];
	[hudView setDetailsLabelText:detailLabel];
	
    vncConnection = [[RFBConnection alloc] initWithServer:serv 
												  profile:[Profile defaultProfile]
													 view:self.vncView];   
    __block BOOL success = NO;
    __block NSString *errMsg = nil;
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        success = [vncConnection openConnectionReturningError:&errMsg];
    });

    BOOL verifoneProtocolExists = [VStore verifoneEAAccessoryProtocolExists];


    if(! verifoneDeviceInitDone  && verifoneProtocolExists) {
        [hudView setLabelText:@"Initializing Verifone device..."];
        [hudView setDetailsLabelText:@""];
    } else {
        [hudView hide:YES];
    }

    if(!success) {
        
        [vncConnection release];
        vncConnection = nil;

        [UIAlertView displayAlertOnNextRunLoopInvocationWithTitle:@"No VNC Connection"
                                                          message:errMsg
                                                         delegate:self
                                                cancelButtonTitle:@"OK"
                                                otherButtonTitle:nil];
        DLog(@"No VNC Connection:%@", errMsg);
		[self.vncView setNeedsDisplay]; // erase current content
	} else {
        [vncConnection setDelegate:self];
		[vncConnection startTalking];
        
        [[SCServerPublicKeyDownloadController sharedController] initiatePublicKeyDownloadFromHost:[serv host]];
     
        [(AppDelegate *)[[UIApplication sharedApplication] delegate] setSyslogHost:[serv host]];
	}
}


//MARK: - 


// If device is inverted (and if often will be, say to enter PIN codes on the back of
// the Verifone sled) if would be easy for inadvertent screen taps to issue unwanted
// actions on the remote VNC screen. So when inverted, we cover the screen with a
// guard view to "lock the screen" and prevent this.
//
- (void)toggleInvertedDeviceBlockScreenWithGravityZValue:(double)zValue
{
	// May need to experiment with the z axis; a 0.0 triggers when device is
	// perfectly vertical, but might want to allow a slight amount of "lean",
	// as long as screen is not pointed say more than 30 degrees toward the ground.
    
	[UIView beginAnimations:@"screenLock" context:nil];
	[UIView setAnimationDuration:0.3];
    
	const float zAxisInvertedAccelerationThreshold = 0.0;
	if (zValue > zAxisInvertedAccelerationThreshold) {
		[screenLockView setHidden:NO];
	}else{
		[screenLockView setHidden:YES];
	}
	[UIView commitAnimations];
}

- (void)addInvertedScreenLockView
{
	// CMMotionManager lets us know when to hide or unhide screenLockView. If device is inverted, we can block
	// the screen to prevent stray screen taps from being sent to the VNC screen.
#define USE_INVERTED_DEVICE_LOCK_SCREEN (0)
#if USE_INVERTED_DEVICE_LOCK_SCREEN

#define ScreenLockViewIsSubviewOfVNCView (1) // screenlock view is subview of VNC view, but VNC view can be smaller than screen size, and we want to cover entire screen
	
	// When device is inverted, want to prevent accidental screen taps from being sent to the VNC screen.
	// Because the Verifone sled has a PIN pad on the back, the device is likely to frequently be upside down.
	// Could use a UIView and do whatever with it, but for the moment, using a UIButton, because it
	// gives some automatic feedback when touched (note: we are not setting a target/action on it).
	// However, the rounded corners are a slight problem, so we make the button a little larger than
	// the screen, then center it, to get complete coverage.
	// Our CMMotion will toggle the button's -hidden property as the device inverts or not.
	// The accelerometer is currently turned on and off in viewWillAppear/Disappear
	screenLockView = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
#if ScreenLockViewIsSubviewOfVNCView
	[screenLockView setTransform:[self.vncView transform]]; // vncView has inverted coords relative to iOS standard
#endif
	
	[screenLockView setAlpha:0.75];
	//[[screenLockView layer] setBackgroundColor:[[UIColor grayColor] CGColor]];
	
	[screenLockView setTitle:@"Screen Locked\r(Device is Upside Down)" forState:UIControlStateNormal];
	
	screenLockView.titleLabel.numberOfLines = 2; 
	screenLockView.titleLabel.lineBreakMode = UILineBreakModeWordWrap;
	screenLockView.titleLabel.textAlignment = UITextAlignmentCenter;
	
	UIImage *image = [UIImage imageNamed:@"shoecarnival-logo.png"];
	const CGFloat kImageTopOffset   = 75;
	const CGFloat kTextBottomOffset = 75;
	
	[screenLockView setTitleEdgeInsets: UIEdgeInsetsMake( 0.0, -image.size.width, kTextBottomOffset,  0.0)]; 
	[screenLockView setImage:image forState:UIControlStateNormal];
    [screenLockView setImageEdgeInsets: UIEdgeInsetsMake( kImageTopOffset, 23.0, 0.0, -screenLockView.titleLabel.bounds.size.width)];
	
	[[screenLockView layer] setBackgroundColor:[[UIColor blueColor] CGColor]];
	[[screenLockView layer] setCornerRadius:0.0f];
	[[screenLockView layer] setMasksToBounds:YES];
	
	
	CGRect viewRect = self.view.frame;
	viewRect.size.width += 20.;
	viewRect.size.height += 20.;
	[screenLockView setFrame:viewRect];
	CGPoint center = self.view.center;
	center.y += 200.;
	//[screenLockView setCenter:center];
	
	// In Simulator for lockScreen debugging, and off in Simulator for normal work
	// Not a problem on device since CMMotionManager takes care of hiding it, but in Simulator it is always shown unless commented out.
#if ScreenLockViewIsSubviewOfVNCView
	[self.vncView addSubview:screenLockView];
#else
	[self.view addSubview:screenLockView];
#endif
	
	[screenLockView setHidden:YES];
	
    _motionManager = [[CMMotionManager alloc] init];
    _motionManager.deviceMotionUpdateInterval = 0.25;
    
    [_motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue]
                                        withHandler:^(CMDeviceMotion *motion, NSError *error) {
                                            if (!motion) {
                                                DLog(@"Can't get motion data, error:%@", error);
                                                return;
                                            }
                                            CMAcceleration gravity = motion.gravity;
                                            [self toggleInvertedDeviceBlockScreenWithGravityZValue:gravity.z];
     }];
    
#endif
}

- (void)setStandardHostDefaults
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
#if DEBUG // set my local test server info
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"SCVL", @"SCHostNameString",
                          @"10.0.1.1", @"SCHostAddrString",
                          [NSNumber numberWithInteger:5902], @"SCHostPort",
                          @"123456", @"SCHostPasswordString",
                          nil];
#else // SC will decide later what/whether these should be set
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"SCVL", @"SCHostNameString",
                          @"10.0.1.1", @"SCHostAddrString",
                          [NSNumber numberWithInteger:5902], @"SCHostPort",
                          @"", @"SCHostPasswordString",
                          nil];
#endif
    [d registerDefaults:dict];
}

//MARK: -

- (void)displayDefaultPinPadReadyMessage
{
   [[VStore sharedVStore] displayLCDMessage:@"READY"
                                      line2:@""
                                      line3:@""
                                      line4:@""
                                 forSeconds:-1];
}

//MARK: -

- (void)addObservers
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];

    // Register for notification of external accessories (such as the Verifone sled) connecting/disconnecting
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(accessoryDidConnect:)
												 name:EAAccessoryDidConnectNotification
											   object:nil];
	
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(accessoryDidDisconnect:)
												 name:EAAccessoryDidDisconnectNotification
											   object:nil];
	[[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
    
    // Register for custom notifications sent when certain messages arrive over TCP from SC/ACI server
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(pinDataRequested:)
												 name:SCServerRequestsPINDataNotification
											   object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(signatureDataRequested:)
												 name:SCServerRequestsSignatureDataNotification
											   object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(changeCardScannerStateRequested:)
												 name:SCServerRequestsChangeCardScannerStateNotification
											   object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(resetEncryptionMode:)
												 name:SCServerRequestsEncryptionModeReset
											   object:nil];
    
    
    // Register for UIKeyboard notifications. We'll use these move the VNC view up when the keyboard
    // comes onscreen, attempting to do for VNC text boxes what iOS does for UITextFields.
    // Since the VNC text fields are just bits in a screen image, we don't know their location,
    // but Dean says moving up about an inch should prevent any field from being obscured by the
    // keyboad, while also not scrolling any field's image off top of the screen.
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillShow:)
												 name:UIKeyboardWillShowNotification
											   object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillHide:)
												 name:UIKeyboardWillHideNotification
											   object:nil];


    
}

//MARK: - SCServerRequestsPINDataNotification

- (void)pinDataRequested:(NSNotification *)note
{
    NSDictionary *userInfo = [note userInfo];
    NSString *requestedAccountNumber = [userInfo objectForKey:ServerRequestedAccountNumberStrKey];
    
    //
    // Account # sanity checking
    //
    if (isEmptyString(requestedAccountNumber)) {
        DLog(@"%@", @"PIN was requested for empty account number, canceled\n");
        SPLog(@"PIN was requested for empty account number, canceled");
        return;
    }
    
    const int kMinAllowableAccountNumberLength = 8;
    const int kMaxAllowableAccountNumberLength = 19;
    if ([requestedAccountNumber length] < kMinAllowableAccountNumberLength ||
        [requestedAccountNumber length] > kMaxAllowableAccountNumberLength) {
        DLog(@"PIN was requested for account number with out of range length:%lu, canceled\n", (unsigned long)[requestedAccountNumber length]);
        SPLog(@"PIN was requested for account number with out of range length:%d, canceled\n", [requestedAccountNumber length]);
        return;
    }
    
    //
    // get PIN data from VX600
    //
    DLog(@"CUSTOMER PIN IS REQUESTED for accountNumber:%@\n\n", requestedAccountNumber);
    SPLog(@"CUSTOMER PIN IS REQUESTED");
    
    
    // Actually at this point we know empiricaly that we're on the main thread,
    // but Verifone stuff needs to always be on the main thread, so to be independent of
    // any possible upstream changes, we ensure that here.
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // -getPinFromUserForAccount will turn these back off
        [[[VStore sharedVStore] payControl] keypadEnabled:YES];
        [[[VStore sharedVStore] payControl] keypadBeepEnabled:YES];

        const int delay = 0.25; // Tom Salzmann @ Verifone says it may be advisable to have a short
                                // delay between keypadEnabled and actually getting PIN data,
                                // although he also says 0.0 seems to work. To be on the safe side, we
                                // user small delay here.
        [self performSelector:@selector(getPinFromUserForAccount:)
                   withObject:requestedAccountNumber
                   afterDelay:delay];
    });
}

- (void)getPinFromUserForAccount:(NSString *)requestedAccountNumber
{
    DLog(@"getPinFromUserForAccount:%@", requestedAccountNumber);
    SPLog(@"get Pin From User For Account:%@", requestedAccountNumber);

    if (![[[VStore sharedVStore] pinPad] connected]) {
        DLog(@"%@", @"pin pad reports it is not connected, cannot get PIN, pin request cancelled/n");
        SPLog(@"pin pad reports it is not connected, cannot get PIN, pin request cancelled");
        return;
    }
    if (![[[VStore sharedVStore] payControl] connected]) {
        DLog(@"%@", @"Pin pad connected, Pay Control NOT connected, cannot get PIN, pin request cancelled\n");
        SPLog(@"Pin pad connected, Pay Control NOT connected, cannot get PIN, pin request cancelled");
        return;
    }
    
    [[SCServerProtocolController sharedController] sendTestString:@"This is a test PIN request response; actual data will follow on port 600 if possible"];
    
    /* Original Verifone comment follows
     
     20110116 - Randy says:
     
     Also, Z50 returns a string response that can be retrieved by calling-
     -(NSString *) copyStringResponse
     
     Z60 populates vfiEncryptedData.serialNumber and vfiEncryptedData.pinBlock
     
     <STX>Z62.4000000000006<FS>0412YMESSAGE 1<FS>
     MESSAGE 2<FS>PROCESSING MSG<ETX><LRC>
     */

    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Flip Over & Hand to Customer ";
    hud.detailsLabelFont = hud.labelFont;
    hud.detailsLabelText = @"For PIN Entry";
    hud.exclusiveTouch = YES; // lock em out

    const int MinPINLength = 4;
    const int MaxPINLength = 8;
    
    DLog(@"About to put PIN Request on LCD with timeout:%d seconds", 70); // 70 is from setPINTimeout
    SPLog(@"About to put PIN Request on LCD with timeout:%d seconds", 70);
    
	int resultCode =
	[[[VStore sharedVStore] pinPad] Z62:requestedAccountNumber
                                 minPIN:MinPINLength
                                 maxPIN:MaxPINLength
                             requirePIN:NO
                           firstMessage:@"ENTER PIN"
                          secondMessage:@""
                      processingMessage:@"Processing..."];
    
        // Monk: actually at this point the PIN request message is already over
        // DLog(@"%@", @"VX600 PIN REQUEST SHOULD BE ON LCD");
        // SPLog(@"VX600 PIN REQUEST SHOULD BE ON LCD");

    [[[VStore sharedVStore] payControl] keypadEnabled:NO];
    
    // Hide "flip over" iOS alert
    [MBProgressHUD hideHUDForView:self.view animated:YES];

    //int pinblockLength = [[[VStore sharedVStore] pinPad].vfiEncryptionData.pinBlock length]; - implicit conversion loses integer precision
    unsigned long pinblockLength = [[[VStore sharedVStore] pinPad].vfiEncryptionData.pinBlock length];
    
    if (resultCode != 0 || !pinblockLength) {
        // Known result codes:
        // 2 == account number out of range (must be between 8 and 19 digits long per Verifine
        // 3 == Cancel key was tapped on pin pad
        // 98 == pin pad session timed out before Enter was tapped; timeout controlled by -setPINTimeout

		DLog(@"PIN request fails with resultCode:%d, pinblockLength:%lu\n", resultCode, pinblockLength);
		SPLog(@"PIN request fails with resultCode:%d, pin block Length:%d", resultCode, pinblockLength);
        
        [[[VStore sharedVStore] pinPad] cancelCommand];
        
		// Monk: following commented-out lines are from verifone sample; don't know their purpose or why commented out...
		//[[[VStore sharedVStore] pinPad] noResponseNextCommand];
		//[[[VStore sharedVStore] pinPad] sendStringCommand:@"S00" calcLRC:YES];

        [[VStore sharedVStore] displayLCDMessage:@"PIN"
                                           line2:@"Entry"
                                           line3:@"Cancelled..."
                                           line4:[NSString stringWithFormat:@"code:%d", resultCode]
                                      forSeconds:3.0];

        // send empty data back to server since PIN failed/cancelled?
        [[SCServerProtocolController sharedController] sendPINData:@""];
		
    } else { // succeeded
        
        [[VStore sharedVStore] displayLCDMessage:@""
                                           line2:@"PIN"
                                           line3:@"Entered"
                                           line4:@"OK"
                                      forSeconds:2.0];
        DLog(@"PIN entered OK, pinblock length is:%lu, sending to server", pinblockLength);
        SPLog(@"PIN entered OK, pinblock length is:%d, sending to server", pinblockLength);

        NSData *pinBlockData = [[VStore sharedVStore] pinPad].vfiEncryptionData.pinBlock;
        NSString *pinblock = [[[NSString alloc] initWithData:pinBlockData encoding:NSASCIIStringEncoding] autorelease];
        
        NSString *DUKPT_KSNStr  = [[[[VStore sharedVStore] pinPad] vfiEncryptionData] serialNumber];

        pinblock = [pinblock stringByAppendingString:DUKPT_KSNStr];
        [[SCServerProtocolController sharedController] sendPINData:pinblock];
    }
	
		
    // Monk: verifone comment below; commented out by verifone.
    // Presumably not needed with recent VX600 firmware...
	// bug in display message requires a wait!!!!!!! hopefully fixed soon.
	// [NSThread sleepForTimeInterval:1.5];
    
    [self displayDefaultPinPadReadyMessage];
	
    DLog(@"%@", @"exiting PIN entry");
	SPLog(@"exiting PIN entry");
}	

//MARK: - SCServerRequestsSignatureDataNotification
- (void)signatureDataRequested:(NSNotification *)note
{
    // show signature panel, get data, then
    ScrawlViewController *svc = [ScrawlViewController createWithScrawlColor:[UIColor blackColor]
                                                       backgroundColorColor:[UIColor whiteColor]
                                                           hasDismissButton:YES
                                                    hasClearSignatureButton:YES
                                                             loadsSavedData:NO];
    [svc setDelegate:self];
    [self setSignatureViewController:svc];
    
#if 0
    [self.parentViewController addChildViewController:svc];
    //[self.parentViewController addChildViewController:self];

    [self.parentViewController transitionFromViewController:self
                      toViewController:svc
                              duration:1.0
                               options:UIViewAnimationOptionLayoutSubviews
                            animations:nil
                            completion:nil];
#else
    //[self presentModalViewController:svc animated:YES]; - deprecated in iOS 6.0
    [self presentViewController:svc animated:YES completion:nil];
#endif
}

//MARK: - SCServerRequestsChangeCardScannerStateNotification
#define kSCServerControlsCardScannerEnableState (1)

- (void)changeCardScannerStateRequested:(NSNotification *)note
{
    NSDictionary *userInfo = [note userInfo];
    NSNumber *newState = [userInfo objectForKey:ServerRequestedNewCardScanneStateKey];
    BOOL newStateFlag = [newState boolValue];
    
    [[VStore sharedVStore] enableCardScanner:newStateFlag];
    
    // Turning off card scanner appears to cause VX to discard its encryption key.
    // So when turning scanner back on, also re-set the key.
//    if (newStateFlag == YES) {
//    }
}

//MARK: - ScrawlViewControllerDelegate
- (void)scrawlViewControllerWillDismiss:(ScrawlViewController *)svc
{
    NSMutableArray *signaturePoints = [[svc scrawlDrawView] completeScrawls];
    
    dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
            
            DLog(@"%@", @"SIG request response points, actual data will follow on port 600 if possible");
            
            // send real data
            [[SCServerProtocolController sharedController] sendSignatureData:signaturePoints];
		}
	});
    
    [self setSignatureViewController:nil];
}

- (void)scrawlViewControllerDidCancel:(ScrawlViewController *)svc;
{
    dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
            
            DLog(@"%@", @"SIG request canceled, empty data will follow");
            
            // send real data
            [[SCServerProtocolController sharedController] sendCancelledSignatureData];
		}
	});
    
    [self setSignatureViewController:nil];
}

//MARK: -

- (void)removeObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[[EAAccessoryManager sharedAccessoryManager] unregisterForLocalNotifications];  
}

- (void)viewDidLoad 
{
    [super viewDidLoad];

	serv = [[ServerBase alloc] init];
	
#if 1 // Local SC server
	[self setStandardHostDefaults];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	
    NSString *hostNameString = [d objectForKey:@"SCHostNameString"];
    [serv setName:hostNameString];
    
    NSString *hostAddrString = [d objectForKey:@"SCHostAddrString"];
    [serv setHost:hostAddrString];
	
    NSInteger port = [d integerForKey:@"SCHostPort"];
    [serv setPort:port];
	
    NSString *hostPasswordString = [d objectForKey:@"SCHostPasswordString"];
    [serv setPassword:hostPasswordString];
	
#elif 1 // local OS X Machine
	[serv setName:@"Atoms"];
    [serv setHost:@"10.0.1.23"];
    [serv setPassword:@"password"];
    [serv setPort:5900];
	
#else // remote test SC server over internet
    [serv setName:@"SC Test"];
	
#define usingBNRPortForwarding 0
#if usingBNRPortForwarding
    [serv setHost:@"localhost"];    // when port forwarding thru BNR's "silver" server with ssh -p9822 -L5902:70.43.60.2:5902 monk@24.98.228.116
#else
	[serv setHost:@"70.43.60.2"];	// ACR test server on internet
#endif
	
    [serv setPassword:@"acrsys"];
    [serv setPort:5902];
#endif

	// When get a working SC server to connect to, will
	// add config panel and only connect then.
	// For now we are hacking in whatever we can get as a server,
	// whether Mac (note - this app not intended to work with VNC screens larger than the device screen).
	// Remote non-working server (but it does have a screen) provided by ACR - however requires a whitelist request each time your local IP changes
	// Port forwarding thru BNR silver to ACR server - works (if whitelisted) but not a functional server, VNC screen test only
	// Local SC server hardware at fixed IP on closed SC network hardware - arrived but not functioning
	
	
	// 
	// Begin new Shoe Carnival code
	//
	// NOTE: self.vncView has an inverse transform! (see VNCContentView -init)
	
	// Add a tap gesture recognizer the vncView to convert screen taps to "mouse clicks" and 
	// forward them to the VNC server.
	UITapGestureRecognizer *tapRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)] autorelease];
	[self.vncView addGestureRecognizer:tapRecognizer];
	
	// Add a swipe gesture recognizer to to parent view reveal the server setup panel.
    // May have to experiment with direction / numberOfTouchesRequired and see how/if there is any
    // interference with the Shoe Carnival VNC UI.
	
    // Right swipe reveals server setup panel
    UISwipeGestureRecognizer *swipeRecognizer = [[[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)] autorelease];
	[swipeRecognizer setNumberOfTouchesRequired:1];
    UISwipeGestureRecognizerDirection swipeDirection = UISwipeGestureRecognizerDirectionRight;
#if DEBUG
    // Left swipe reveals signature panel, for testing without going thru an entire purchase transaction
    swipeDirection |= UISwipeGestureRecognizerDirectionLeft;
#endif
	[swipeRecognizer setDirection:(swipeDirection)];
	[self.view addGestureRecognizer:swipeRecognizer];

    
    // Left two-touch swipe reveals Verifone test view (will remove, or else must reconfigure not to interfere with our normal Verifone connection)
//    swipeRecognizer = [[[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSecondSwipeGesture:)] autorelease];
//	[swipeRecognizer setNumberOfTouchesRequired:2];
//	[swipeRecognizer setDirection:UISwipeGestureRecognizerDirectionLeft];
//	[self.view addGestureRecognizer:swipeRecognizer];

    
    // Up swipe reveals server setup panel also
	swipeRecognizer = [[[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)] autorelease];
	[swipeRecognizer setNumberOfTouchesRequired:1];
	[swipeRecognizer setDirection:UISwipeGestureRecognizerDirectionUp];
	[self.view addGestureRecognizer:swipeRecognizer];

    //
    // Add temp buttons in swipe-able overlay view
    //
    // These have become sort of permanent; might want to move all this
    // to a nib file to ease changes.
    //
    CGRect viewRect = self.view.frame;
	viewRect.origin.y = viewRect.origin.y + 436.0;
    viewRect.size.height = 44.0;
    
    self.buttonOverlayView = [[[UIView alloc] initWithFrame:viewRect] autorelease];
    [self.buttonOverlayView setBackgroundColor:[UIColor blackColor]];
    [self.buttonOverlayView setAlpha:0.85];
    
	viewRect = self.buttonOverlayView.frame;
    viewRect.origin.x = 3.0;
	viewRect.origin.y = 4.0;

	CGRect previousButtonRect = CGRectZero;
	float interButtonSpacing = 5.0;
    
#define USE_CONFIG_BTN (0) // Server config can also be performed via a right-swipe
#if USE_CONFIG_BTN
    int numButonsAcross = 6;
    const float extraButtonWidth = 0.0;
#else
    int numButonsAcross = 5;
    const float extraButtonWidth = 56/numButonsAcross;
#endif
    
	// "Show Kbd" button
	UIButton *showKbdButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[showKbdButton setTitle:@"Kbd" forState:UIControlStateNormal];
	[showKbdButton addTarget:self action:@selector(showKbdButtonTapped)	forControlEvents:UIControlEventTouchUpInside];
	
	showKbdButton.frame = viewRect;
	[showKbdButton sizeToFit];
    
    // add extra width if Cfg button is not used
    CGRect frame = [showKbdButton frame];
    frame.size.width += extraButtonWidth;
    [showKbdButton setFrame:frame];

	[self.buttonOverlayView addSubview:showKbdButton];
	
	previousButtonRect = showKbdButton.frame;
    
    // Config button
#if USE_CONFIG_BTN
	UIButton *showConfigButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[showConfigButton setTitle:@"Cfg" forState:UIControlStateNormal];
	[showConfigButton addTarget:self action:@selector(showConfigButtonTapped)	forControlEvents:UIControlEventTouchUpInside];
	
	viewRect = previousButtonRect;
	viewRect.origin.x += viewRect.size.width + interButtonSpacing;
	showConfigButton.frame = viewRect;
	[showConfigButton sizeToFit];
	[self.buttonOverlayView addSubview:showConfigButton];

	previousButtonRect = showConfigButton.frame;
#endif
 
	// "Esc" button; needed by SC VNC UI
	UIButton *escButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[escButton setTitle:@"Esc" forState:UIControlStateNormal];
	[escButton addTarget:self action:@selector(EscButtonTapped)	forControlEvents:UIControlEventTouchUpInside];
	
	viewRect = previousButtonRect;
	viewRect.origin.x += viewRect.size.width + interButtonSpacing;
	escButton.frame = viewRect;
	[escButton sizeToFit];
    
    // add extra width if Cfg button is not used
    frame = [escButton frame];
    frame.size.width += extraButtonWidth;
    [escButton setFrame:frame];
    
	[self.buttonOverlayView addSubview:escButton];
	
	previousButtonRect = escButton.frame;
	
	// "F3" button; needed by SC VNC UI
	UIButton *F3Button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[F3Button setTitle:@"F3" forState:UIControlStateNormal];
	[F3Button addTarget:self action:@selector(F3ButtonTapped)	forControlEvents:UIControlEventTouchUpInside];
	
	viewRect = previousButtonRect;
	viewRect.origin.x += viewRect.size.width + interButtonSpacing;
	F3Button.frame = viewRect;
	[F3Button sizeToFit];
    
    // add extra width if Cfg button is not used
    frame = [F3Button frame];
    frame.size.width += extraButtonWidth;
    [F3Button setFrame:frame];

	[self.buttonOverlayView addSubview:F3Button];



	previousButtonRect = F3Button.frame;
	
	// "Return" button; needed by SC VNC UI
	UIButton *returnButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[returnButton setTitle:@"Ret" forState:UIControlStateNormal];
	[returnButton addTarget:self action:@selector(returnButtonTapped)	forControlEvents:UIControlEventTouchUpInside];
	
	viewRect = previousButtonRect;
	viewRect.origin.x += viewRect.size.width + interButtonSpacing;
	returnButton.frame = viewRect;
	[returnButton sizeToFit];
    
    // add extra width if Cfg button is not used
    frame = [returnButton frame];
    frame.size.width += extraButtonWidth;
    [returnButton setFrame:frame];

	[self.buttonOverlayView addSubview:returnButton];
   
	previousButtonRect = returnButton.frame;

#define UseDeleteButton (1) // Don't totally need, we are now faking an ascii DEL char in textView:shouldChangeTextInRange, but a button is more convenient than bring up the keyboard just to hit a Del
#if UseDeleteButton
	// "Backspace/Delete" button; needed by SC VNC UI
	UIButton *deleteButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[deleteButton setTitle:@"Del" forState:UIControlStateNormal];
	[deleteButton addTarget:self action:@selector(deleteButtonTapped)	forControlEvents:UIControlEventTouchUpInside];
	
	viewRect = previousButtonRect;
	viewRect.origin.x += viewRect.size.width + interButtonSpacing;
	//viewRect.origin.y -= viewRect.size.height + interButtonSpacing; // above Return btn for now
	deleteButton.frame = viewRect;
	[deleteButton sizeToFit];
    
    // add extra width if Cfg button is not used
    frame = [deleteButton frame];
    frame.size.width += extraButtonWidth;
    [deleteButton setFrame:frame];

	CGRect r = deleteButton.frame;
	r.size.width -= 4.0;
	deleteButton.frame = r;
	[self.buttonOverlayView addSubview:deleteButton];
    
#endif
	
    // Add Page Up & Page Down keys on a second row per Dean Grimes 8/27
    // Will need to make the "slide in" view taller, with two rows of buttons.
#define kInterButtonRowSpacing (10) // bit of space between the two rows of buttons
    r = self.buttonOverlayView.frame;
    r.size.height *= 2;
    r.size.height += kInterButtonRowSpacing; 
    r.origin.y -= r.size.height/2;
    self.buttonOverlayView.frame = r;
    
    r = showKbdButton.frame;
    r.origin.y += r.size.height + kInterButtonRowSpacing;
    UIButton *pageDownButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[pageDownButton setTitle:@"⬇" forState:UIControlStateNormal];
	[pageDownButton addTarget:self action:@selector(pageDownButtonTapped) forControlEvents:UIControlEventTouchUpInside];
	pageDownButton.frame = r;
	[self.buttonOverlayView addSubview:pageDownButton];
    
    r = deleteButton.frame;
    r.origin.y = pageDownButton.frame.origin.y;
    UIButton *pageUpButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[pageUpButton setTitle:@"⬆" forState:UIControlStateNormal];
	[pageUpButton addTarget:self action:@selector(pageUpButtonTapped) forControlEvents:UIControlEventTouchUpInside];
	pageUpButton.frame = r;
	[self.buttonOverlayView addSubview:pageUpButton];
    
	[self.view addSubview:self.buttonOverlayView];
    // hide overlay (a swipe will show it)
    [self hideButtonOverlayView];



//    UIButton *pkButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
//    [pkButton setTitle:@"^B" forState:UIControlStateNormal];
//    [pkButton addTarget:self action:@selector(controlB:) forControlEvents:UIControlEventTouchUpInside];
//    pkButton.frame = CGRectMake(F3Button.frame.origin.x,
//                                pageUpButton.frame.origin.y,
//                                F3Button.frame.size.width,
//                                pageUpButton.frame.size.height);
//    [self.buttonOverlayView addSubview:pkButton];


    //
	// Offscreen textfield to allow bringing up UIKeyboard. We won't actually allow any
    // characters into the field. User typing will be redirected to VNC.
    //
	keyboardtextField = [[UITextView alloc] init];
	[keyboardtextField setDelegate:self];
	viewRect = self.view.frame;
	viewRect.size.width = 20.;
	viewRect.origin.x -= 100.; // offscreen
	
	[keyboardtextField setFrame:viewRect];
	[self.view addSubview:keyboardtextField];
	
	//[keyboardtextField setKeyboardType:UIKeyboardTypeASCIICapable];
	//[keyboardtextField setKeyboardType:UIKeyboardTypeNumberPad];
	[keyboardtextField setKeyboardType:UIKeyboardTypeNumbersAndPunctuation];
	[keyboardtextField setAutocorrectionType:UITextAutocorrectionTypeNo];
	[keyboardtextField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
	
#define ReturnKeyActsAsDoneButton (1) // toggle to 0 to let Return act as a Return key rather than "Done/Dismiss Kbd" button
#if ReturnKeyActsAsDoneButton			// If used as a Done btn, we will resignFirstResponder when the button is hit (happens in textView:shouldChangeTextInRange below)
	[keyboardtextField setReturnKeyType:UIReturnKeyDone];
#endif
    
    
	// Add hidden view to lock the screen when device is inverted
	[self addInvertedScreenLockView];
	
    //MARK: - 
    
    [self addObservers];
    
    NSTimeInterval externalAccessoryConnectDelay= 0.0;
    if (LOG_TO_WIFI) {
        // wait for Bonjour session to connect for WiFi logging
        externalAccessoryConnectDelay = 5.0;
    }
        

    // attempt to connect to Verifone hardware, if succeeds, 
    // that will init the  singleton instance of Verifone manager.
    // If fails, then if/when accessory is connected we will receive a notification
    // in accessoryDidConnect and can do this again there.
    [self performSelector:@selector(connectWithExternalAccessory) withObject:nil afterDelay:externalAccessoryConnectDelay];
    
    [self performSelector:@selector(configServer) withObject:nil afterDelay:0.5];
	
}
		 
- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{	
    [super viewDidAppear:animated];
    
    //if ([[VStore sharedVStore] barcode].initialized)
	//	[[VStore sharedVStore] barcodeScanOff]; 
	
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];

}

- (void)viewDidUnload {
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;

    [self removeObservers];
    
	[screenLockView removeFromSuperview];
	[screenLockView release]; screenLockView = nil;
	
	[keyboardtextField removeFromSuperview];
	[keyboardtextField release]; keyboardtextField = nil;
	
	[[self vncView] removeAllGestureRecognizers];
	
	[self setVncView:nil];
}

//MARK: - UIApplicationDidBecomeActiveNotification

- (void)applicationDidBecomeActive:(NSNotification *)note
{
    static BOOL oneShot = NO;
    if (![vncConnection frameBuffer]) {
        if (!oneShot) {
            oneShot = YES;
        } else {
            [self performSelector:@selector(configServer) withObject:nil afterDelay:0.0];
        }
	}
}

//MARK: Show Kbd Button
- (void)showKbdButtonTapped {
	// Show Standard Keyboard
	[keyboardtextField becomeFirstResponder];
    
    [self hideButtonOverlayView];
}

//MARK: Show Cfg Button
- (void)showConfigButtonTapped {
    [self configServer];
    
    [self hideButtonOverlayView];
}
        
//MARK: Esc Button
- (void)EscButtonTapped {
	// Send ASCII ESC character
	[vncConnection sendEscapeKey];
    
    [self hideButtonOverlayView];
}

//MARK: F3 Button
- (void)F3ButtonTapped {
	//SPLog(@"F 3 key");

	// Send F3 key
	[vncConnection sendFunctionKey:3];
    
    [self hideButtonOverlayView];
}

//MARK: Return Button
- (void)returnButtonTapped {
	// Send Return key	
	//SPLog(@"Return key");
	    
	[vncConnection sendKey:0x0D pressed:YES];
	[vncConnection sendKey:0x0D pressed:NO];
    
    [self hideButtonOverlayView];
}

- (void) controlB:(id)sender {
	[vncConnection sendKey:SENTINEL pressed:YES];
	[vncConnection sendKey:SENTINEL pressed:NO];
}

//MARK: Delete Button
- (void)deleteButtonTapped {
	// Send Delete key
	[vncConnection sendKey:0x7F pressed:YES];
	[vncConnection sendKey:0x7F pressed:NO];
    
    [self hideButtonOverlayView];
}

//MARK: PageUp button
- (void)pageUpButtonTapped {

	[vncConnection sendKey:0xff55 pressed:YES]; // see RFB manual page pg 23
	[vncConnection sendKey:0xff55 pressed:NO];
    
    [self hideButtonOverlayView];
}

//MARK: PageDown button
- (void)pageDownButtonTapped {
    
	[vncConnection sendKey:0xff56 pressed:YES]; // see RFB manual page pg 23
	[vncConnection sendKey:0xff56 pressed:NO];
    
    [self hideButtonOverlayView];
}

//MARK: UIScrollViewDelegate

// Note: Scrolling will not actually occur in the Shoe Carnival VNC client: the 
// remote screen is assumed to match the device screen size (or smaller); scrolling and scaling
// larger VNC screens is not supported (and wouldn't make sense anyway)
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return [self vncView];
}

//MARK: UIViewControllerRotation

// Rotation is not supported; since Shoe Carnival app runs on a device inserted
// into Verifone sled which assume Portrait orientation
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orient 
{
    return (orient == UIInterfaceOrientationPortrait);
//    if (orient == UIDeviceOrientationPortraitUpsideDown) {
//        return NO;
//    }
//    
//    if (self.signatureViewController) {
//        return YES;
//    }
//    //return YES;
//    return UIDeviceOrientationIsPortrait(orient);
}

// But if rotation *were* supported, it'd need this...
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)old
{
    //[self fixScale];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if (self.signatureViewController) {
        [self.signatureViewController willAnimateRotationToInterfaceOrientation:toInterfaceOrientation
                                                                       duration:duration];
    }
}


//MARK: -

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    [_motionManager release];
    _motionManager = nil;
    
    [self removeObservers];

	[vncView release];
    
    vncConnection.delegate = nil;
	[vncConnection release];
	
	[screenLockView release];
	[keyboardtextField release];
    
    self.signatureViewController.delegate = nil;
    self.signatureViewController = nil;

		
    [super dealloc];
}

//MARK: - UITextViewDelegate
- (BOOL)textViewShouldBeginEditing:(UITextView *)textView {
	return YES;
}

- (void)textViewDidBeginEditing:(UITextView *)textView;
{
	//DLog(@"%@", @"editing began");
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
	DLog(@"text range to replace:%@", NSStringFromRange(range));
	
	char buffer[2] = {0,0};
	
	if ([text getCString:buffer maxLength:2 encoding:NSUTF8StringEncoding]) {
		
#if ReturnKeyActsAsDoneButton 
		if (buffer[0] == '\n') {
			// 'Done' button pressed on keyboard
			[keyboardtextField resignFirstResponder];
			return NO;
		}
#endif
		// range.length == 0 for typed characters
		if (buffer[0]) {
			[vncConnection sendKey:buffer[0] pressed:YES];
			[vncConnection sendKey:buffer[0] pressed:NO];
		}  else if (buffer[0] == 0 && isEmptyString(text)) {
			// range.length == 1 when iOS Delete key is tapped, however no Delete character is sent (it replaces a range of length 1 with nothing)
			[self deleteButtonTapped];
		}
	}
	return NO; // we don't actually want/need any characters in the field; it's just there so we can get a keyboard on screen and redirect the user's typing to VNC
}

//MARK: - UIKeyboardWillShowNotification
- (void)keyboardWillShow:(NSNotification *)note
{
    
    // Might need keyboard rect, but for starters, Dean saving moving VNC view up
    // "anout an inch" should be enough to prevent any VNC text box being obscured by
    // the keyboard.
    //NSDictionary *userInfo = [note userInfo];
    //CGRect finalKeyboardRect = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    CGRect vncViewFrame = [vncView frame];
    vncViewFrame.origin.y -= 110.0; // might tweak; have no server at the moment, so can't see effect
    
    [UIView beginAnimations:@"keyboardWillShow" context:nil];
    [vncView setFrame:vncViewFrame];
    [UIView commitAnimations];
}

//MARK: - UIKeyboardWillHideNotification
- (void)keyboardWillHide:(NSNotification *)note
{
    // Re-center VNC view, which was moved up when keyboard appeared,to avoid obscuring
    // VNC text boxes.
    CGRect vncViewFrame = [vncView frame];
    vncViewFrame.origin = CGPointZero;
    
    [UIView beginAnimations:@"keyboardWillHide" context:nil];
    [vncView setFrame:vncViewFrame];
    [UIView commitAnimations];
}

//MARK: -

- (void)displayNoVerifoneDeviceAlert
{
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    if (self.isViewLoaded && self.view.window) {
        
        // If VX not connected, EAAccessoryManager will not have found the Verifone protocols.
        // Suggest to user some ways to solve the issue, which can be different
        // for different VX variants.
        // VX600 for iPad communicates with us via EAAccessory Made-For-iOS bluetooth
        // VX600 for iPod uses EAAccessory MFI 30-pin.
        NSString *platformSpecificMessage = @"VX connected?";
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            platformSpecificMessage = @"Bluetooth turned on in iPad Settings?";
        }
        NSString *message = [NSString stringWithFormat:@"VX600 EAAccessory protocol not found.\r\r %@\r\rVX powered up?\r\rVX paired with iOS device (if using Bluetooth)?", platformSpecificMessage];
        
        [UIAlertView displayAlertOnNextRunLoopInvocationWithTitle:@"No Verifone Device"
                                                          message:message
                                                         delegate:nil
                                                cancelButtonTitle:@"OK"
                                                 otherButtonTitle:nil];
    }
}

//MARK: -

- (void)setDefaultBarcodeOptions
{
    [[VStore sharedVStore] barcodeScanOn];
    
    // Enable 2D code types (DataMatrix, Maxicode, QR Code, GS1 Composite, Aztec, GS1 Composite, Maxicode, QR Code)
    // Note 1D scanning looks like a horizontal red line emitted from scanner.
    // 2D scanning looking like flashing horizontal red line surrounded by red light (like a flashlight), scans a bit faster
    [[[VStore sharedVStore] barcode] setScanner2D]; // per Dean, definitely want 2D
    
    [[[VStore sharedVStore] barcode] setScanTimeout:5000];  // 5sec
    
    // Ensure scanner laser turns off after a successful scan on all Veridfone devices.
    // On VX600, scanner defaults to turning off the laser after a successful scan, as
    // documented in the current Verifone headers and docs.
    // However the newer Verifone e3xx devices default to continuous scanning - i.e.
    // the laser doesn't turn off after a scan.
    // The Verifone docs and header comments
    // have not yet been updated, as confirmed by Verifone mailto:MobileSDKSupport@verifone.com
    // But they state calling -setSingleScan on VX600 does nothing, on
    // e3xx devices it'll provide Shoe Carnial's desired behavior as per Dean Grimes.
    [[[VStore sharedVStore] barcode] setSingleScan];
    
    BOOL vmfGen3Flag = [[VStore sharedVStore] barcode].isGen3;
    if(vmfGen3Flag==true)[[[VStore sharedVStore] barcode] setBeepOn];
    
    //[[[VStore sharedVStore] barcode] includeAllBarcodeTypes]; // don't want/need all types for SC
    
    // soft mode        [[[VStore sharedVStore] barcode] setLevel];
    // Return the type in the barcode delegate
    
    [[[VStore sharedVStore] barcode] barcodeTypeEnabled:YES];
    
    // Shoe Carnival server does not want the barcode checksum digit returned to it.
    // This suppresses the barcode scanner from returning it to us in -barcodeScanData:
    
    DLog(@"%@", @"Attempting to turn off barcode check digit");
    //SPLog(@"Attempting to turn off barcode check digit");
    [[VStore sharedVStore] enableBarcodeCheckDigit:NO];

    DLog(@"%@", @"Setting barcode to transmit UPC E as UPC A");
    //SPLog(@"Setting barcode to transmit UPC E as UPC A");
    [[VStore sharedVStore] enableBarcodeTransmitsUPCE_as_UPCA:YES];
}

- (void)initVerifoneDevice
{
    //SPLog(@"entered init Verifone Device");
    DLog(@"%@", @"entered initVerifoneDevice");
    
    verifoneDeviceInitStarted = YES; 
        
    BOOL verifoneProtocolExists = [VStore verifoneEAAccessoryProtocolExists];
    
    if (!verifoneProtocolExists) {
        SPLog(@"no Verifone EA protocol found, exiting initVerifoneDevice");
        DLog(@"%@", @"no Verifone EA protocol found, exiting initVerifoneDevice");
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        [self displayNoVerifoneDeviceAlert];
        return;
    }
    
    (void)[VStore sharedVStore]; // create and init shared instance;
    
    // listen for VFMMessage notifications from the Verifone framework (note: not currently used)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(VFMMessageReceived:) name:@"VFMMessage" object:nil];
	
    DLog(@"%@", @"init pinPad");
    if(hudView) hudView.detailsLabelText = @"Initializing PIN pad...";
    
	//    [[[VStore sharedVStore] pinPad] setFrameworkTimeout:5]; // ios5 bug workaround. // <-- original Verifone coment with no explanation
    
    [[[VStore sharedVStore] pinPad] setDelegate:self];
    [[[VStore sharedVStore] pinPad] initDevice];    
    
    if ([[VStore sharedVStore] pinPad].vfiDiagnostics.osversion == nil) {
        SPLog(@"Init Pinpad Failed. Restart App.");
        DLog(@"%@", @"Init Pinpad Failed. Restart App.");
        
        [[[VStore sharedVStore] pinPad] closeDevice]; 
        [[[VStore sharedVStore] showAlertWithMessage:@"Verifone Init Failed\nRestart App..."] show];
        
        // Monk: this sort of thing is not really acceptable in a production app, but that's 
        // what Verifone does here...need to clean

        [NSThread sleepForTimeInterval:3.405]; 
		
        exit(0); //
        
    } else {
        DLog(@"%@", @"init pinPad succeeded, setting pinpad timeouts"); 

        if(hudView) hudView.detailsLabelText = @"Setting PIN pad timeouts...";

        [[[VStore sharedVStore] pinPad] setFrameworkTimeout:120]; // ENTER PIN timeout old way.
        [[[VStore sharedVStore] pinPad] setPINTimeout:70]; // ENTER PIN timeout 
        [[[VStore sharedVStore] pinPad] setAccountEntryTimeout:120]; 
        [[[VStore sharedVStore] pinPad] setPromptTimeout:70]; 
        [[[VStore sharedVStore] pinPad] setACKTimeout:3.0];  
		
        [[[VStore sharedVStore] pinPad] setKSN20Char:YES]; 
		
        
#if 0   // make VMFFramework emit log statements
        // they will be saved to ~/Documents if RedirectConsoleToFile is true
        [[[VStore sharedVStore] pinPad] logEnabled:YES];
        [[[VStore sharedVStore] pinPad] consoleEnabled:YES]; // log to Xcode(?) - docs not clear (to me anyway)
        
#endif
        
        DLog(@"%@", @"init payControl"); 
        if(hudView) hudView.detailsLabelText = @"Initializing pay control...";

        [[[VStore sharedVStore] payControl] setDelegate:self]; 
        [[[VStore sharedVStore] payControl] initDevice]; 
        [[[VStore sharedVStore] payControl] keypadBeepEnabled:YES] ;  
        [[[VStore sharedVStore] payControl] keypadEnabled:NO]; 
  
        
#if (1) || !defined(DEBUG)
        // Allow VX600 to draw USB power from the iOS device, but
        // if turned on, cannot use Xcode debugger via VX's mini-USB and the double-boot procedure.
        [[[VStore sharedVStore] payControl] hostPowerEnabled:YES]; 
#endif
        
        // Verifone sample code says: "try doing all this init here to save time later."
        DLog(@"%@", @"init barcode");
        if(hudView) hudView.detailsLabelText = @"Initializing barcode reader...";

        [[[VStore sharedVStore] barcode] setDelegate:self];
        [[[VStore sharedVStore] barcode] initDevice];
        
        [self setDefaultBarcodeOptions];
        
        if(hudView) hudView.detailsLabelText = @"Setting card scanner to OFF";
        [[VStore sharedVStore] enableCardScanner:NO];   // start off with card scanner disabled;
                                                        // server will send a message when it wants it on

#if (0) // log internal state of VX600/VMFFramework as it processes messages
        [[VStore sharedVStore] logDiagnostics];
		
        // these cause the specified device to call controlLogEntry etc deletgate methods
        // with logging info from withing the VFIFramework
        [[[VStore sharedVStore] pinPad] logEnabled:YES];
        [[[VStore sharedVStore] payControl] logEnabled:YES];
#endif

        dispatch_async(dispatch_get_main_queue(), ^{
            if(hudView) hudView.detailsLabelText = @"Attempting to set VX encryption mode ...";
            [self setEncryptionMode];
            [[VStore sharedVStore] displayInitCompleteLCDMessage];
            if(hudView) hudView.detailsLabelText = @"Complete!";
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            verifoneDeviceInitDone = YES;
        });

		
    }
    

	DLog(@"%@", @"Verifone Init Complete; now waiting on -isConnected replies."); 
    
    verifoneDeviceInitStarted = NO; 
    
    if (verifoneDeviceInitDone) {
		// Original Verifone comment
        // do g14 for bt fw version... 
		//        [[[VStore sharedVStore] payControl] sendCommandLRC:@"G14"]; 
        
        // get keypad fw version... 
        //[[[VStore sharedVStore] payControl] queryKeypadVersion];
        //DLog(@"Keypad version:%@.%@", [[[[VStore sharedVStore] payControl] vfiKeypadVersion  ]FirmwareMajor], [[[[VStore sharedVStore] payControl] vfiKeypadVersion] FirmwareMinor]);
    
    }
    
}

//MARK: EAAccessoryDidConnectNotification
- (void)accessoryDidConnect:(NSNotification *)note
{
    // This will be called if 30-pin device comes on line after app launches.
    // The other possible path is the app launches and the device is already connected.
    
    SPLog(@"accessory Did Connect");
    DLog(@"%@", @"accessory Did Connect");
    
    if (verifoneDeviceInitDone) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        return;
    }
    
    // BMonk: this sort of "verifoneDeviceInitStarted" thing shouldn't be necessary...
    // but it's in the verifone sample code. Which is suspect works partly by luck...

    if (verifoneDeviceInitStarted == NO) {
        verifoneDeviceInitStarted = YES; 
        
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.labelText = @"Initializing Verifone Device";
        hud.detailsLabelText = @"Please Wait...";
        
        // Monk: Below is original verifone comment. 16 seconds is not exactly a "short delay" but that's what it says.
        // Verifone: "do some init type things after a short delay to let the device catch its breath. "
        // Monk: actually it takes the VX600 about 25 sec to fully boot.
        // However, we don't know at what point in that boot sequence iOS sends us the accessoryDidConnect:
        // message that gets us here...
        [self performSelector:@selector(initVerifoneDevice) withObject:nil afterDelay:16.0];
    }
    
}

//MARK: EAAccessoryDidDisconnectNotification
- (void)accessoryDidDisconnect:(NSNotification *)note 
{
#if DEBUG	
    NSString *accessoryName = [[note userInfo] objectForKey:EAAccessoryKey];

    SPLog(@"accessory DidDisconnect");
    DLog(@"accessory:%@ DidDisconnect", accessoryName);
#endif
	
    

    [EAAccessoryManager logConnectedAccessories];
}

//MARK: -

- (NSString *)nameForEncryptionTypeCode:(EncryptionMode)code
{
    NSString *encryptionName = @"Unknown encryption type";
    switch (code) {
        case EncryptionMode_VSP:
            encryptionName = @"VSP";
            break;
        case EncryptionMode_PKI:
            encryptionName = @"PKI";
            break;
        case EncryptionMode_NOE:
            encryptionName = @"NONE";
            break;
        default:
            break;
    }
    return encryptionName;
}

//MARK: VFMMessage
-(void)VFMMessageReceived:(NSNotification *)note
{
    //Monk: this would be sent by Verifone's framework. Purpose?  
	SPLog(@"VFMNotificationReceived");
	DLog(@"%@", @"VFMNotificationReceived");
}

- (void)connectWithExternalAccessory
{
#define CONNECT_WITH_ACCESSORY (1)
#if !CONNECT_WITH_ACCESSORY
    return;
#endif
        
	SPLog(@"Attempting Connection with accessory");
	
    // redirectConsoleToFile is useful when device is in sled, since can't attach 30-pin to debug. SPEAK_DEBUG_STRINGS/SPLog is handier
    // but not as verbose. If -logEnabled (do a search in this file) is set after accessory is initialized, internal logging from VMFFramework will also be logged
    //
    // Another options is to use the app BNRConsole, which gathers the log on the device (while in sled) and emails it
#define RedirectConsoleToFile (0)
	if (RedirectConsoleToFile) [self redirectConsoleLogToDocumentFolder];
	
    // this will most likely fail the first time if accessory not yet connected and 
    // fully inited (the Verifone device has its own somewhat lengthy startup sequence)
	BOOL foundVerifoneDevice = [VStore verifoneEAAccessoryProtocolExists]; 
	if (foundVerifoneDevice) {
		// Verifone comment: "we're goood.  Do the init... Otherwise we'll do it when we connect."
        
        SPLog(@"found Verifone Device connected, init-ing");
		
		// Verifone comment: "do some init type things after a short delay to let the device catch its breath."
        // Monk: note the sled can take up to 25sec to boot
		[self performSelector:@selector(initVerifoneDevice) withObject:nil afterDelay:2.0];
	} else {
        [self displayNoVerifoneDeviceAlert];
    }
}

- (IBAction)setPublicKey:(id)sender {
    [self setEncryptionMode];
    [self hideButtonOverlayView];
}

- (IBAction)resetEncryptionMode:(id)sender {
    [self setEncryptionMode];
}

//MARK:

- (BOOL)setEncryptionMode
{
#define kUseVerifoneDemoKey (0)
#if kUseVerifoneDemoKey
    // Set verifone's dummy public key (their code).
    // In actual use this will come from SC/ACI server
    NSString *certData1 = @"-----BEGIN PUBLIC KEY-----\n";
    NSString *certData2 = @"MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqDRh+sXNMn2y9Tmpu+4s\n";
    NSString *certData3 = @"g79X5/i1ddhVQUZjPW5MebiIORCD6IFm6ruPd/jDjKad/cX364EggmF/5YeZOxca\n";
    NSString *certData4 = @"rSVnM3EmBex//6SzP2U/L8oIMIdBt9sTCev4BrdKe7oXyqUOTZ2gJQ37QmAymc5N\n";
    NSString *certData5 = @"9X2MCxGvD+d4zsUJWRRUzrCbfejjF+YMUD6PEtQIxdbYWRV+r4ovGI0B1cd5751B\n";
    NSString *certData6 = @"2IG73n1mJPh53LJHRTwCez2Y/zwx2F7ZKsCsqlLYDTAPC3wYvK9UG4j0sUc/kYjB\n";
    NSString *certData7 = @"2RNxt4gemZ6AtFUaLhTFEUR6swL96MdAdf5fYA4iIM1JHDnkBLMQPDRJzdlIhVv/\n";
    NSString *certData8 = @"qwIDAQAB\n";
    NSString *certData9 = @"-----END PUBLIC KEY-----\n";
    
    NSString *cert = [NSString stringWithFormat:@"%@%@%@%@%@%@%@%@%@",certData1,certData2,certData3,certData4,certData5,certData6,certData7,certData8,certData9];
    NSString *certID = @"114436";
    
#else // get key from Shoe Carnival server
    
    NSString *cert = [[SCServerPublicKeyDownloadController sharedController] publicKey];
    NSString *certID = [[SCServerPublicKeyDownloadController sharedController] publicKeyID];
#endif
    if (!isEmptyString(cert)) {
        NSString *s = @"Public key exists; setting VX600 encryption mode to PKI";
        NSLog(@"%@", s);
        SPLog(s);
        EncryptionMode mode = [[[VStore sharedVStore] pinPad] selectEncryptionMode:EncryptionMode_PKI];
        [[[VStore sharedVStore] pinPad] E08_RSA:cert publicKeyID:certID];
        if (mode != EncryptionMode_PKI) {
            NSLog(@"%@", @"This VX600  appears not to support PKI.");
            SPLog(@"Device appears not to support VSP.");
        }

    } else {
        // No public key exists; infer as a signal to us to set VSP encryption.
        NSString *s = @"No public key exists; interpreting as a request to set VX600 encryption mode to VSP";
        NSLog(@"%@", s);
        SPLog(s);
        EncryptionMode mode = [[[VStore sharedVStore] pinPad] selectEncryptionMode:EncryptionMode_VSP];
        if (mode != EncryptionMode_VSP) {
            NSLog(@"%@", @"This VX600  appears not to support VSP. VSP activated on device?");
            SPLog(@"Device appears not to support VSP. VSP activated on device?");
        }
    }
    
    
    EncryptionMode mode = [[[VStore sharedVStore] pinPad] getEncryptionMode];
    NSLog(@"VX600 reports its encryption mode is now:%@", [self nameForEncryptionTypeCode:mode]);
    SPLog(@"VX 600 reports encryption mode is now:%@", [self nameForEncryptionTypeCode:mode]);
    
    return isEmptyString(cert);
}

//MARK: - VFIPinpadDelegate

//Monitors connect/disconnect events from [[VStore sharedVStore] pinPad]
- (void)pinpadConnected:(BOOL)isConnected
{
    SPLog(@"pinpad Connected: %@", isConnected ? @"YES" : @"NO");
    DLog(@"delegate received pinpadConnected: %@", isConnected ? @"YES" : @"NO");
    
    if (isConnected) {
        
        [[VStore sharedVStore] enableCardScanner:NO];   // start off with card scanner disabled;
                                                        // SC server will send message when it wants it on
                
        // Setting sled encryption mode is now done as part of communicatio with the Shoe Carnival server.
        //[self setEncryptionMode];

        // going away (setting number of tracks now done via message from SC server on port 600)
        //SPLog(@"Enabling MSR dual track");
        //DLog(@"%@", @"Enabling MSR dual track");
        //[[[VStore sharedVStore] pinPad] enableMSRDualTrack];
        
        if(![[[VStore sharedVStore] pinPad] pinpadConnected]) {
            SPLog(@"ERROR pinPad just reported it is connected, but when re-queried, immediately reports it is NOT connected.");
            DLog(@"%@", @"ERROR pinPad just reported it is connected, but when re-queried, immediately reports it is NOT connected.");
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:ConnectVX600Notification object:nil];
        }
    }
}

- (void)pinpadDataReceived:(NSData*)data {
    return; // unused
    
    SPLog(@"pinpadDataReceived %u bytes", [data length]);
    DLog(@"pinpadDataReceived %lu bytes", (unsigned long)[data length]);
    
    NSString *pinPadDataAsString = [[VStore sharedVStore] nsdataToNSString:data];
    
    if ([pinPadDataAsString length] >= 2) {
        if ([[pinPadDataAsString substringToIndex:2] isEqualToString:@"06"]) {
            // Verifone sample code doesn't indicate what this case means... originally nothing was done here
            SPLog(@"pinpad Data Received ignoring %u bytes", [data length]);
            DLog(@"pinpadDataReceived ignoring %lu bytes", (unsigned long)[data length]);

        } else {
            DLog(@"pinpadDataReceived: %@", [[VStore sharedVStore] hexToString:[[VStore sharedVStore] nsdataToNSString:data]]);
            
        }
    }
}

// One track (track 2 only)
#ifdef UNUSED
- (void) pinpadMSRData:(NSString*)pan  expMonth:(NSString*)month  expYear:(NSString*)year  trackData:(NSString*)track2
{
    NSString *msg = [NSString stringWithFormat:@"received pinpadMSRData with month:%@ year:%@ track2 dataLength:%u", month, year, [track2 length]];
    SPLog(@"pinpad received one track of data:%@", msg);
    DLog(@"pinpad received one track of data:%@", msg);
}
#endif


// Two tracks
- (void)pinpadMSRData:(NSString*)pan expMonth:(NSString*)month expYear:(NSString*)year track1Data:(NSString *)track1 track2Data:(NSString *)track2
{
    NSString *msg = [NSString stringWithFormat:@"pinpad received two tracks of data for pan:%@ month:%@ year:%@ track1 dataLength:%lu track2 dataLength:%lu \n\n", pan, month, year, (unsigned long)[track1 length], (unsigned long)[track2 length]];
    SPLog(msg);
    DLog(@"%@", msg);
    
    //DLog(@"track1:%@", track1);
    //DLog(@"track2:%@", track2);
    
    NSString *blob1 = nil;
    EncryptionMode encryptionMode = [[[VStore sharedVStore] pinPad] getEncryptionMode];
    if (encryptionMode == EncryptionMode_PKI) {
        
        [[[VStore sharedVStore] pinPad] getPKICipheredData]; // pulls data into pinPad.vfiCipheredData
        
        int encryptionTypeCode = [[[[VStore sharedVStore] pinPad] vfiCipheredData] encryptionType];
        NSString *encryptionName = [self nameForEncryptionTypeCode:encryptionTypeCode];
        
        msg = [NSString stringWithFormat:@"Encryption Type:%@\n, KeyID:%@\n, dataType:%d \n\n",
               encryptionName,
               [[VStore sharedVStore] pinPad].vfiCipheredData.keyID,
               [[VStore sharedVStore] pinPad].vfiCipheredData.dataType];
        SPLog(msg);
        DLog(@"%@", msg);
        
        // This error seen 10/4/12
        if (encryptionTypeCode != EncryptionMode_PKI) {
            msg = [NSString stringWithFormat:@"Error, encryption type of data is %@, expected %@",
                   [self nameForEncryptionTypeCode:encryptionTypeCode],
                   [self nameForEncryptionTypeCode:EncryptionMode_PKI]];
            SPLog(msg);
            DLog(@"%@", msg);
            // should return if this happens? Or just let transaction proceed and fail?
        }
        
        DLog(@"%@", @"getting PKU blob1");
        blob1 = [[VStore sharedVStore] pinPad].vfiCipheredData.encryptedBlob_1;
        //DLog(@"Blob1:%@", blob1);
        
        //DLog(@"%@", @"getting blob2");
        //NSString *blob2 = [[VStore sharedVStore] pinPad].vfiCipheredData.encryptedBlob_2;
        //DLog(@"Blob2:%@", blob2);
        
        // Forward to the blob per ACI protocol from Dave Posluszny <mdp3351@acrretail.com>
        // How about a "^P" (decimal 16) denotes the start of PINPAD data being echoed via the VNC.
        // Then the second character that follows will represent the data type:
        // 0x02 - Card swipe data.
        // Only track two should be sent, with a 0x0d to signal the end of the stream.
        /*
         According to the E07 response documentation, the blob2 would only be present
         if track 3 is present on the card.  Track 3 is ignored by our software, so
         that's not a concern for us.  The first blob is what contains the important
         data for card transactions, which is track 1 & 2.
         
         So this looks good, and it's 344 bytes as promised by their documentation.
         */
    }
    
    [[VStore sharedVStore] displayLCDMessage:@"CARD"
                                       line2:@"DATA"
                                       line3:@"OK"
                                       line4:@""
                                  forSeconds:3.0];

    [[VStore sharedVStore] displayLCDMessage:@"Forwarding"
                                       line2:@"card data"
                                       line3:@""
                                       line4:@""
                                  forSeconds:2.0];

    
    // For VSP and PKI encryption, send track2 data
    DLog(@"Sending track two to server. Track length from VX600 was:%lu", (unsigned long)[track2 length]);
    SPLog(@"Sending track two to server. Track length from VX600 was:%d", [track2 length]);
    [[SCServerProtocolController sharedController] sendCardData:track2];
    
    // For PKI only, encrypted blob1 follows. 
    if (encryptionMode == EncryptionMode_PKI) {
        DLog(@"Sending blob1 to server. Data length from VX600 was:%lu", (unsigned long)[blob1 length]);
        SPLog(@"Sending blob 1 to server. data length from VX600 was:%d", [blob1 length]);
        [[SCServerProtocolController sharedController] sendEncryptedCardData:blob1];
    }
    
    [self displayDefaultPinPadReadyMessage];
}

- (void) pinpadLogEntry:(NSString *)logEntry withSeverity:(int)severity
{
	DLog(@"pinPad Log Entry: %@", logEntry);
}

//MARK: - VFIBarcodeDelegate
/*
 - (void) barcodeConnected:(BOOL)isConnected;
 - (void) barcodeDataReceived:(NSData*)data;
 - (void) barcodeDataSent:(NSData*)data;
 - (void) barcodeScanData:(NSData*)data;*/

- (void) barcodeConnected:(BOOL)isConnected
{	
#if 0 // from Verifone sample
    DLog(@"%@", [NSString stringWithFormat:@"IC:BC/PP/CTL - C:%d/%d/%d  I:%d/%d/%d\n%@",
                       ([[VStore sharedVStore] barcode].connected), 
                       ([[VStore sharedVStore] pinPad].connected),                        
                       ([[VStore sharedVStore] payControl].connected), 
                       ([[VStore sharedVStore] barcode].initialized),                        
                       ([[VStore sharedVStore] pinPad].initialized), 
                       ([[VStore sharedVStore] payControl].initialized), 
                       miscText.text]);
#endif	
    
    SPLog(@"barcode Connected: %@", isConnected ? @"YES" : @"NO");

    if (isConnected) {
        
        [self setDefaultBarcodeOptions];
        
        // Comment from Verifone sample:
		//
        // turning scan back on is tricky... trying to use application became active.
        // The idea is that we only want scanner on if we want scanner on... that's the trick... 
		//
        DLog(@"%@", @"Wake up barcode in isConnected...");
        [[VStore sharedVStore] barcodeScanOnAfterSleeping]; 
		
		
	} 
}

#ifdef UNUSED
- (void) barcodeDataReceived:(NSData*)data
{
	SPLog(@"Barcode data received");
	DLog(@"%@", @"Barcode data received");
	
    NSString *dataAsString = [[VStore sharedVStore] nsdataToNSString:data]; 
    
    if ([dataAsString length] >= 2) {
        if ([[dataAsString substringToIndex:2] isEqualToString:@"06"]) {
            // case is blank in Verifone code
        } else {
		
        SPLog(@"Barcode data: %@", dataAsString);
        DLog(@"%@", @"Barcode data: %@", dataAsString);
		//DLog(@"BCRECV: %@", [self hexToString:[self nsdataToNSString:data]]);
		// Log field in sample:
		//[miscText setText:[NSString stringWithFormat:@"BCRECV: %@\n%@", dataAsString, miscText.text]]; 
        }
    }
}
#endif

static BOOL gotScan = NO; 

- (void) barcodeScanData:(NSData*)data barcodeType:(int)barcodeType
{
    DLog(@"%@", @"\n\n--- BARCODE SCAN DATA RECEIVED ---\n"); 
    SPLog(@"BARCODE SCAN DATA RECEIVED"); 
	
    gotScan = YES; 
	
	NSString *hexString = [[VStore sharedVStore] nsdataToNSString:data];
	NSString *asciiString = [[VStore sharedVStore] hexToString:hexString];

    char crlf_c[3] = { 0x0d, 0x0a, 0x00 };
    NSString *crlf = [NSString stringWithCString:crlf_c encoding:NSASCIIStringEncoding];

    if([asciiString hasSuffix:crlf]) {
        NSRange r = NSMakeRange(0, asciiString.length - 2);
        asciiString = [asciiString substringWithRange:r];
    }
    
    /* From Dave Posluszny <mdp3351@acrretail.com>
     2) Scanner data - This should already be supported by ACR. Dean would setup a 'keyboard wedge' scanner similar to what he did for the MF-2350 handheld device.  
     // Bill, if you echo the scanner data as key data, please send a starting sentinal of "^B" (decimal 2), followed by the barcode data and a 0x0D to signal the end of the stream.
     */
	DLog(@"forwarding barcodeScanData as ASCII:%@\n\n", asciiString);
    // create a string of each char in barcode separated by spaces, so it gets read aloud as "1 2 3" rather than "One Hundred Twenty Three"
    NSString *numericSpokenString = @"";
    for (NSInteger i = 0; i < [asciiString length]; i++) {
        numericSpokenString = [numericSpokenString stringByAppendingFormat:@"%c ", [asciiString characterAtIndex:i]];
    }
	SPLog(@"forwarding barcode Scan Data to server as ASCII:%@", numericSpokenString);
    
    // Display the scanned data - for debugging purposes ONLY
    /*
    UIAlertView *scannedDataView = [[UIAlertView alloc] initWithTitle:@"Scanned Data"
                                                              message:asciiString
                                                             delegate:self
                                                    cancelButtonTitle:@"OK"
                                                    otherButtonTitles:nil, nil];
    [scannedDataView show];
    */
    
    [self sendVNCKeypressesFromString:asciiString];

}


- (void) barcodeDataSent:(NSData*)data
{
    // Monk: Note this delegate method will receive a number of data blocks from the barcide 
    // upon init / connection to the barcode scanner. No idea of their significance....  

#if 0
	NSString *dataAsString = [[VStore sharedVStore] nsdataToNSString:data];
	DLog(@"barcodeDataSent:%@\n\n", dataAsString);
#endif
    
}


- (void) commandResult:(int)result {
	DLog(@"commandResult:%d", result);
}


- (void) barcodeTriggerEvent:(int)triggerCode 
{
    SPLog(@"Barcode trigger event received:%d", triggerCode);
    
    DLog(@" ----------------------------- BARCODE TRIGGER: %d --------------------------------\n", triggerCode);
	    
#if 1 // from Verifone sample
	static int lastTrigger = -1; 

	@synchronized(self) {
        //if (softMode)
        {
            if (triggerCode == lastTrigger) {
                DLog(@"DEBOUNCE: IGNORING BARCODE TRIGGER: %d\n", triggerCode);
                // we have bounced. ignore it...
            } 
			else {
                lastTrigger = triggerCode;
                                
				switch (triggerCode) {
						
					case BCS_TRIGGER_RELEASED:
						// if lifting off button without a good scan, disable. Otherwise, the good scan will have
						// disabled. 
						if (gotScan == NO) {
							[[[VStore sharedVStore] barcode] sendTriggerEvent:NO];  // turns off the scanner. 
							DLog(@"sendTriggerEvent:NO for trigger:%d\n", triggerCode);                         
						}
						break;
						
					case BCS_TRIGGER_LEFT_PRESSED:
					case BCS_TRIGGER_RIGHT_PRESSED:
						[[[VStore sharedVStore] barcode] sendTriggerEvent:YES];  // lights up the scanner.         
						DLog(@"sendTriggerEvent:YES fpr trigger:%d\n", triggerCode);
						
						gotScan = NO; 
						break;
						
					default:
						break;
				}
			}
		}
    }
#endif
	
}

- (void) barcodeSerialData:(NSData*)data  incoming:(BOOL)isIncoming {
}

//MARK: - VFIControlDelegate

- (void) controlConnected:(BOOL)isConnected;
{
    DLog(@"pay control Connected: %@", isConnected ? @"YES" : @"NO");
    SPLog(@"pay control Connected: %@", isConnected ? @"YES" : @"NO");
}

- (void) controlLogEntry:(NSString*)logEntry withSeverity:(int)severity {
    DLog(@"payControl Log Entry: %@", logEntry);
}

// MARK: - UIAlertViewDelegate

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if ([alertView.title isEqual: @"No VNC Connection"] || [alertView.title isEqual:@"VNC Connection Terminated"]) {
        if (![self vncView]) {
            [self configServer];
        }
    }
}

@end
