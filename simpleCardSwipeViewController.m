//
//  simpleCardSwipeViewController.m
//  simpleCardSwipe
//
//
// Based on code by Thomas Salzmann on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//
//  Altered for Shoe Carnival by BigNerdRanch 2012
//
#import <dispatch/dispatch.h>

#import "simpleCardSwipeViewController.h"
#import "VStore.h" 
#import "VFIBarcodeDelegate.h"
#import "SCServerPublicKeyDownloadController.h"
#import "EAAccessoryManager+Utils.h"
#import "NSString+Utils.h"

#define redirectConsole (1)

@implementation simpleCardSwipeViewController

// @synthesize zonTalk;c
// @synthesize payControl; 
@synthesize cardData; 
@synthesize controlButton;
@synthesize connectButton;
@synthesize waitSwipe; 
@synthesize frameworkReturnCode; 
@synthesize frameworkReturnCode2; 
@synthesize miscText;
#if !RunWithoutNeedlessTimers
    @synthesize myTimer; 
#endif
@synthesize batteryCheckTimer; 
@synthesize myAlert; 
@synthesize myAlert2; 
@synthesize hideUnHide; 
@synthesize controlNotReady; 
@synthesize pinpadNotReady; 
@synthesize versionLabel; 
@synthesize kfwLabel; 
@synthesize battery; 

// CAC Added this for a constant for acc read threshold
#define kAccelerationThreshold 0

#define MYVERSION @"0.78bg" // 2011.12.08


- (IBAction)verifoneTestScreenDoneButtonTapped
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}


/* CRITICAL - Because of VSP track encryption, MSR MUST REMAIN ENABLED BETWEEN CARD SWIPE AND 
   The prompt for ENTER PIN!!!!!!!!!!!  Disabling card swipe will cause the VCL buffer to be 
   cleared and the ultimate PIN decryption by HSM to fail.  
 */


- (void) disableMSR:(BOOL) msrFlag  {

//	@synchronized(self) {
		
		//int saveFrameWorkTimeout = [[VStore sharedVStore] pinPad ].frameworkTimeout; 
		//int saveAckTimeout = [[VStore sharedVStore] pinPad ].ackTimeout; 

		//[[[VStore sharedVStore] pinPad] setFrameworkTimeout:1.0];  
		//[[[VStore sharedVStore] pinPad] setACKTimeout:2.0];  
        
        /* 
         New methods:
         - (void) Q42;
         - (void) enableMSRDualTrack;
         
         New optional delegate protocol:
         - (void) pinpadMSRData:(NSString*)pan  expMonth:(NSString*)month  expYear:(NSString*)year  track1Data:(NSString*)track1  track2Data:(NSString*)track2;
         
         Both the original pinpadMSRData and the new pinpadMSRData are called by both Q40 and Q42.   Q42 populates the track2 of the original protocol, and Q40 only populates the track2 of the new protocol. 

         */

		
		if (msrFlag) {
			
			DLog(@"%@", @"disable MSR"); 
	//		[[[VStore sharedVStore] pinPad] noResponseNextCommand];
	//		[[[VStore sharedVStore] pinPad] sendStringCommand:@"Q41" calcLRC:YES]; 	 

            [[[VStore sharedVStore] pinPad] disableMSR]; 
			
		} else {
			
			DLog(@"%@", @"enable MSR"); 
	//		[[[VStore sharedVStore] pinPad] noResponseNextCommand];
	//		[[[VStore sharedVStore] pinPad] sendStringCommand:@"Q42" calcLRC:YES]; 	 
            
            [[[VStore sharedVStore] pinPad] enableMSRDualTrack]; 
			
		}
		
		//[[[VStore sharedVStore] pinPad] setACKTimeout:saveAckTimeout];  
		//[[[VStore sharedVStore] pinPad] setFrameworkTimeout:saveFrameWorkTimeout]; 
        
// TESTING KLUGE FOR CTLS ISSUE        
        
//        [NSThread sleepForTimeInterval:0.155]; 

        
        
//	}
	
}

- (void) redirectConsoleLogToDocumentFolder
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
														 NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *logPath = [documentsDirectory
						 stringByAppendingPathComponent:@"console.log"];
	freopen([logPath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stderr);
}

static BOOL myInitDone = NO; 
static BOOL myInitStarted = NO; 




-(void)updateBatteryBar {

    [[[VStore sharedVStore] payControl] queryBatteryLevel];
    
    float myBattery = [[VStore sharedVStore] payControl].batteryLevel; 
    
    myBattery = myBattery / 100; 
   
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"5.0")) {
    
     if (myBattery < 0.25) {
		 [battery setProgressTintColor: [UIColor redColor]] ;             
     } else if (myBattery < 0.5) {
		 [battery setProgressTintColor: [UIColor yellowColor]] ;                         
     } else {
		 [battery setProgressTintColor: [UIColor greenColor]] ;             
     }
    
    }
   
    [battery setProgress:myBattery ]; 

//    NSMutableArray* arr = [NSMutableArray array];
//    [arr addObject:@"KSN=1"];
//    [[[VStore sharedVStore] pinPad] setParameterArray: arr];
    
//    
//    NSMutableArray* arr = [NSMutableArray array];
//    [arr addObject:@"*APPOVERRIDE=0"];
//     [arr addObject:@"*STAYCONNECTED=1"];
//     [arr addObject:@"*KEEPALIVE=1"];
//     [arr addObject:@"*POWERSHARE=100"];
//     [arr addObject:@"*CHARGEHOST=100"];
//    [arr addObject:@"*XCDEBUG=1"];
//    [[[VStore sharedVStore] pinPad] setParameterArray: arr];
     

  /*
    NSMutableArray* arr = [NSMutableArray array];
    [arr addObject:@"*APPOVERRIDE=0"];
    [arr addObject:@"*STAYCONNECTED=1"];
    [arr addObject:@"*KEEPALIVE=1"];
     [arr addObject:@"*POWERSHARE=0"];
     [arr addObject:@"*CHARGEHOST=50"];
    [arr addObject:@"*XCDEBUG="];
    [[[VStore sharedVStore] pinPad] setParameterArray: arr];
*/
    
    /*
    NSMutableArray* arr = [NSMutableArray array];
    [arr addObject:@"OPTFLAG=\"1100000000000000\""];
    [[[VStore sharedVStore] pinPad] setParameterArray: arr];
*/
    
   /* 
    NSMutableArray* arr = [NSMutableArray array];
    [arr addObject:@"*CHARGEHOST=99"];   
    [arr addObject:@"*POWERSHARE=99"];    
    [[[VStore sharedVStore] pinPad] setParameterArray: arr];
    */

     
   //  NSMutableArray* arr = [NSMutableArray array];
   //  [arr addObject:@"*BT_SSP_EN=OFF"];   
   //  [arr addObject:@"*BT_PIN=1003"];    
   //  [[[VStore sharedVStore] pinPad] setParameterArray: arr];	
     
    
    
  //  NSMutableArray* arr = [NSMutableArray array];
  //  [arr addObject:@"*APPOVERRIDE=0"];
  //  [arr addObject:@"*STAYCONNECTED="];
  //  [arr addObject:@"*KEEPALIVE="];
  //  [arr addObject:@"*XCDEBUG="];
  //  [[[VStore sharedVStore] pinPad] setParameterArray: arr];



    
}

static BOOL noBattPoll = NO; 

- (void)turnOffBatteryPolling {
    noBattPoll = YES; 
}

- (void)batteryCheckTimerFired:(NSTimer *)theTimer 
{
    if (noBattPoll) return; 
    
    @synchronized(self) {
        
    if (([[VStore sharedVStore] pinPad].connected) && ([[VStore sharedVStore] pinPad].initialized)) {
        // [[[VStore sharedVStore] pinPad] enableMSR];

        [self updateBatteryBar]; 
   
        }
    }
}	


- (BOOL)openSessionForProtocol:(NSString *)protocolString {
	return [EAAccessoryManager accessoryProtocolExists:protocolString];
}

-(BOOL) init01BCFlagFile {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *foofile = [documentsDirectory stringByAppendingPathComponent:                         
                          [NSString stringWithFormat:@"bcInit01.%@", [[VStore sharedVStore] pinPad].vfiDiagnostics.pinpadSerialNumber ]];
    
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:foofile];
    
    if (fileExists) {
        return fileExists;
        
    } else {
        
        [@"Hello BC" writeToFile:foofile atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        /*
         
         NSMutableArray* arr = [NSMutableArray array];
         [arr addObject:@"*APPOVERRIDE=0"];
         [arr addObject:@"*STAYCONNECTED=1"];
         [arr addObject:@"*KEEPALIVE=1"];
         [arr addObject:@"*POWERSHARE=100"];
         [arr addObject:@"*CHARGEHOST=100"];
         [arr addObject:@"*XCDEBUG="];
         [[[VStore sharedVStore] pinPad] setParameterArray: arr];
         
         */

       
        return NO; 
    }
    
}

#if RunWithoutNeedlessTimers
- (void)delayedInitVerifoneDevice
#else
- (void)delayedInitVerifoneDevice:(NSTimer *)theTimer 
#endif
{
    DLog(@"%@", @"Enter Verifone delayed init code..."); 
    
    myInitStarted = YES; 

#define kLogSledInitTime (0)
#if kLogSledInitTime
    CFTimeInterval startTime = CFAbsoluteTimeGetCurrent();    
#endif
    
    // gen 2.5  ... The correct protocol is com.verifone.PWMRDA, but you don't need to worry about this.  It is hidden/managed by the framework.

    
    if ([self openSessionForProtocol:@"com.verifone.pmr2.xpi"]) {
        [miscText setText:[NSString stringWithFormat:@"Found accessory.\n%@",  miscText.text]]; 
        DLog(@"%@", @"Salzo Found Accessory..."); 

    } else if ([self openSessionForProtocol:@"com.verifone.PWMRDA"]) {
        [miscText setText:[NSString stringWithFormat:@"Found accessory BLUETOOTH.\n%@",  miscText.text]]; 
        DLog(@"%@", @"Salzo Found BT Accessory..."); 
        
    } else {
        [miscText setText:[NSString stringWithFormat:@"Cannot Find Accessory.\n%@",  miscText.text]]; 
        DLog(@"%@", @" DID NOT Find Accessory..."); 

    }
    
    //Set up listener for any broadcast messages from the framework
    //DLog(@"%@", @"set up for broadcasts"); 
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedVFMMessage:) name:@"VFMMessage" object:nil];

    DLog(@"%@", @"Salzo init [[VStore sharedVStore] pinPad]"); 
    [miscText setText:[NSString stringWithFormat:@"Init Pinpad.\n%@",  miscText.text]]; 
    
    //Allocate instance of [[VStore sharedVStore] pinPad] class, set self as delegate, and initialize connection
#ifdef kVStoreDoesntAllocOwnSledObjects
    [VStore sharedVStore].pinPad = [[[VFIPinpad alloc] init] autorelease];
#endif
    
//    [[[VStore sharedVStore] pinPad] setFrameworkTimeout:5]; // ios5 bug workaround. 
    
    DLog(@"%@", @"Set pinPad delegate and call init Device"); 
    [[[VStore sharedVStore] pinPad] setDelegate:self];
    [[[VStore sharedVStore] pinPad] initDevice];    
    
    if ([[VStore sharedVStore] pinPad].vfiDiagnostics.osversion == nil) {
        DLog(@"%@", @"Init Pinpad Failed. Restart App."); 
        
        [[[VStore sharedVStore] pinPad]closeDevice]; 
        self.myAlert2 = [[VStore sharedVStore] showAlertWithMessage:@"Init Failed\nRestart App..."];
        
        [NSThread sleepForTimeInterval:3.405]; // <-- original Verifone code - why 3.405???

        exit(0); // <-- original Verifone code - potential for data loss? BMonk 7/19/12
        
    } else {
        
        [[[VStore sharedVStore] pinPad] setFrameworkTimeout:120]; // ENTER PIN timeout old way. 
        [[[VStore sharedVStore] pinPad] setPINTimeout:70]; // ENTER PIN timeout 
        [[[VStore sharedVStore] pinPad] setAccountEntryTimeout:120]; 
        [[[VStore sharedVStore] pinPad] setPromptTimeout:70]; 
        [[[VStore sharedVStore] pinPad] setACKTimeout:3.0];  

        [[[VStore sharedVStore] pinPad] setKSN20Char:YES]; 

        
        DLog(@"%@", @"Initing payControl"); 
#ifdef kVStoreDoesntAllocOwnSledObjects
        [VStore sharedVStore].payControl = [[[VFIControl alloc] init] autorelease]; 
#endif
        [[[VStore sharedVStore] payControl] setDelegate:self]; 
        [[[VStore sharedVStore] payControl] initDevice]; 
        [[[VStore sharedVStore] payControl] keypadBeepEnabled:YES] ;  
        [[[VStore sharedVStore] payControl] keypadEnabled:NO]; 
        [[[VStore sharedVStore] payControl] hostPowerEnabled:YES]; 
        
        // try doing all this init here to save time later.
        DLog(@"%@", @"Initing barcode"); 
#ifdef kVStoreDoesntAllocOwnSledObjects
        [VStore sharedVStore].barcode = [[[VFIBarcode alloc] init] autorelease];
#endif
        
#define kVStoreIsOwnSledDelegate 1
#if ! kVStoreIsOwnSledDelegate
        [[[VStore sharedVStore] barcode] setDelegate:self];
#endif
        [[[VStore sharedVStore] barcode] initDevice];
        
        if ([self init01BCFlagFile] == NO) {
            [[VStore sharedVStore] barcodeScanOn]; 
            [[[VStore sharedVStore] barcode] setScanner2D]; 	
            [[[VStore sharedVStore] barcode] setScanTimeout:5000]; 
            [[[VStore sharedVStore] barcode] includeAllBarcodeTypes]; 
            // soft mode        [[[VStore sharedVStore] barcode] setLevel];	
            // Return the type in the barcode delegate
            [[[VStore sharedVStore] barcode] barcodeTypeEnabled:YES]; 
        }
        
        // disable msr 
        //        [miscText setText:[NSString stringWithFormat:@"Disable MSR.\n%@",  miscText.text]]; 
        [self disableMSR:YES];  
        
        NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        appVersionString = [NSString stringWithFormat:@"v%@", appVersionString];
        [[[VStore sharedVStore] pinPad] displayMessages:@"SHOE CARNIVAL"
                                                  Line2:@"iOS Client"
                                                  Line3:appVersionString
                                                  Line4:@"INIT COMPLETE"];


//        [[[VStore sharedVStore] payControl] queryKeypadVersion];
//        NSMutableString *str = [NSMutableString array];
//        [str appendFormat:@"Processor: %@\n",[[VStore sharedVStore] payControl].vfiKeypadVersion.Processor];
//        [str appendFormat:@"Bootloader Major: %@\n",[[VStore sharedVStore] payControl].vfiKeypadVersion.BootloaderMajor];
//        [str appendFormat:@"Bootloader Minor: %@\n",[[VStore sharedVStore] payControl].vfiKeypadVersion.BootloaderMinor];
//        [str appendFormat:@"Firmware Major: %@\n",[[VStore sharedVStore] payControl].vfiKeypadVersion.FirmwareMajor];
//        [str appendFormat:@"Firmware Minor: %@\n",[[VStore sharedVStore] payControl].vfiKeypadVersion.FirmwareMinor];
        
//        NSMutableString *kfw = [NSMutableString array];
//        [kfw appendFormat:@"%@.",[[VStore sharedVStore] payControl].vfiKeypadVersion.FirmwareMajor];
//        [kfw appendFormat:@"%@",[[VStore sharedVStore] payControl].vfiKeypadVersion.FirmwareMinor];
        
        
//         [kfwLabel setText:kfw] ; 

        
/*        [[[VStore sharedVStore] payControl] querySoftwareVersion];
        NSMutableString *str1 = [NSMutableString array];
        [str1 appendFormat:@"App Major: %@\n",[[VStore sharedVStore] payControl].vfiSoftwareVersion.AppMajor];
        [str1 appendFormat:@"App Minor: %@\n",[[VStore sharedVStore] payControl].vfiSoftwareVersion.AppMinor];
        [str1 appendFormat:@"App Build: %@\n",[[VStore sharedVStore] payControl].vfiSoftwareVersion.AppBuild];
        [str1 appendFormat:@"OS Platform: %@\n",[[VStore sharedVStore] payControl].vfiSoftwareVersion.OSPlatform];
        [str1 appendFormat:@"OS ID: %@\n",[[VStore sharedVStore] payControl].vfiSoftwareVersion.OSID];
        [str1 appendFormat:@"OS Version: %@\n",[[VStore sharedVStore] payControl].vfiSoftwareVersion.OSVersion];
        [str1 appendFormat:@"OS Subversion: %@\n",[[VStore sharedVStore] payControl].vfiSoftwareVersion.OSSubVersion];
        
//        [[[VStore sharedVStore] payControl] queryBatteryLevel];
//        NSMutableString *str2 = [NSMutableString array];
//        [str2 appendFormat:@"%i",[[VStore sharedVStore] payControl].batteryLevel];
*/
       
/*     miscText.text = [NSString stringWithFormat:@"%@Framework: %@\nOS: %@\nXPI: %@\nVXCI: %@\nEMV: %@\nCTLS: %@\nVSP: %@\nPinPad: %@\n%@\n%@\n%@",
                         str,
                         [[VStore sharedVStore] pinPad].frameworkVersion, 
                         [[VStore sharedVStore] pinPad].vfiDiagnostics.osversion,
                         [[VStore sharedVStore] pinPad].vfiDiagnostics.xpiVersion,
                         [[VStore sharedVStore] pinPad].vfiDiagnostics.vxciVersion,
                         [[VStore sharedVStore] pinPad].vfiDiagnostics.emvVersion,
                         [[VStore sharedVStore] pinPad].vfiDiagnostics.ctlsReaderFirmwareVersion,
                         [[VStore sharedVStore] pinPad].vfiDiagnostics.vspVersion,
                         [[VStore sharedVStore] pinPad].vfiDiagnostics.pinpadSerialNumber,
                         @"...", // str1
                         @"...", // str2, 
                         miscText.text];
  */      

        [[VStore sharedVStore] logDiagnostics];
        
        // finish off barcode's first init. 
        [[VStore sharedVStore] barcodeScanOff]; 
        
        [[[VStore sharedVStore] pinPad] logEnabled:YES];
        [[[VStore sharedVStore] barcode] logEnabled:YES];
        [[[VStore sharedVStore] payControl] logEnabled:YES];

        myInitDone = YES; 
    }
   
	[self.myAlert dismissWithClickedButtonIndex:0 animated:YES];  
    self.myAlert = nil;
    
#if kLogSledInitTime
    CFTimeInterval difference = CFAbsoluteTimeGetCurrent() - startTime;
	DLog(@"Init Complete [%f].\n",  difference); 
#endif
    
    myInitStarted = NO; 
    
    if (myInitDone){
        [self updateBatteryBar]; 

        // do g14 for bt fw version... 
//        [[[VStore sharedVStore] payControl] sendCommandLRC:@"G14"]; 
        
        // get keypad fw version... 
#if 0
        [[[VStore sharedVStore] payControl] queryKeypadVersion];
        NSString *keypadFirmwareStr = [NSString stringWirthFormat:@"Keypad:%@.",[[VStore sharedVStore] payControl].vfiKeypadVersion.FirmwareMajor];
        keypadFirmwareStr = [keypadFirmwareStr appendFormat:@"%@",[[VStore sharedVStore] payControl].vfiKeypadVersion.FirmwareMinor]; 
        DLog(@"%@", keypadFirmwareStr);        
#endif
    }

}	

//MARK: EAAccessoryDidConnectNotification

- (void)accessoryDidConnect:(NSNotification  *)note
{
    [miscText setText:[NSString stringWithFormat:@"PWMe CONNECTED...\n%@",  miscText.text]]; 
    if (myInitDone) return; 
    if (myInitStarted == NO) {
        myInitStarted = YES; 

        self.batteryCheckTimer = [NSTimer scheduledTimerWithTimeInterval:120.0
                                                             target:self
                                                           selector:@selector(batteryCheckTimerFired:)
                                                           userInfo:nil
                                                            repeats:YES];
        
        
        // do some init type things after a short delay to let the device catch its breath.
#if RunWithoutNeedlessTimers
        [self performSelector:@selector(delayedInitVerifoneDevice) withObject:nil afterDelay:16.0];
#else
        self.myTimer = [NSTimer scheduledTimerWithTimeInterval:16.0
                                                   target:self
                                                 selector:@selector(delayedInitVerifoneDevice:)
                                                 userInfo:nil
                                                  repeats:NO];
#endif
        
        self.myAlert = [[VStore sharedVStore] showActivityIndicatorAlertWithMessage:@"Initializing\nPlease Wait..."];
        // alert is released in "delayedInitVerifoneDevice:"
    }
}

//MARK: EAAccessoryDidDisconnectNotification

- (void)accessoryDidDisconnect:(NSNotification *)note
{
	NSString *accessoryName = [[note userInfo] objectForKey:EAAccessoryKey];
	
    DLog(@"accessory:%@ DidDisconnect", accessoryName);
    SPLog(@"accessory:%@ DidDisconnect", accessoryName);

    // NSString* str = miscText.text;  //get current miscText
	
    DLog(@"%@", @"DEVICE DISCONNECTED!!!\nRemaining Devices Still Connected:\n"); //Report that device was disconnect.
    [EAAccessoryManager logConnectedAccessories];
}

//MARK: View controller delegate methods

- (void)viewDidLoad 
{
	[super viewDidLoad];

	// Turn on EAAccessoryManager notifications and add observers to receive them
	[[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];    //we want to hear about accessories connecting and disconnecting    

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(accessoryDidConnect:)
                                                 name:EAAccessoryDidConnectNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(accessoryDidDisconnect:)
                                                 name:EAAccessoryDidDisconnectNotification
                                               object:nil];
    
	// Add observers of notifications from the VStore delegate objects (barcode, pinpad, etc)
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(barcodeDidReceiveData:)
                                                 name:VerifoneBarcodeDidReceiveDataNotification
                                               object:nil];
	
    
    
    
	// Turn on accelerometer
	[UIAccelerometer sharedAccelerometer].delegate = self;
	
    if (redirectConsole) 
        [self redirectConsoleLogToDocumentFolder];
//     [self redirectConsoleLogToDocumentFolder]; 
	
    // SET VERSION HERE      
    
	
	//[waitSwipe hidesWhenStopped];  // <-- original Verifone code, accomplishes nothing. BMonk
	

    [pinpadNotReady setHidden: YES];
    [controlNotReady setHidden: YES];
    [hideUnHide setHidden: YES];
    [[VStore sharedVStore] setUpsideDown: NO]; 


    BOOL myAccessory = NO; 
    
    if ([self openSessionForProtocol:@"com.verifone.pmr2.xpi"]) {
        myAccessory = YES; 
        
        
    } else if ([self openSessionForProtocol:@"com.verifone.PWMRDA"]) {
        myAccessory = YES; 
        
        
    }
    
    if (myAccessory) {
        // we're goood.  Do the init... Otherwise we'll do it when we connect. 
        
        self.batteryCheckTimer = [NSTimer scheduledTimerWithTimeInterval:120.0
                                                             target:self
                                                           selector:@selector(batteryCheckTimerFired:)
                                                           userInfo:nil
                                                            repeats:YES];
        
        
        // do some init type things after a short delay to let the device catch its breath.
#if RunWithoutNeedlessTimers
        [self performSelector:@selector(delayedInitVerifoneDevice) withObject:nil afterDelay:0.0];
#else
        self.myTimer = [NSTimer scheduledTimerWithTimeInterval:0.0
                                                   target:self
                                                 selector:@selector(delayedInitVerifoneDevice:)
                                                 userInfo:nil
                                                  repeats:NO];
#endif
        
        self.myAlert = [[VStore sharedVStore] showActivityIndicatorAlertWithMessage:@"Initializing\nPlease Wait..."];

    }


    
    
}

- (void)viewDidAppear:(BOOL)animated 
{
    [super viewDidAppear:animated];
    
    if ([[VStore sharedVStore] barcode].initialized) [[VStore sharedVStore] barcodeScanOff]; 
    
    if (myInitDone){
        NSString *str = [NSString stringWithFormat:@"VDA:BC/PP/CTL - C:%d/%d/%d  I:%d/%d/%d\n",  
                        ([[VStore sharedVStore] barcode].connected), 
                        ([[VStore sharedVStore] pinPad].connected),                        
                        ([[VStore sharedVStore] payControl].connected), 
                        ([[VStore sharedVStore] barcode].initialized),                        
                        ([[VStore sharedVStore] pinPad].initialized), 
                        ([[VStore sharedVStore] payControl].initialized)];
        DLog(@"%@", str);     
        }

	if ([[VStore sharedVStore] pinPad].initialized) {
        
//        [self disableMSR:NO];  
        DLog(@"%@", @"viewDidAppear Setting pinpad delegate"); 
        [[[VStore sharedVStore] pinPad] setDelegate:self];

        
    } else {
    
//         [waitSwipe startAnimating]; 
//         self.myAlert = [[VStore sharedVStore] showActivityIndicatorAlertWithMessage:@"Waking Device\nPlease Wait..."];
        
        // [NSThread sleepForTimeInterval:1.5]; 

//        [myAlert dismissWithClickedButtonIndex:0 animated:YES];  

        
    }
    
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
	//[[NSNotificationCenter defaultCenter] removeObserver:self];
}

//MARK: VFMMessage notification
- (void)receivedVFMMessage:(NSNotification *)notification {
	
	NSString *msg = [notification object];

	DLog(@"VFM message received: %@", msg);
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)clearDelegates
{
    if ([[[VStore sharedVStore] pinPad] delegate] == self) {
        [[[VStore sharedVStore] pinPad] setDelegate:nil];
    }
    if ([[[VStore sharedVStore] barcode] delegate] == self) {
        [[[VStore sharedVStore] barcode] setDelegate:nil];
    }
    if ([[[VStore sharedVStore] payControl] delegate] == self) {
        [[[VStore sharedVStore] payControl] setDelegate:nil];
    }
    if ([[[VStore sharedVStore] zonTalk] delegate] == self) {
        [[[VStore sharedVStore] zonTalk] setDelegate:nil];
    }
}

- (void)viewDidUnload {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [self clearDelegates];
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
    [super viewDidUnload]; 
}


- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [self clearDelegates];
    
	[super dealloc];
}


//MARK: - Utils from Verifone sample code

// - - - - - - - - - 

-(NSString *) convertString:(NSString *)myString
{
	
	NSArray *myArray = [myString componentsSeparatedByString:@"!"];
	if ([myArray count] > 1) {
		NSMutableString *newString = [NSMutableString string];
		[newString appendString:[myArray objectAtIndex:0]];
		for (int y = 1; y < [myArray count]; y++) {
			
			NSString *field = [myArray objectAtIndex:y];
			
			unsigned int dec;
			NSString *hexString = [field substringToIndex:2] ;
			NSScanner *scan = [NSScanner scannerWithString:hexString];
			
			if ([scan scanHexInt:&dec]) {
				if (dec == 0) {
					[newString appendString:[NSString stringWithFormat:@"\x00%@",[field substringFromIndex:2]]];
				}
				else {
					char bytes[2];
					bytes[0] = 0;
					bytes[1] = dec;
					[newString appendString:[NSString stringWithFormat:@"%c%@",dec,[field substringFromIndex:2]]];
				}
				
				//DLog(@"Dec value, %d is sccessfully scanned.", dec);
			} else {
				[newString appendString:[NSString stringWithFormat:@"%@",[field substringFromIndex:2]]];
				//DLog(@"%@", @"No dec value is scanned.");
			}
			
			
		}
		
		myString = [[newString copy] autorelease];
	}
	//DLog(@"%@",myString);
	return myString;
	
}

//MArk: Action methods

- (IBAction)swipeButtonPushed 
{
	[waitSwipe startAnimating]; 

	[cardData setText: @""]; 
	
	// get card data
	int rc = [[[VStore sharedVStore] pinPad]	getCardData:10 language:VX600LanguageCodeUSA amount:5.00 otherAmount:0];
	NSString *myRC = [NSString stringWithFormat:@"%d", rc];

	[frameworkReturnCode setText:myRC]; 
	NSString *myTrack = [[[NSString alloc] initWithData:[[VStore sharedVStore] pinPad].vfiCardData.track2 encoding:NSASCIIStringEncoding] autorelease]; 

	[cardData setText: myTrack]; 

	DLog(@"%@", @"all done with swipe button");

	[waitSwipe stopAnimating]; 
	//[waitSwipe hidesWhenStopped];  // <-- original Verifone code, accomplishes nothing. BMonk
}

- (IBAction)keypadOnButtonPushed 
{	
	[waitSwipe startAnimating]; 

	DLog(@"%@", @"enable keypad");
	[[[VStore sharedVStore] payControl] keypadEnabled:YES] ;  
	
	[waitSwipe stopAnimating]; 
	//[waitSwipe hidesWhenStopped];  // <-- original Verifone code, accomplishes nothing. BMonk
	
}

- (IBAction)keypadOffButtonPushed 
{	
	[waitSwipe startAnimating]; 

	DLog(@"%@", @"disable keypad");
	[[[VStore sharedVStore] payControl] keypadEnabled:NO] ;  
	
	[waitSwipe stopAnimating]; 
	//[waitSwipe hidesWhenStopped];  // <-- original Verifone code, accomplishes nothing. BMonk

}

- (IBAction)msrOnButtonPushed 
{
	[waitSwipe startAnimating]; 

	
	[self disableMSR:NO];  

    
    // [[[VStore sharedVStore] pinPad]sendStringCommand:@"S20" calcLRC:YES ] ;  
    // s20 test... [[[VStore sharedVStore] pinPad] sendStringCommand:[NSString stringWithFormat:@"S20020%c598", 0x1c] calcLRC:YES]; 	 

    
	
	[waitSwipe stopAnimating]; 
	//[waitSwipe hidesWhenStopped];  // <-- original Verifone code, accomplishes nothing. BMonk
	
}

- (IBAction)msrOffButtonPushed 
{	
	[waitSwipe startAnimating]; 
	
	[self disableMSR:YES];  
	
	[waitSwipe stopAnimating]; 
	//[waitSwipe hidesWhenStopped];  // <-- original Verifone code, accomplishes nothing. BMonk
}

#if RunWithoutNeedlessTimers
- (void)quickDisableMSR
#else
- (void)quickDisableMSR:(NSTimer *)theTimer 
#endif
{
//    [[[VStore sharedVStore] pinPad] cancelCommand]; 
    [self disableMSR:YES];
}

- (IBAction)resetButtonPushed 
{
	@synchronized(self) {
		
        [[[VStore sharedVStore] pinPad] cancelCommand]; 
//        [[[VStore sharedVStore] pinPad] performBreak]; 
        
        // on reset, make sure msr is disabled. 
#if RunWithoutNeedlessTimers
        [self performSelector:@selector(quickDisableMSR) withObject:nil afterDelay:2.0];
#else
        self.myTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                   target:self
                                                 selector:@selector(quickDisableMSR:)
                                                 userInfo:nil
                                                  repeats:NO];
#endif
        
		
	}
}

- (IBAction)clearMiscText 
{	
	miscText.text = @""; 
    cardData.text = @"";
    frameworkReturnCode.text = @"";
    frameworkReturnCode2.text = @"";
}


// Why not make these statics into instance variables?
// Because there seems to be some sort of undocumented timing
// dependency in the Verifone initialization code. We have simply
// copied their code below rather than taking on the possibly lengthy
// task of refactoring it.
static int pkiHackForTesting = 0 ; 

static int myEncryptionType = EncryptionMode_NOE; 



- (void)startTheBackgroundJob 
{      
    //get your main thread and make it accessible if needed

//    dispatch_queue_t main = dispatch_get_main_queue();

    
//    dispatch_async(main, ^{
    
    
    DLog(@"%@", @"SALZOTHREAD:Enter Thread, call getCardData");
    
    int rc = [[[VStore sharedVStore] pinPad] getCardData:120 language:VX600LanguageCodeUSA amount:5.00 otherAmount:0];
    
    DLog(@"%@", @"DONE WITH GETCARDDATA\n"); 
    DLog(@"%@", @"SALZOTHREAD:after call to getCardData");
    
    // put up the return code.
    NSString *myRC = [NSString stringWithFormat:@"%d", rc];

    DLog(@"SALZOTHREAD:Set the RC:%@", myRC);

//thread    dispatch_async(main, ^{
        [frameworkReturnCode setText:myRC]; 
//thread    }); 

    DLog(@"%@", @"SALZOTHREAD:Pull track data");
    
    NSString *myTrack = [[[NSString alloc] initWithData:[[VStore sharedVStore] pinPad].vfiCardData.track2 encoding:NSASCIIStringEncoding] autorelease]; 
    NSString *myTrack1 = [[[NSString alloc] initWithData:[[VStore sharedVStore] pinPad].vfiCardData.track1 encoding:NSASCIIStringEncoding] autorelease]; 
    
    //thread     [miscText setText:[NSString stringWithFormat:@"%@\n%@", myTrack1, miscText.text]]; 
    
    // put up msr data
    //thread     [cardData setText:myTrack]; 
    
    // display a message
    DLog(@"%@", @"SALZOTHREAD:displaying 4 lines of text after swipe");
    [[[VStore sharedVStore] pinPad] displayMessages:@"Card" Line2:@"Data" Line3:@"entered" Line4:@"OK"]; 
   
    //thread     [self disableMSR:YES];  

    
    DLog(@"%@", @"SALZOTHREAD:all done with swipe button");
    
    DLog(@"%@", @"SALZOTHREAD:This is where your blocked code which will run simultaneously with the main thread will go");
    //The line below will perform an action on the main thread. useful for updating the UI
//thread    dispatch_async(main, ^{
        // [self updateMyUI];
        
        // disable msr.
        DLog(@"%@", @"SALZOTHREAD.main:disable msr");
        [self disableMSR:YES];  

        DLog(@"SALZOTHREAD.main:put up track 1[%@]", myTrack1);
        [miscText setText:[NSString stringWithFormat:@"%@\n%@", myTrack1, miscText.text]]; 
        
        // put up msr data
        DLog(@"SALZOTHREAD.main:put up track 2[%@]", myTrack);
        [cardData setText:myTrack]; 
//thread    });

    
    if (myEncryptionType == EncryptionMode_PKI) {

       // [[[VStore sharedVStore] pinPad]sendStringCommand:@"E06" calcLRC:YES ] ;  

        
        [[[VStore sharedVStore] pinPad] getPKICipheredData] ;  
        
            
        DLog(@"Encryption Type [%d], Keyid [%@], dataType [%d]", 
              [[VStore sharedVStore] pinPad].vfiCipheredData.encryptionType, 
              [[VStore sharedVStore] pinPad].vfiCipheredData.keyID, 
              [[VStore sharedVStore] pinPad].vfiCipheredData.dataType); 
        
        DLog(@"Blob1[%@]",[[VStore sharedVStore] pinPad].vfiCipheredData.encryptedBlob_1); 
        DLog(@"Blob2[%@]",[[VStore sharedVStore] pinPad].vfiCipheredData.encryptedBlob_2); 
        
        
        // -(EncryptionMode) getEncryptionMode;
//        [[[VStore sharedVStore] pinPad]sendStringCommand:@"E00" calcLRC:YES ] ;  

        
        
    }
    
    
    
    DLog(@"%@", @"SALZOTHREAD:exit thread");

//    });
}  


/*
-(void) c30Thread{
    [[[VStore sharedVStore] pinPad] C30:15 language:VX600LanguageCodeUSA amount:1.00 otherAmount:0];

    NSMutableString *str = [NSMutableString stringWithString:@"\nC30 No Amt\n"];
    [str appendFormat:@"Acct. #: %@\n",[[VStore sharedVStore] pinPad].vfiCardData.accountNumber];
    [str appendFormat:@"Expiry Date: %@\n",[[VStore sharedVStore] pinPad].vfiCardData.expiryDate];
//    [str appendFormat:@"Track 2 Hex: %@\n",[pinPad.vfiCardData.track2 description]];
//    [str appendFormat:@"Track 2 ASCII: %@\n",[[[NSString alloc] initWithData:pinPad.vfiCardData.track2 encoding:NSUTF8StringEncoding] autorelease] ];
 //   [str appendFormat:@"AID: %@\n",pinPad.vfiCardData.AID];
 //   [str appendFormat:@"App name: %@\n",pinPad.vfiCardData.appPreferredName];
 //   [str appendFormat:@"App label: %@\n",pinPad.vfiCardData.appLabel];
 //   [str appendFormat:@"Service Code: %i\n",pinPad.vfiCardData.serviceCode];
 //   [str appendFormat:@"Entry Type: %i\n",pinPad.vfiCardData.entryType];
 //   [str appendFormat:@"Cardholder Name: %@\n",pinPad.vfiCardData.cardHolderName];
 //   [str appendFormat:@"EMV Tags: \n%@\n",[pinPad.vfiCardData.emvTags description]];
    DLog(@"Data =\n%@",str);
}
*/

// The "MSR Entry" button
- (IBAction)combinedButtonPushed {
	
	[waitSwipe startAnimating];
    
	// clear msr data field. 
	DLog(@"%@", @"Calling C30 to Slide or Tap..."); 
	
    // enable msr.
	[self disableMSR:NO];  
    
	// get card data
	self.myAlert = [[VStore sharedVStore] showActivityIndicatorAlertWithMessage:@"Please Slide or Tap"];

    
// failed experiments: :)    
//thread - start threading code.    
// [NSThread detachNewThreadSelector:@selector(startTheBackgroundJob) toTarget:self withObject:nil];  
// [self startTheBackgroundJob]; 
// NSThread* t = [[NSThread alloc] initWithTarget:self selector:@selector(c30Thread) object:nil];
// [t start];
// DLog(@"%@", @"THREAD EXECUTED - C30 NO BLOCKING");


    
    // playing with doing this without waiting - change waitUntilDone to see it run without tying up the UI.
    
    [self performSelectorOnMainThread:@selector(startTheBackgroundJob) withObject:nil waitUntilDone:YES];

	[waitSwipe stopAnimating]; 
	//[waitSwipe hidesWhenStopped];  // <-- original Verifone code, accomplishes nothing. BMonk
	
	[self.myAlert dismissWithClickedButtonIndex:0 animated:YES];  
	self.myAlert = nil;
	
}

- (IBAction)s20ButtonPushed 
{	
	[waitSwipe startAnimating]; 
	
	
    DLog(@"%@", @"enable keypad");
	[[[VStore sharedVStore] payControl] keypadEnabled:YES] ;  
    
	DLog(@"%@", @"s16 manual key"); 
    
    
	// [[[VStore sharedVStore] pinPad] sendStringCommand:[NSString stringWithFormat:@"S20000%c598", 0x1c] calcLRC:YES]; 	 
	
//	[[[VStore sharedVStore] pinPad]S16:0];
	[[[VStore sharedVStore] pinPad]obtainCardData:0]; 

	
	// put up card number
    NSString *maskedAccountNumber = [[[[VStore sharedVStore] pinPad] vfiCardData] accountNumber];
	DLog(@"%@", maskedAccountNumber); 
	
	
	
	//DLog(@"put up rc, stop animation, all done.");
	//myRC = [NSString stringWithFormat:@"after Disp:%d", (int) rc];
	//[frameworkReturnCode2 setText:myRC]; 
	
	
	DLog(@"%@", @"all done with swipe button");

    DLog(@"%@", @"disable keypad");
	[[[VStore sharedVStore] payControl] keypadEnabled:NO] ;  

    
	[waitSwipe stopAnimating]; 
	//[waitSwipe hidesWhenStopped];  // <-- original Verifone code, accomplishes nothing. BMonk

}

int controlReceived;
- (void)myControlReceived {
	controlReceived = 1; 
}
- (void)myControlSent {
	controlReceived = 0; 
}

static NSString *lastPan = @""; 

#if RunWithoutNeedlessTimers
- (void)enterPinMethod 
#else
- (void)enterPinMethod:(NSTimer *)theTimer 
#endif
{
	
	
	//	[[[VStore sharedVStore] pinPad] noResponseNextCommand]; 
	//  [[[VStore sharedVStore] pinPad] sendStringCommand:[NSString stringWithFormat:@"Z2%cENTER PIN", 0x1A] calcLRC:YES]; 	 
	
	//	[[[VStore sharedVStore] pinPad] Z2: @"ENTER PIN" clearScreen: YES]; 
	
	//  	[NSThread sleepForTimeInterval:1.5]; 
	// 	[[[VStore sharedVStore] pinPad] sendStringCommand:[NSString stringWithFormat:@"Z60.5410096560196306"] calcLRC:YES]; 	
	
	//	[[[VStore sharedVStore] pinPad] Z60:@"5410096560196306"] ; 
	
    // [[[VStore sharedVStore] pinPad] sendStringCommand:[NSString stringWithFormat:@"Z62.5410096560196306%c0412NENTER PIN%c%cProcessing...", 0x1C, 0x1c, 0x1c] calcLRC:YES]; 	 
	//-(int) Z62:(NSString *)accountNumber minPIN:(int)min maxPIN:(int)max requirePIN:(BOOL)req firstMessage:(NSString*)msg1 secondMessage:(NSString*)msg2 processingMessage:(NSString*)procMsg ;
	
/*  
    [[[VStore sharedVStore] pinPad] S07:30 pin:60 balance:15];
    [[[VStore sharedVStore] pinPad] storeTimers:30 pin:60 balance:15];
    [[[VStore sharedVStore] pinPad] clearAllData];
    [[[VStore sharedVStore] pinPad] logEnabled:YES];
    [[[VStore sharedVStore] pinPad] consoleEnabled:YES];
    [[[VStore sharedVStore] pinPad] diagnosticInfo];

  */  
    
    
//    [[[VStore sharedVStore] payControl] keypadEnabled:YES] ;  
    
//	[[[VStore sharedVStore] payControl] keypadBeepEnabled:YES] ;  

    
    
    
	int pinRC = 
	[[[VStore sharedVStore] pinPad] Z62: lastPan minPIN:4 maxPIN:8 requirePIN:NO firstMessage:@"ENTER PIN" secondMessage:@"" processingMessage:@"Processing..."]; 
	
    DLog(@"%@", @"ENTER PIN IS UP");


  
	// [cardData setText: [NSString stringWithFormat:@"[%d]", pinRC] ];
	
	//int pbLength = [[[VStore sharedVStore] pinPad].vfiEncryptionData.pinBlock length]; - implicit conversion loses integer precision
    unsigned long pbLength = [[[VStore sharedVStore] pinPad].vfiEncryptionData.pinBlock length];
	
	if ((pinRC != 0) || (pbLength == 0)) {
		

		NSString *myPB = @"PIN test Fails:";  
		
		//	NSString *myPB = [[NSString alloc] initWithData:[[VStore sharedVStore] pinPad].vfiEncryptionData.pinBlock encoding:NSASCIIStringEncoding] autorelease]; 
		// 	myPB = [myPB stringByAppendingString:[[VStore sharedVStore] pinPad].vfiEncryptionData.serialNumber]; 
		myPB = [myPB stringByAppendingString:[NSString stringWithFormat:@"[%d]", pinRC]]; 
		
		[cardData setText: myPB ];

        [[[VStore sharedVStore] pinPad] cancelCommand]; 

		//[[[VStore sharedVStore] pinPad] noResponseNextCommand]; 
		//[[[VStore sharedVStore] pinPad] sendStringCommand:@"S00" calcLRC:YES]; 	
        
		[[[VStore sharedVStore] pinPad] displayMessages:@"PIN" Line2:@"Entry" Line3:@"Cancelled..." Line4:@""]; 
		
	} else {
		NSString *myPB = [[[NSString alloc] initWithData:[[VStore sharedVStore] pinPad].vfiEncryptionData.pinBlock encoding:NSASCIIStringEncoding] autorelease]; 
		myPB = [myPB stringByAppendingString:@"."]; 
		myPB = [myPB stringByAppendingString:[[VStore sharedVStore] pinPad].vfiEncryptionData.serialNumber]; 
		myPB = [myPB stringByAppendingString:[NSString stringWithFormat:@"[%d]", pinRC]]; 
		DLog(@"%@", myPB);
		
		[[[VStore sharedVStore] pinPad] displayMessages:@"" Line2:@"PIN" Line3:@"Entered" Line4:@"OK"]; 
		
		
	}
	
	
	[[[VStore sharedVStore] payControl] keypadEnabled:NO] ;  
	
	
	// bug in display message requires a wait!!!!!!! hopefully fixed soon.
	// [NSThread sleepForTimeInterval:1.5]; 
	
	[self.myAlert dismissWithClickedButtonIndex:0 animated:YES];  
	self.myAlert = nil;
	
	DLog(@"%@", @"all done with PIN entry");
	
	[waitSwipe stopAnimating]; 
	//[waitSwipe hidesWhenStopped];  // <-- original Verifone code, accomplishes nothing. BMonk
	
}	

BOOL doingBlob = NO; 
- (IBAction)blobButton 
{    
    doingBlob = YES; 
	
    self.myAlert2 = [[VStore sharedVStore] showAlertWithMessage:@"Downloading Pub Key\nPlease Wait..."];
    
    [[[VStore sharedVStore] pinPad] selectEncryptionMode:EncryptionMode_PKI];
    myEncryptionType = EncryptionMode_PKI; 
    
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
    
    [[[VStore sharedVStore] pinPad] E08_RSA:cert publicKeyID:certID];

    [[[VStore sharedVStore] pinPad] enableMSRDualTrack];
    
    [self.myAlert2 dismissWithClickedButtonIndex:0 animated:YES];  
    self.myAlert = nil;
    
    self.myAlert2 = [[VStore sharedVStore] showAlertWithMessage:@"Key Downloaded\nPlease Slide Card..."];
    
    
    
}

- (IBAction)enterPINButton 
{	
    DLog(@"%@", @"ENTER PIN IS REQUESTED");

	[[[VStore sharedVStore] payControl] keypadEnabled:YES] ;  
    
	[[[VStore sharedVStore] payControl] keypadBeepEnabled:YES] ;  
	
	[waitSwipe startAnimating]; 
	
	self.myAlert = [[VStore sharedVStore] showActivityIndicatorAlertWithMessage:@"Flip Over & Hand to Customer\nFor PIN Entry"];

	// clear msr data field. 
	[cardData setText: lastPan]; // Verifone issue: lastPan is never retained
	
	// 
	DLog(@"%@", @"z62 PIN"); 
	
/*	

 20110116 - Randy says: 
 
 Also, Z50 returns a string response that can be retrieved by calling-
	-(NSString *) copyStringResponse

	Z60 populates vfiEncryptedData.serialNumber and vfiEncryptedData.pinBlock
 
 <STX>Z62.4000000000006<FS>0412YMESSAGE 1<FS>
 MESSAGE 2<FS>PROCESSING MSG<ETX><LRC>
*/	
	
#if RunWithoutNeedlessTimers
    [self performSelector:@selector(enterPinMethod) withObject:nil afterDelay:0.3];
#else
	self.myTimer = [NSTimer scheduledTimerWithTimeInterval:0.3
											   target:self
											 selector:@selector(enterPinMethod:)
											 userInfo:nil
											  repeats:NO];
#endif
	
	
	
}


- (IBAction)Z50Button 
{
	[waitSwipe startAnimating]; 
	
	// clear msr data field. 
	[cardData setText: @""]; 
	
	DLog(@"%@", @"Set Config"); 
	
	
    // For Development:
    
/*    
    Production
    Development
  
 *APPOVERRIDE
    Remove from config
    0
 
 *OFF
    36000
    36000
 
 *STAYCONNECTED
    Remove from config
    1
 
 *KEEPALIVE
    Remove from config
    1
 
 *TURNON
    Remove from config
    1
 
 *XCDEBUG  ( DONT USE THIS - if removed, need 90% power for xc.  If not removed, 
             cannot charge via usb ) 
    Remove from config
    1
 
*/
    
    
    
	// Pass it a NSMutableArray with commands.
	
	// Example

	// This only works if zontalk is not instantiated... 
//	[cardData setText:@"Setting engine to 1"];

	NSMutableArray* arr = [NSMutableArray array];
//	[arr addObject:@"WELCMSG=\"Welcome 4.24ATT\""];
//	[arr addObject:@"DUKPTENGINE=1"];
//	[arr addObject:@"XPIDUKPTIDX=1"];
//	[arr addObject:@"XPIDUKPTIDIX=1"];
//  [arr addObject:@"DDLPORT=1"]; 
// 	[arr addObject:@"*APPOVERRIDE=1"];  <<< DO NOT DO THIS VIA THIS MEANS... 
//	[arr addObject:@"*OFF=18000"];		
//	[arr addObject:@"*POW=320000"];		
    [arr addObject:@"XPILOG=N"];
    [arr addObject:@"PROMPTO=15"];
    [arr addObject:@"DIGITO=15"];
    [arr addObject:@"BALTO=5"];
    [arr addObject:@"CBMODE=0"];
    [arr addObject:@"EMVDR=0"];
    [arr addObject:@"CHQ=A"];
    [arr addObject:@"SAV=B"];
    [arr addObject:@"EMVDS=0"];
    [arr addObject:@"CBAMT1=20"];
    [arr addObject:@"CBAMT2=40"];
    [arr addObject:@"CBAMT3=60"];
    [arr addObject:@"CBAMT4=100"];
    [arr addObject:@"EMVLANG=1"];
    [arr addObject:@"DEFLANG=E"];
    [arr addObject:@"SNREMOVE=0"];
    [arr addObject:@"SNPREFIX="];
    [arr addObject:@"BACKLITE=0"];
    [arr addObject:@"VISATTQ=\"B2C00000\""];
    [arr addObject:@"OPTFLAG=\"1000000000000000\""];
    [arr addObject:@"DEFLANG=E"];
    [arr addObject:@"SNREMOVE=0"];
    [arr addObject:@"SNPREFIX="];
    [arr addObject:@"BACKLITE=0"];
    [arr addObject:@"ENTRYMODE=1"];
    [arr addObject:@"XPILANGCNT=2"];
    [arr addObject:@"XPILANG0=ENGL"];
    [arr addObject:@"XPILANG1=FREN"];
    [arr addObject:@"DUKPTENGINE=1"];
    [arr addObject:@"XPIDUKPTIDX=0"];
    [arr addObject:@"XPIDUKPTIDIX=0"];
    [arr addObject:@"XPIENCRPT=\"DUKPT\""];
    [arr addObject:@"BAUDRATE=9600"];
    [arr addObject:@"FORMAT=8N1"];
    [arr addObject:@"COMMPORT=1"];
    [arr addObject:@"DDLPORT=1"];
    [arr addObject:@"URLHOST="];
    [arr addObject:@"PORT="];
    [arr addObject:@"SSL=1"];
    [arr addObject:@"WELCMSG=\"Welcome xxxxxxxxx\""];
    [arr addObject:@"COUNTRY=\"US\""];
    [arr addObject:@"*APPOVERRIDE=0"];
    [arr addObject:@"*OFF=32000"];
    [arr addObject:@"VXCILOG=C"];
    [arr addObject:@"VXCI_PORT=CTLS"];
	
	
	
	
	[[[VStore sharedVStore] pinPad] setParameterArray: arr];
	
	DLog(@"%@", @"all done with config");
	
	[waitSwipe stopAnimating]; 
	//[waitSwipe hidesWhenStopped];  // <-- original Verifone code, accomplishes nothing. BMonk	
}



- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    //	printf("User Pressed Button %d\n", buttonIndex + 1);
    
    if (buttonIndex != 0)  // 0 == the cancel button
    {
        //  Since we don't have a pointer to the textfield, we're
        //  going to need to traverse the subviews to find our 
        //  UITextField in the hierarchy
        for (UIView* view in alertView.subviews)
        {
            if ([view isKindOfClass:[UITextField class]])
            {
                UITextField* textField = (UITextField*)view;
                NSString *myURL = textField.text;
                DLog(@"text:[%@]", textField.text);
                [cardData setText: myURL]; 
                DLog(@"%@", @"Load XPI"); 
                
                [self turnOffBatteryPolling] ; 
                
                [[[VStore sharedVStore] pinPad] updateFromUrl:myURL];
                //	[[[VStore sharedVStore] pinPad] updateFromUrl:@"http://salzo.com/OS110117.zip"];
                
                
                
                DLog(@"%@", @"all done with load");
                
                
                
                break;
            }
        }
    }
    
    
    [waitSwipe stopAnimating]; 
	//[waitSwipe hidesWhenStopped];  // <-- original Verifone code, accomplishes nothing. BMonk
    
    //    [alertView release];
}




- (IBAction)loadStuffButton 
{
	[waitSwipe startAnimating]; 	
	
	// clear msr data field. 
	[cardData setText: @""]; 
	
	DLog(@"%@", @"Load OS"); 
    
    // no sleep or lock allowed!!
    
    UIApplication* myApp = [UIApplication sharedApplication];
    myApp.idleTimerDisabled = YES;
    
    //
    
    UIAlertView *alert = [[[UIAlertView alloc] 
						  initWithTitle: @"Enter File Location" 
						  message:@"Specify the URL"
						  delegate:self
						  cancelButtonTitle:@"Cancel"
						  otherButtonTitles:@"OK", nil] autorelease];
    
    
    
    UITextField *txtName; 
    txtName = [[[UITextField alloc] initWithFrame:CGRectMake(12.0, 45.0, 260.0, 25.0)] autorelease];
    [txtName setText:@"http://salzo.com/..."]; 
	txtName.keyboardType = UIKeyboardTypeURL; 
    [txtName setBackgroundColor:[UIColor whiteColor]];
    [txtName setKeyboardAppearance:UIKeyboardAppearanceAlert];
    [txtName setAutocorrectionType:UITextAutocorrectionTypeNo];
    
    //[txtName setTextAlignment:UITextAlignmentCenter]; - deprecated in iOS 6.0
    [txtName setTextAlignment:NSTextAlignmentCenter];
    
    
    [alert addSubview:txtName] ; 
    
    [alert show];
    
	
    //	[[[VStore sharedVStore] pinPad] updateFromUrl:@"http://salzo.com/UPDATEOS.zip"];
    //	[[[VStore sharedVStore] pinPad] updateFromUrl:@"http://salzo.com/OS110117.zip"];
    
	
	DLog(@"%@", @"all done with load");
	
//	[waitSwipe stopAnimating]; 
	//[waitSwipe hidesWhenStopped];  // <-- original Verifone code, accomplishes nothing. BMonk
	
	
	
}


-(IBAction) pkiButton {
    
    [[[VStore sharedVStore] pinPad] selectEncryptionMode:EncryptionMode_PKI];
    myEncryptionType = EncryptionMode_PKI; 

/*NSString *certData1 = @"-----BEGIN PUBLIC KEY-----\n";
NSString *certData2 = @"MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArzv85D/wj1UTJxqxz5zA\n";
NSString *certData3 = @"x1TaiAckTvFiqavYfOgjq33cj6C8E8yvIfC7Awpj8Aa3Bejo8CeSfBhnA1bIkxE/\n";
NSString *certData4 = @"ffKcSr99NDPfWgyP5wA0D/4w/MnBFRXZXoBsoM030eQD1PmbYRiPgNWn3BmaK1cC\n";
NSString *certData5 = @"wbyeKo8JCvBbQlqezdyJHz5rXbYBykgVo4Y1nGhvo/00ycJq7nI2Slzf8xUqUDrS\n";
NSString *certData6 = @"buETXSDtm5zrfmjWaXvbcE6z2MC44JWUQeTysRBFkRehN1OJ3A4I0WEEp7XyKxhe\n";
NSString *certData7 = @"WQ/PygdqHE09OIu75bgWH7bZenTvrREvfUOchjo29rZ4ZfOK+J+putW3dDNohPAm\n";
NSString *certData8 = @"JQIDAQAB\n";
NSString *certData9 = @"-----END PUBLIC KEY-----\n";
*/    
    
        
NSString *certData1 = @"-----BEGIN PUBLIC KEY-----\n";
NSString *certData2 = @"MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvP/0yAKVnQSFCI62InvG\n";
NSString *certData3 = @"ufApPVKWtHd9wEW6cVSLyWnKEeRqWxqtiUIiXNrr1bxXa/G3RgMejb+dPHDFI4pK\n";
NSString *certData4 = @"8aomxjXxmb5ghq2beFSddWDamrmkLnwONvw950ESgaiDlttsj+CBnerEMW+AhmVB\n";
NSString *certData5 = @"kNlZH85Wuy2ZfN5sA/oU6Y+4kD0m4NKDZLEML0xA4o6YnlBu7dsENJq2IupkPBzH\n";
NSString *certData6 = @"L+fx2H6FOTe2oy0v3lJbDlDptnArYLw62sjkbkkm5zbHgKo84h2IgYmVOP+oKq3S\n";
NSString *certData7 = @"wEJn8jmEkg+rp2zVL+acmqd13YUF0q2uLl264kq51Duws60b0CaLYQmQ7rorWlYH\n";
NSString *certData8 = @"bQIDAQAB\n";
NSString *certData9 = @"-----END PUBLIC KEY-----\n";
    
    pkiHackForTesting++; 
    
    if (pkiHackForTesting == 10) {
        
        //    NSString *cert = [NSString stringWithFormat:@"-----BEGIN PUBLIC KEY-----%c%@%@%@%@%@%@%@%c-----END PUBLIC KEY-----",0x0a,certData1,certData2,certData3,certData4,certData5,certData6,certData7,0x0a]; 
        //    NSString *certID = @"114434";
        
        NSString *cert = [NSString stringWithFormat:@"%@%@%@%@%@%@%@%@%@",certData1,certData2,certData3,certData4,certData5,certData6,certData7,certData8,certData9]; 
        NSString *certID = @"114435";
        
        [[[VStore sharedVStore] pinPad] E08_RSA:cert publicKeyID:certID];
    }

     
}

- (IBAction)vspButton {
    
    [[[VStore sharedVStore] pinPad] selectEncryptionMode:EncryptionMode_VSP];
    myEncryptionType = EncryptionMode_VSP; 
    
}

- (IBAction)loadXPIButton {
	
	
	[waitSwipe startAnimating]; 	
	
	// clear msr data field. 
	[cardData setText: @""]; 
	
    
    UIAlertView *alert = [[[UIAlertView alloc] 
						  initWithTitle: @"Enter File Location" 
						  message:@"Specify the URL"
						  delegate:self
						  cancelButtonTitle:@"Cancel"
						  otherButtonTitles:@"OK", nil] autorelease];
	   
    
    
    UITextField *txtName; 
    txtName = [[[UITextField alloc] initWithFrame:CGRectMake(12.0, 45.0, 260.0, 25.0)] autorelease];
    [txtName setText:@"http://salzo.com/..."]; 
	txtName.keyboardType = UIKeyboardTypeURL; 
    [txtName setBackgroundColor:[UIColor whiteColor]];
    [txtName setKeyboardAppearance:UIKeyboardAppearanceAlert];
    [txtName setAutocorrectionType:UITextAutocorrectionTypeNo];
    
    //[txtName setTextAlignment:UITextAlignmentCenter]; - deprecated in iOS 6.0
    [txtName setTextAlignment:NSTextAlignmentCenter];
    
    
    
//	tf.clearButtonMode = UITextFieldViewModeWhileEditing;
//	tf.keyboardType = UIKeyboardTypeURL;
//	tf.keyboardAppearance = UIKeyboardAppearanceAlert;
//	tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
//	tf.autocorrectionType = UITextAutocorrectionTypeNo;
    
    [alert addSubview:txtName] ; 
    
    [alert show];
	
}

//MARK: VFIPinpadDelegate

- (void) pinpadDownloadInfo:(NSString*)log{
	
	[cardData setText:log];
	[miscText setText:[NSString stringWithFormat:@"%@\n%@", log, miscText.text]]; 
}

- (void) pinpadDownloadBlocks:(int)TotalBlocks sent:(int)BlocksSent{
	NSString *myBlocks; 
	myBlocks = [NSString stringWithFormat:@"%i sent of %i total blocks.",BlocksSent,TotalBlocks];
	[cardData setText:myBlocks];
	// [miscText setText:[NSString stringWithFormat:@"%@\n%@", myBlocks, miscText.text]]; 

	
}


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


- (BOOL)setPublicKey
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

#else

    NSString *cert = [[SCServerPublicKeyDownloadController sharedController] publicKey];
    NSString *certID = [[SCServerPublicKeyDownloadController sharedController] publicKeyID];
#endif
    if (isEmptyString(cert)) {
        DLog(@"%@", @"Error: pin pad public key is empty");
        SPLog(@"Error: pin pad public key is empty");
    }

    [[[VStore sharedVStore] pinPad] selectEncryptionMode:EncryptionMode_PKI];

    [[[VStore sharedVStore] pinPad] E08_RSA:cert publicKeyID:certID];

    EncryptionMode mode = [[[VStore sharedVStore] pinPad] getEncryptionMode];
    DLog(@"pinpad reports its encryption mode is now:%@", [self nameForEncryptionTypeCode:mode]);
    SPLog(@"pin pad reports encryption mode is now:%@", [self nameForEncryptionTypeCode:mode]);

    return isEmptyString(cert);
}


//Monitors connect/disconnect events from [[VStore sharedVStore] pinPad]
- (void)pinpadConnected:(BOOL)isConnected
{
     SPLog(@"pinpad Connected: %@", isConnected ? @"YES" : @"NO");
        DLog(@"delegate received pinpadConnected: %@", isConnected ? @"YES" : @"NO");

        if (isConnected) {
            NSLog(@"\n\n\nEnable Card Scanner\n\n");
#if 1 // added: simplifying assumption for testing
            [[VStore sharedVStore] enableCardScanner:YES];
            [self setPublicKey];
            
#else // existing line
            [[VStore sharedVStore] enableCardScanner:NO];
#endif
        }

	static BOOL needInit = NO;
	
    DLog(@"PPC:BC/PP/CTL - C:%d/%d/%d  I:%d/%d/%d\n",  
                       ([[VStore sharedVStore] barcode].connected), 
                       ([[VStore sharedVStore] pinPad].connected),                        
                       ([[VStore sharedVStore] payControl].connected), 
                       ([[VStore sharedVStore] barcode].initialized),                        
                       ([[VStore sharedVStore] pinPad].initialized), 
                       ([[VStore sharedVStore] payControl].initialized)); 

		if (isConnected) {
			UIImage *greenImage = [UIImage imageNamed:@"1287153228_Circle_Green.png"];
			UIImage *greenButtonImage = [greenImage stretchableImageWithLeftCapWidth:0 topCapHeight:0];
			[connectButton setImage:greenButtonImage forState:UIControlStateNormal];

        
			needInit = NO; 
            

            // TEST INIT/NOT INIT LOGIC
            [pinpadNotReady setHidden: YES];


			
		}else {

			needInit = YES; 
            
            // TEST INIT/NOT INIT LOGIC
            [pinpadNotReady setHidden: NO];

            //myInitStarted = NO; 
            //myInitDone = NO; 

            
            
		}
		

}


- (void) pinpadSerialData:(NSData *)data incoming:(BOOL)isIncoming {
	
	
}


//Monitors data being received from the [VStore sharedVStore] pinPad
- (void) pinpadDataReceived:(NSData*)data{
	
    NSString *myData = [[VStore sharedVStore] nsdataToNSString:data]; 
    
    if ([myData length] >= 2) {
        if ([[myData substringToIndex:2] isEqualToString:@"06"]) {
        } else {
        // DLog(@"PPRECV: %@", [[VStore sharedVStore] nsdataToNSString:data]);
        DLog(@"PPRECV: %@", [[VStore sharedVStore] hexToString:[[VStore sharedVStore] nsdataToNSString:data]]);
            
            
        }
    }
}


//Monitors data being sent
- (void) pinpadDataSent:(NSData*)data{
	
    NSString *myData = [[VStore sharedVStore] nsdataToNSString:data]; 
    
    if ([myData length] >= 2) {
        
        if ([[myData substringToIndex:2] isEqualToString:@"06"]) {
        } else {
        // DLog(@"PPSEND: %@", [[VStore sharedVStore] nsdataToNSString:data]);
        DLog(@"PPSEND: %@", [[VStore sharedVStore] hexToString:[[VStore sharedVStore] nsdataToNSString:data]]);
                    
        }
    }
}

- (void) pinpadLogEntry:(NSString *)logEntry withSeverity:(int)severity{
	
	DLog(@"ppLogEntry: %@", logEntry);
	
	
	
}

- (void) pinpadMSRData:(NSString*)pan  expMonth:(NSString*)month  expYear:(NSString*)year  trackData:(NSString*)track2 {
    
    dispatch_queue_t main = dispatch_get_main_queue();
    dispatch_async(main, ^{
                
        // put up msr data
        DLog(@"PAN - year - month:%@=%@%@", pan, year, month); 
        
    });
    
    
    lastPan = [NSString stringWithFormat:@"%@", pan]; // Monk: Verifone bug here: needless format does nothing; no retain loses lastPan
    
    if (myEncryptionType == EncryptionMode_PKI) {
        
        [[[VStore sharedVStore] pinPad] getPKICipheredData];  
        
        dispatch_async(main, ^{ // unnecessary; setting text sets needsDisplay but doesn't actually do anything with the UI directly
            
#if 0
            [miscText setText:[NSString stringWithFormat:@"Encryption Type [%d], Keyid [%@], dataType [%d]\n%@", 
                               [[VStore sharedVStore] pinPad].vfiCipheredData.encryptionType, 
                               [[VStore sharedVStore] pinPad].vfiCipheredData.keyID, 
                               [[VStore sharedVStore] pinPad].vfiCipheredData.dataType, 
                               miscText.text]];
            
            [miscText setText:[NSString stringWithFormat:@"Blob1[%@]\n%@", 
                               [[VStore sharedVStore] pinPad].vfiCipheredData.encryptedBlob_1,
                               miscText.text]]; 
            
            [miscText setText:[NSString stringWithFormat:@"Blob2[%@]\n%@", 
                               [[VStore sharedVStore] pinPad].vfiCipheredData.encryptedBlob_2,
                               miscText.text]]; 
#endif
            
        });
        
        DLog(@"Encryption Type [%d], Keyid [%@], dataType [%d]", 
              [[VStore sharedVStore] pinPad].vfiCipheredData.encryptionType, 
              [[VStore sharedVStore] pinPad].vfiCipheredData.keyID, 
              [[VStore sharedVStore] pinPad].vfiCipheredData.dataType); 
        
        DLog(@"Blob1[%@]",[[VStore sharedVStore] pinPad].vfiCipheredData.encryptedBlob_1); 
        DLog(@"Blob2[%@]",[[VStore sharedVStore] pinPad].vfiCipheredData.encryptedBlob_2); 
        
        if (doingBlob) {
            doingBlob = NO; 
            
            [self.myAlert2 dismissWithClickedButtonIndex:0 animated:YES];  
            self.myAlert2 = nil;
            
            self.myAlert2 = [[VStore sharedVStore] showAlertWithMessage:@"Generating Blob File...\nPlease Wait..."];
            
            
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths objectAtIndex:0];
            
            NSString *foofile = [documentsDirectory stringByAppendingPathComponent:                         
                                 [NSString stringWithFormat:@"%@", @"lastBlob.out" ]];
            
            
            NSString *fred = [NSString stringWithFormat:@"%@", [[VStore sharedVStore] pinPad].vfiCipheredData.encryptedBlob_1]; 
            //int fredL = [[VStore sharedVStore] pinPad].vfiCipheredData.encryptedBlob_1.length; - implicit conversion loses integer precision
            unsigned long fredL = [[VStore sharedVStore] pinPad].vfiCipheredData.encryptedBlob_1.length;
            NSString *fred16 = @"";
            int ii; 
            for (ii = 0; ii < fredL; ii+=16) {
                // grab 16 bytes and append \n 
                
                // DLog([@"1234567890" substringWithRange:NSMakeRange(ii, 16)]);
                
                if ((ii+16) > fredL) {
                    
                    fred16 = [NSString stringWithFormat:@"%@%@\n", fred16, [fred substringWithRange:NSMakeRange(ii, (fredL - ii))]]; 
                    
                    
                } else {
                    
                    //  NSString *spud = [fred substringWithRange:NSMakeRange(ii, 16)]; 
                    
                    fred16 = [NSString stringWithFormat:@"%@%@\n", fred16, [fred substringWithRange:NSMakeRange(ii, 16)]]; 
                    
                    //                                                                       [string substringWithRange: NSMakeRange(3, 6)]
                    
                }
                
                
            }
            
            [fred16 writeToFile:foofile atomically:YES encoding:NSUTF8StringEncoding error:nil];
            
            [self.myAlert2 dismissWithClickedButtonIndex:0 animated:YES];  
            self.myAlert2 = nil;
            
        }
        
        
    }
    
}

- (void) pinpadMSRData:(NSString*)pan  expMonth:(NSString*)month  expYear:(NSString*)year  track1Data:(NSString*)track1  track2Data:(NSString*)track2 {
    
    lastPan = [NSString stringWithFormat:@"%@", pan]; // BMonk: this Verifone code is useless since lastPan not retained
            
    DLog(@"Card Data: %@/%@/%@/%@/%@\n", track1, track2, pan, year, month); 
    
}


//MARK: VFIControlDelegate

- (void) controlConnected:(BOOL)isConnected {
    DLog(@"controlConnected:%d", isConnected);
	
}


//Monitors data being received from the [VStore sharedVStore] pinPad
- (void) controlDataReceived:(NSData*)data{
	
	// [self displayInfo:data iPhone:NO];
	
    NSString *myData = [[VStore sharedVStore] nsdataToNSString:data]; 
    
    if ([myData length] >= 2) {
        
        if ([[myData substringToIndex:2] isEqualToString:@"06"]) {
        } else {
            // DLog(@"LCRECV: %@", [[VStore sharedVStore] nsdataToNSString:data]);
            DLog(@"LCRECV: %@", [[VStore sharedVStore] hexToString:[[VStore sharedVStore] nsdataToNSString:data]]);
            // [miscText setText:[NSString stringWithFormat:@"CRECV: %@\n%@", [[VStore sharedVStore] nsdataToNSString:data], miscText.text]]; 
        }
    }

	[self myControlReceived];
	
}


//Monitors data being sent
- (void) controlDataSent:(NSData*)data{
	
	// DLog(@"CSEND: %@", [[VStore sharedVStore] nsdataToNSString:data]);
	DLog(@"CSEND: %@", [[VStore sharedVStore] hexToString:[[VStore sharedVStore] nsdataToNSString:data]]);
// 	[miscText setText:[NSString stringWithFormat:@"CSEND: %@\n%@", [[VStore sharedVStore] nsdataToNSString:data], miscText.text]]; 
	
}

- (void) controlLogEntry:(NSString*)logEntry withSeverity:(int)severity {
    DLog(@"controlLogEntry: %@", logEntry);
    
}

//MARK: UIAccelerometerDelegate

- (void)accelerometer :(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration 
{ 
#define kFilteringFactor			0.1
    
	//Use a basic low-pass filter to only keep the gravity in the accelerometer values
	_accelerometerFilter[0] = acceleration.x * kFilteringFactor + _accelerometerFilter[0] * (1.0 - kFilteringFactor);
	_accelerometerFilter[1] = acceleration.y * kFilteringFactor + _accelerometerFilter[1] * (1.0 - kFilteringFactor);
	_accelerometerFilter[2] = acceleration.z * kFilteringFactor + _accelerometerFilter[2] * (1.0 - kFilteringFactor);

	if (_accelerometerFilter[2] > kAccelerationThreshold) {
    //if (acceleration.z > kAccelerationThreshold) {
		[hideUnHide setHidden: NO];
		[[VStore sharedVStore] setUpsideDown: YES]; 
	}else{
		[hideUnHide setHidden: YES];
		[[VStore sharedVStore] setUpsideDown: NO]; 
	}
	
}

//MARK: VerifoneBarcodeDidReceiveDataNotification
- (void)barcodeDidReceiveData:(NSNotification *)note
{
	SPLog(@"diagnostics view received barcode data");

	NSDictionary *userInfo = [note userInfo];
	
	NSString *barcodeDataAsString = [userInfo objectForKey:BarcodeDataAsStringKey];
	
	// Append string to log
	DLog(@"BCRECV: %@\n", barcodeDataAsString); 
}

//MARK: VFIBarcodeDelegate
#ifdef UNUSED // VFIBarcodeDelegate methods are now handled by VFIBarcodeDelegate.m
- (void) barcodeConnected:(BOOL)isConnected {
    SPLog(@"barcodeConnected : %@", isConnected ? @"Yes" : @"No");
    
    DLog(@"barcodeConnected: %d", isConnected);
}

- (void) barcodeDataReceived:(NSData*)data {
    NSString *myData = [[VStore sharedVStore] nsdataToNSString:data]; 
    
    if ([myData length] >= 2) if ([[myData substringToIndex:2] isEqualToString:@"06"]) {
    } else {
        DLog(@"BCRECV: %@\n", [[VStore sharedVStore] nsdataToNSString:data]); 
    }
}

- (void) barcodeDataSent:(NSData*)data {
	DLog(@"BCSEND: %@\n", [[VStore sharedVStore] nsdataToNSString:data]); 
}

- (void) barcodeScanData:(NSData*)data barcodeType:(int)thetype{
    DLog(@"barcodeScanData: %@", [data description]);
}

- (void) barcodeLogEntry:(NSString*)logEntry withSeverity:(int)severity {
    DLog(@"barcodeLogEntry: %@", logEntry);
}

- (void) barcodeTriggerEvent:(int)triggerCode {
    
    DLog(@"barcodeTriggerEvent: %d", triggerCode);
}
#endif

@end
