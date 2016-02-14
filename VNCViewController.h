//
//  VNCViewController.h
//
//

#import <UIKit/UIKit.h>
#import	<ExternalAccessory/ExternalAccessory.h>

#import <VMF/VMFramework.h>

#import "MBProgressHUD.h"
#import "VNCContentView.h"
#import "SCServerSetupViewController.h"
#import "ScrawlViewController.h"

#import "simpleCardSwipeViewController.h"
@class DebugSheetViewController;
@class ServerBase;

#if DEBUG
@class GSKFlite; // for spoken debugging
#endif

@class ScrawlViewController;

@class simpleCardSwipeViewController; // will go away

@interface VNCViewController : UIViewController <UIScrollViewDelegate, UIAccelerometerDelegate, UITextViewDelegate, NSURLConnectionDelegate, UIAlertViewDelegate,
	VFIBarcodeDelegate, VFIControlDelegate, VFIPinpadDelegate, SCServerSetupViewControllerDelegate, ScrawlViewControllerDelegate>
{
	// Original COTVNC code
    CGSize _contentSize;
    VNCContentView *vncView;
	
	RFBConnection *vncConnection;
	// end original COTVNC code
	ServerBase *serv;

	// Begin new Shoe Carnival code
	UIButton *screenLockView;		// when device is inverted, this view covers the screen to "lock" it and prevent inadvertent upside-down screen taps. Using a UIButton because it automatically will highlight when tapped.
	UITextView *keyboardtextField;
    UIView *buttonOverlayView;
	
    // only used with verifone's test view, which is going away
    UINavigationController *navVC;
    simpleCardSwipeViewController *verifoneTestScreenViewController;
    //
    
	// Verifone ivars
	BOOL verifoneDeviceInitStarted;
	BOOL verifoneDeviceInitDone;
    
    // signature-capture view
    ScrawlViewController *signatureViewController;
    MBProgressHUD *hudView;
    
    
}
@property (nonatomic, retain) DebugSheetViewController *dbg;

@property (nonatomic, retain) IBOutlet VNCContentView *vncView;
@property (nonatomic, retain) IBOutlet UIView *buttonOverlayView;

@property (nonatomic, retain) ScrawlViewController *signatureViewController;

@end

