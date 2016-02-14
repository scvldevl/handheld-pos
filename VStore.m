//
//  VStore.m
//
// Based on:
//  pwmg2Sandbox by Thomas Salzmann on 10/27/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//
//  Altered for Shoe Carnival by BMonk/BigNerdRanch 2012
//

#import "VStore.h"
#import "SC_VX600_LCDMessageDisplayQueue.h"

// currently unused
#import "VFIPinPadDelegate.h"
#import "VFIBarcodeDelegate.h"

#import "EAAccessoryManager+Utils.h"

// Verifone Notifications
NSString *ConnectVX600Notification = @"ConnectVX600";

@interface VStore ()
@end
    
@implementation VStore

@synthesize pinPad, barcode, payControl, zonTalk;
@synthesize pinPadDelegate, barcodeDelegate;

- (void)displayInitCompleteLCDMessage
{
    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    appVersionString = [NSString stringWithFormat:@"v%@", appVersionString];
    
#if 0
    [[self pinPad] displayMessages:@"SHOE CARNIVAL"
                             Line2:@"iOS Client"
                             Line3:appVersionString
                             Line4:@"INIT COMPLETE"];
#else
    [[VStore sharedVStore] displayLCDMessage:@"SHOE CARNIVAL"
                                       line2:@"iOS Client"
                                       line3:appVersionString
                                       line4:@"INIT COMPLETE"
                                  forSeconds:-1];
#endif
}

- (void)intializeConnectedPinPad
{
    //[pinPad enableMSR];           // now controlled by SC server (also we aren't using this method now)
    //[pinPad enableMSRDualTrack]; // tell device to accept a card swipe at any time
    
    [pinPad setFrameworkTimeout:120];   // ENTER PIN timeout old way. // <-- original veriophone comments
    [pinPad setPINTimeout:70];          // ENTER PIN timeout 
    [pinPad setAccountEntryTimeout:120]; 
    [pinPad setPromptTimeout:70]; 
    [pinPad setACKTimeout:3.0];  
    
    [pinPad setKSN20Char:YES];          // no idea what this does; it was in Verifone sample code, but is not in the docs

    [self displayInitCompleteLCDMessage];
}

- (void)logDiagnostics
{
    DLog(@"frameworkVersion:%@\n osversion:%@\n xpiVersion:%@\n xpiVersion:%@\n emvVersion:%@\n ctlsReaderFirmwareVersion:%@\nvspVersion: %@\n pinpadSerialNumber:%@\n",
        pinPad.frameworkVersion,
        pinPad.vfiDiagnostics.osversion,
        pinPad.vfiDiagnostics.xpiVersion,
        pinPad.vfiDiagnostics.xpiVersion,
        pinPad.vfiDiagnostics.emvVersion,
        pinPad.vfiDiagnostics.ctlsReaderFirmwareVersion,
        pinPad.vfiDiagnostics.vspVersion,
        pinPad.vfiDiagnostics.pinpadSerialNumber);
}
 
//MARK: -
         
- (void)initializeConnectedBarcode
{
    // Set barcode trigger mode
    // Following notes are from Verifone sample code
    /* notes on modes from Wil: (modes might be reversed here)
     
     Edge mode is barcode stuff:
     
     Edge mode: you just need to click the trigger and the light stays on until timeout (or successful scan if single scan is on)
     
     Level mode:  Hold the trigger to keep the light on
     
     Single Scan:  Light turns off after recognizing a bar scan
     
     Multi Scan: Light stays on after recognizing a bar scan
     
     */
    

    [barcode setLevel];	// hold down barcode trigger to scan aka "soft mode"
    
    
    //[barcode setEdge]; // if used, a single barcode trigger press keeps light on until timeout (or successful scan if single scan is on)

    
    [[[VStore sharedVStore] barcode] setScanner2D]; 	
	[[[VStore sharedVStore] barcode] setScanTimeout:5000]; 
	[[[VStore sharedVStore] barcode] includeAllBarcodeTypes]; 
	[[[VStore sharedVStore] barcode] barcodeTypeEnabled:YES]; 
    
	[[VStore sharedVStore] barcodeScanOff]; 
	//[[[VStore sharedVStore] barcode] logEnabled:YES];
}

//

- (void)initializeConnectedPayControl
{
}

#define kUseZontalk (0) // zontalk not needed not needed for now

- (void)initializeConnectedZonTalk
{
}

//MARK:

- (void)enablePassthroughXCodeDebugging:(BOOL)flag
{
    // From Tom Salzmann; enables Xcode via the sled's passthrough mini-USB port (you'll need an
    // appropriate cable...), but will also drain battery (and requires - hostPowerEnabled:NO also be set)
    if (flag) {

        NSArray* arr = [NSArray arrayWithObjects:@"*APPOVERRIDE=0",
                        @"*STAYCONNECTED=1",
                        @"*KEEPALIVE=1",
                        @"*XCDEBUG=",
                        @"*POWERSHARE=30",
                        @"*CHARGEHOST=30", 
                        nil];
        [[[VStore sharedVStore] pinPad] setParameterArray:(NSMutableArray *)arr]; 
    } else {
        //Disable Xcode debugging:
        
        NSArray* arr = [NSArray arrayWithObjects:@"*APPOVERRIDE=0",
                        @"*APPOVERRIDE=0",
                        @"*STAYCONNECTED=1",
                        @"*KEEPALIVE=1",
                        @"*XCDEBUG=",
                        @"*POWERSHARE=100",
                        @"*CHARGEHOST=98", 
                        nil];
        [[[VStore sharedVStore] pinPad] setParameterArray:(NSMutableArray *)arr]; 
    }
    DLog(@"Setting passthroughXCodeDebug to:%d", flag);
}

//MARK: 

- (void)displayLCDMessage:(NSString *)line1
                    line2:(NSString *)line2
                    line3:(NSString *)line3
                    line4:(NSString *)line4 forSeconds:(NSInteger)displaySeconds
{
    [[SC_VX600_LCDMessageDisplayQueue sharedQueue] displayVX600LCDMessage:line1
                                                                    line2:line2
                                                                    line3:line3
                                                                    line4:line4
                                                               forSeconds:displaySeconds];
}

//MARK: -

static VStore *sharedVStore = nil;
+ (VStore *)sharedVStore
{
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{ 
        sharedVStore = [[self alloc] init];
    });
    return sharedVStore;
}

- (id)init
{
	if (sharedVStore != nil) {
		DLog(@"%@", @"Please use [VStore sharedVStore], not alloc/init");
		return sharedVStore;
	}
	
    self = [super init];
    if (self) {
        DLog(@"%@", @"init VStore");
        
#define kUseSeparateVerifoneDelegateObjects (0)
        // The Verifone sample code is quite intertwined with its UI code.
        // Would like to decouple all the Verifone delegate methods from
        // our UI code.
        // VFIPinPadDelegate and the others below are for this purpose.
        // Unfortunately there seems to be timing dependencies when
        // init the various VX sub-devices. Using the code below doesn't
        // work, yet doing the init interspersed with UI code etc, does.
        // So in the interest of expediency, we are doing it the latter way for now.
        
        // these delegate setups and initializations
        // now happen in VNCViewController because of weird Verifone timing issue
        // We just alloc/init the objects here.

        pinPad = [[VFIPinpad alloc] init];
#if kUseSeparateVerifoneDelegateObjects
        pinPadDelegate = [[VFIPinPadDelegate alloc] init];
        [pinPad setDelegate:pinPadDelegate];
        [pinPad initDevice];
#endif
        
        
        barcode = [[VFIBarcode alloc] init];
#if kUseSeparateVerifoneDelegateObjects
        barcodeDelegate = [[VFIBarcodeDelegate alloc] init];
        [barcode setDelegate:barcodeDelegate];
        [barcode initDevice];
#endif
    
        
        payControl = [[VFIControl alloc] init];
#if kUseSeparateVerifoneDelegateObjects
        [payControl setDelegate:self];
        [payControl initDevice];
#endif

#if kUseZontalk
        zonTalk = [[VFIZontalk alloc] init];
        [zonTalk setDelegate:self];
#endif


    }
    return self;
}

// VStore is a singleton which exists for the life of the application, so dealloc usually will never be called
- (void)dealloc
{
    [pinPad setDelegate:nil];
    [pinPad closeDevice];
    [pinPad release];
    [pinPadDelegate release];
    
    [barcode setDelegate:nil];
    [barcode closeDevice];
    [barcode release];
    [barcodeDelegate release];
    
    [payControl setDelegate:nil];
    [payControl closeDevice];
    [payControl release];
    
#if kUseZontalk
    [zonTalk setDelegate:nil];
    [zonTalk closeDevice];
    [zonTalk release];
#endif
    
    [super dealloc];
}

//MARK: - Verifone barcode Utils

- (void) barcodeScanOn
{
	[barcode startScan];
	barcodeEnabled = YES; 
}

- (void) barcodeScanOff 
{    
    [barcode abortScan]; 
    barcodeEnabled = NO; 
}

- (void) scanOnAfterSleeping  
{
    @synchronized(self) {
        DLog(@"ScanOnAfterSleep: connected:%d initialized:%d", (barcode.connected), (barcode.initialized))                        ;
        [barcode startScan]; 
    }
}

- (void) barcodeScanOnAfterSleeping 
{
	[self performSelector:@selector(scanOnAfterSleeping) withObject:nil afterDelay:0.25]; // delay time from original Verifone sample code
	//FIXME: should replace with perform selector. BMonk
}

- (void) barcodeScanOffWhileSleeping 
{    
    if (barcodeEnabled) {     
        [barcode abortScan]; 
    }
    
}

//MARK: Verifone pinpad utils

// NOTE: The commented-out code below is from original Verifone sample - BMonk. Other than some documentation with /**/ not known if/what purpose this code served

/* CRITICAL - Because of VSP track encryption, MSR MUST REMAIN ENABLED BETWEEN CARD SWIPE AND
 The prompt for ENTER PIN!!!!!!!!!!!  Disabling card swipe will cause the VCL buffer to be
 cleared and the ultimate PIN decryption by HSM to fail.
 */

- (void) disableMSR:(BOOL) msrFlag  {
    
    
    /* verifone comments
     New methods:
     - (void) Q42;
     - (void) enableMSRDualTrack;
     
     New optional delegate protocol:
     - (void) pinpadMSRData:(NSString*)pan  expMonth:(NSString*)month  expYear:(NSString*)year  track1Data:(NSString*)track1  track2Data:(NSString*)track2;
     
     Both the original pinpadMSRData and the new pinpadMSRData are called by both Q40 and Q42.   Q42 populates the track2 of the original protocol, and Q40 only populates the track2 of the new protocol. 
     
     */
    
    
    if (msrFlag) {
        
        DLog(@"%@", @"disabling MSR");
        //		[[[VStore sharedVStore] pinPad] noResponseNextCommand];
        //		[[[VStore sharedVStore] pinPad] sendStringCommand:@"Q41" calcLRC:YES]; 	 
        
        [[[VStore sharedVStore] pinPad] disableMSR]; 
        
    } else {
        
        DLog(@"%@", @"enabling MSR");
        //		[[[VStore sharedVStore] pinPad] noResponseNextCommand];
        //		[[[VStore sharedVStore] pinPad] sendStringCommand:@"Q42" calcLRC:YES]; 	 
        
        [[[VStore sharedVStore] pinPad] enableMSRDualTrack]; 
        
    }
    
    // Verifone comments
    //[[[VStore sharedVStore] pinPad] setACKTimeout:saveAckTimeout];  
    //[[[VStore sharedVStore] pinPad] setFrameworkTimeout:saveFrameWorkTimeout]; 
    // TESTING KLUGE FOR CTLS ISSUE        
    //        [NSThread sleepForTimeInterval:0.155]; 
    
    
    
    //	}
	
}

- (void)enableCardScanner:(BOOL)flag
{
    [self disableMSR: ! flag];
}

//MARK: - VX sled sleep utils

// In use in store, VX sled goes to sleep (*not* a power down) when its battery drops to about
// 70%. It wakes back up when a command is sent from this app, but it takes it about 10
// seconds to wake up, and that first command tends to fail. After awaking, sled works fine.
// Default sled sleep time can be set with a VX param or by loading a special text file into it
// using the Verifone PwnMe demo app.
// After discussion with Tom Salzmann at Verifone, and trying a 4-hour sleep time,
// we are now setting the sled sleep time to 8 hours to keep th unit responsive in the store.

- (void)setTimeBeforeVX600SleepToFourHours {
    NSMutableArray *paramArray = [NSMutableArray arrayWithObject:@"XPITO=14400 "]; // 4 * 60 * 60 minutes
    [[[VStore sharedVStore] pinPad] setParameterArray:paramArray];
}

- (void)setTimeBeforeVX600SleepToEightHours {
    // Tom Salzmann from Verifone says 32,000 is an OK value to use
    NSMutableArray *paramArray = [NSMutableArray arrayWithObject:@"XPITO=32000 "]; // 8.88 * 60 * 60 minutes
    [[[VStore sharedVStore] pinPad] setParameterArray:paramArray];
}

//MARK: Verifone Barcode utils
// See Verifone manual for details...

- (void)sendISCPCommand: (unsigned char) commandType
                  group:(unsigned char) group
                    fid:(unsigned char) fid
                  param:(unsigned char) param {
    
    //ISCP_HIGH *frame = [[[ISCP_HIGH alloc] init] autorelease]; - object renamed in 64-bit VMF (1.0.5.295)
    VFI_ISCP_HIGH *frame = [[[VFI_ISCP_HIGH alloc] init] autorelease];
    frame.commandType = commandType;
    frame.group = group;
    frame.fid = fid;
    
#if 1
    unsigned char* bytes = malloc(1);
    bytes[0] = param;
    
    frame.param = [NSData dataWithBytes:bytes length:1];
    free(bytes);
#else
    frame.param = [NSData dataWithBytes:&param length:1];
#endif
    
    [[[VStore sharedVStore] barcode] sendISCP:frame];
}

- (void)enableBarcodeCheckDigit:(BOOL)flag
{
    if (barcode.isGen3) {
        [barcode mSymbology:SYM_PID_XMIT_UPCA_CHECK_DIGIT value:flag];
    } else {
        // See ISCP manual pg 60
        [self sendISCPCommand:0x41              // write
                        group:0x4B              // UPC / EAN group barcodes
                          fid:0X54              // function identifier
                        param:flag ? 0x01 : 0x00
        ];
    }
}

- (void)enableBarcodeTransmitsUPCE_as_UPCA:(BOOL)flag
{
    if (barcode.isGen3) {
        [barcode mSymbology:SYM_PID_CONVERT_UPCE_2_UPCA value:flag];
    } else {
        // See ISCP manual pg 60
        [self sendISCPCommand:0x41              // write command
                        group:0x4B              // UPC / EAN group barcodes
                          fid:0x5B              // function identifier for xmit UPC-E as UPC-A
                        param:flag ? 0x01 : 0x00
        ];
    }
}

//MARK: - Alert Utils
// Note: unused except by verifone simpleCardSwipeViewController, which is going away

- (UIAlertView *)showActivityIndicatorAlertWithMessage:(NSString *)waitMessage
{  
	UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:waitMessage message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles: nil] autorelease];; 	
    [alert show];  // show first so its bounds become valid

    UIActivityIndicatorView *indicator = [[[UIActivityIndicatorView alloc]  
                                           initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge] autorelease];;  
	
	indicator.center = CGPointMake(alert.bounds.size.width / 2,   
								   alert.bounds.size.height - 50);  
	[indicator startAnimating];  
	[alert addSubview:indicator];  

	return alert;  
}  


- (UIAlertView *)showAlertWithMessage:(NSString *)waitMessage
{  
	UIAlertView *alert = [[[UIAlertView alloc]   
						   initWithTitle:waitMessage   
						   message:nil delegate:nil cancelButtonTitle:nil  
						   otherButtonTitles: nil] autorelease];  
	
	[alert show];  
	
	return alert;  
}  

//MARK: - Data conversion Utils
// From Verifone sample code - could be made into category methods on NSString/NSData for cleaner organization.

int char2Hex(unichar c) {
	switch (c) {
		case '0' ... '9': return c - '0';
		case 'a' ... 'f': return c - 'a' + 10;
		case 'A' ... 'F': return c - 'A' + 10;
		default: return -1;
	}
}

- (NSData *)hexToData:(NSString*)str 
{   //Example - Pass string that contains characters "30313233", and it will return a data object containing ascii characters "0123"
	//unsigned stringIndex=0, resultIndex=0, max=[str length]; - implicit conversion loses integer precision
    unsigned long stringIndex=0, resultIndex=0, max=[str length];
	NSMutableData* result = [NSMutableData dataWithLength:(max + 1)/2];
	unsigned char* bytes = [result mutableBytes];
	
	unsigned num_nibbles = 0;
	unsigned char byte_value = 0;
	
	for (stringIndex = 0; stringIndex < max; stringIndex++) {
		int val = char2Hex([str characterAtIndex:stringIndex]);
		if (val < 0) continue;
		num_nibbles++;
		byte_value = byte_value * 16 + (unsigned char)val;
		if (! (num_nibbles % 2)) {
			bytes[resultIndex++] = byte_value;
			byte_value = 0;
		}
	}
	
	
	//final nibble
	if (num_nibbles % 2) {
		bytes[resultIndex++] = byte_value;
		//byte_value = 0; // analyzer-flagged dead store
	}
	
	[result setLength:resultIndex];
	return result;
}

- (NSString*) dataToString:(NSData*)data
{   //Example - Pass data that contains characters "0123", and it will return a string "0123"
	return  [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];	
}

-(NSData*) stringToData:(NSString *)str
{	
	return [str dataUsingEncoding:NSUTF8StringEncoding];
}

// Verifone sample code; removes spaces and < and > characeters from data retured from Verifone device
-(NSString*) nsdataToNSString:(NSData*)data
{
	return [[[[data description] stringByReplacingOccurrencesOfString:@" " withString:@""] stringByReplacingOccurrencesOfString:@"<" withString:@""] stringByReplacingOccurrencesOfString:@">" withString:@""] ;
}

- (NSString*) hexToString:(NSString*)str
{  //Example - Pass string that contains characters "30313233", and it will return a string "0123"
	return   [self dataToString:[self hexToData:str]];
}

//MARK: -

- (BOOL) isUpsideDown 
{	
	return upsideDown; 
}

- (void) setUpsideDown:(BOOL) orientation
{	
	upsideDown = orientation; 
}

//MARK: Class utility methods

+ (BOOL)verifoneEAAccessoryProtocolExists
{
    // Below is original Verifone comment (which is not totally clear) - BMonk
    //
    // gen 2.5  ... The correct protocol is com.verifone.PWMRDA, but you don't need to worry about this.  It is hidden/managed by the framework. 
    NSString *protocolFound = nil;
    if ([EAAccessoryManager accessoryProtocolExists:@"com.verifone.pmr.xpi"]) {
        protocolFound = @"com.verifone.pmr.xpi"; // gen 3 Verifone e315 device
    } else if ([EAAccessoryManager accessoryProtocolExists:@"com.verifone.pmr2.xpi"]) {
            protocolFound = @"com.verifone.pmr2.xpi";
    } else if ([EAAccessoryManager accessoryProtocolExists:@"com.verifone.PWMRDA"]) {
        protocolFound = @"com.verifone.PWMRDA";
    } else {
        DLog(@"%@", @"No Verifone Accessory protocol found"); 
        SPLog(@"No Veri fone EAAccessory protocol found"); // space makes it pronounce Verifone correctly :)
        return NO;
    }
    
    DLog(@"Found Accessory protocol %@\n\n", protocolFound);
    //SPLog(@"Found Accessory protocol %@", protocolFound);
    
    return YES;
}



@end
