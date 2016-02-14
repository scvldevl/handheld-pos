//
//  simpleCardSwipeViewController.h
//  simpleCardSwipe
//
//  Based on code by Thomas Salzmann on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//
//  Altered for Shoe Carnival by BigNerdRanch 2012
//

#import <UIKit/UIKit.h>
#import <VMF/VMFramework.h>
#import	<ExternalAccessory/ExternalAccessory.h>

#define RunWithoutNeedlessTimers (1)    // Verifone sample code uses many non-repeating NSTimers (and fails to properly memory-manage them...) when a simple performSelector...withDelay would serve.
                                        // Moving toward elimination of that code.

// CAC - accelerometer... 
@interface simpleCardSwipeViewController : UIViewController <UIAccelerometerDelegate, VFIPinpadDelegate, VFIControlDelegate, /* VFIZontalkDelegate,*/ VFIBarcodeDelegate> 
{
    UIAccelerationValue _accelerometerFilter[3];
    
	IBOutlet UITextField *cardData; 
	IBOutlet UIButton *connectButton; 
	IBOutlet UIButton *controlButton; 
	IBOutlet UIActivityIndicatorView *waitSwipe; 
	IBOutlet UITextField *frameworkReturnCode; 
	IBOutlet UITextField *frameworkReturnCode2; 
	IBOutlet UITextView	*miscText;
//	VFIPinpad *pinPad;  
//	VFIZontalk *zonTalk;
	// VFIControl *payControl; 
    
#if !RunWithoutNeedlessTimers
	NSTimer *myTimer; 
#endif
	NSTimer *batteryCheckTimer;
    
	UIAlertView *myAlert; 

	// button to hide/unhide when we go upside down :-)
	IBOutlet UIButton *controlNotReady;
	IBOutlet UIButton *pinpadNotReady;
	IBOutlet UIButton *hideUnHide;
    IBOutlet UILabel *versionLabel;
    IBOutlet UILabel *kfwLabel;
    IBOutlet UIProgressView *battery;

}
	
-(IBAction) combinedButtonPushed;
-(IBAction) s20ButtonPushed;
-(IBAction) enterPINButton;
-(IBAction) blobButton;
-(IBAction) Z50Button;
-(IBAction) swipeButtonPushed;
-(IBAction) keypadOnButtonPushed;
-(IBAction) keypadOffButtonPushed;
-(IBAction) msrOnButtonPushed;
-(IBAction) msrOffButtonPushed;
-(IBAction) clearMiscText;
-(IBAction) resetButtonPushed;
-(IBAction) loadStuffButton;
-(IBAction) loadXPIButton;
-(IBAction) pkiButton;
-(IBAction) vspButton;


// @property(nonatomic, retain) VFIPinpad *pinPad;
// @property(nonatomic, retain) VFIZontalk *zonTalk;
// @property(nonatomic, retain) VFIControl *payControl; 
@property(nonatomic, retain) UITextField *cardData; 
@property(nonatomic, retain) UIButton *connectButton; 
@property(nonatomic, retain) UIButton *controlButton; 
@property(nonatomic, retain) UIActivityIndicatorView *waitSwipe; 
@property(nonatomic, retain) UITextField *frameworkReturnCode; 
@property(nonatomic, retain) UITextField *frameworkReturnCode2; 
@property(nonatomic, retain) UITextView	*miscText;

#if !RunWithoutNeedlessTimers
@property(nonatomic, retain) NSTimer *myTimer; 
#endif
@property(nonatomic, retain) NSTimer *batteryCheckTimer; 

@property(nonatomic, retain) UIAlertView *myAlert; 
@property(nonatomic, retain) UIAlertView *myAlert2; 

@property(nonatomic, retain) UIButton *hideUnHide; 
@property(nonatomic, retain) UIButton *pinpadNotReady; 
@property(nonatomic, retain) UIButton *controlNotReady; 
@property(nonatomic, retain) UILabel *versionLabel; 
@property(nonatomic, retain) UILabel *kfwLabel; 
@property(nonatomic, retain) UIProgressView *battery;

- (IBAction)verifoneTestScreenDoneButtonTapped;

@end

