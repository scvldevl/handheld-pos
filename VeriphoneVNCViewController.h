//
//  VeriphoneVNCViewController.h
//
//  Based on code by Thomas Salzmann on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//
//  Altered for Shoe Carnival by BigNerdRanch 2012
//

#import <UIKit/UIKit.h>
#import <VMF/VMFramework.h>
#import	<ExternalAccessory/ExternalAccessory.h>

#import "VNCViewController.h"

#define RunWithoutNeedlessTimers (1)    // Veriphone sample code uses many non-repeating NSTimers (and fails to properly memory-manage them...) when a simple performSelector...withDelay would serve.
                                        // Moving toward elimination of that code.

// CAC - accelerometer... 
@interface VeriphoneVNCViewController : VNCViewController <UIAccelerometerDelegate, VFIPinpadDelegate, VFIControlDelegate, /* VFIZontalkDelegate,*/ VFIBarcodeDelegate> 
{
    UIAccelerationValue _accelerometerFilter[3];
    
//	VFIPinpad *pinPad;  
//	VFIZontalk *zonTalk;
	// VFIControl *payControl; 
    
#if !RunWithoutNeedlessTimers
	NSTimer *myTimer; 
#endif
	NSTimer *batteryCheckTimer;
    
	UIAlertView *myAlert; 

    UIButton *hideUnHide; // unused
}
	

// @property(nonatomic, retain) VFIPinpad *pinPad;
// @property(nonatomic, retain) VFIZontalk *zonTalk;
// @property(nonatomic, retain) VFIControl *payControl; 

#if !RunWithoutNeedlessTimers
@property(nonatomic, retain) NSTimer *myTimer; 
#endif
@property(nonatomic, retain) NSTimer *batteryCheckTimer; 

@property(nonatomic, retain) UIAlertView *myAlert; 
@property(nonatomic, retain) UIAlertView *myAlert2; 

@property(nonatomic, retain) UIProgressView *battery;


@end

