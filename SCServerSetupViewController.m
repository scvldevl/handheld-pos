//
//  SCServerSetupViewController.m
//  ShoeCarnival
//
//  Created by Bill Monk on 6/19/12.
//  Copyright 2012 Big Nerd Ranch. All rights reserved.
//

#import "SCServerSetupViewController.h"
#import "VStore.h"

#import "UIAlertView+Utils.h"

@implementation SCServerSetupViewController
@synthesize delegate, serverAddressField, vncPortField, passwordField, showPasswordSlider, VXSleepTime4Button, VXSleepTime8Button, VXStatusLabel;

- (id)init {
    NSString *nibname = @"SCServerSetupViewController";
    self = [super initWithNibName:nibname bundle:nil];
    if (self) {
    }
    return self;
}

- (void)removeObservers {
    //[[NSNotificationCenter defaultCenter] removeObserver:nil]; - requires a non-null argument
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)addObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(VXCameOnlineNotification:)
												 name:ConnectVX600Notification
											   object:nil];

}

- (void)VXCameOnlineNotification:(NSNotification *)note {
    BOOL VX600Connected = [[[VStore sharedVStore] pinPad] pinpadConnected];
    if (VX600Connected) { // double-check
        [self setVXConnectedUIState];
    }
}

- (void)setVXConnectedUIState {
    [VXSleepTime4Button setEnabled:YES];
    [VXSleepTime4Button setTitleColor:[UIColor blackColor] forState:UIControlStateDisabled];
    [VXSleepTime4Button setAlpha:1.0];
    
    [VXSleepTime8Button setEnabled:YES];
    [VXSleepTime8Button setTitleColor:[UIColor blackColor] forState:UIControlStateDisabled];
    [VXSleepTime8Button setAlpha:1.0];
    
    [VXStatusLabel setText:@"VX600 Connected"];
}

- (void)setVXDisconnectedUIState {
    [VXSleepTime4Button setEnabled:NO];
    [VXSleepTime4Button setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
    [VXSleepTime4Button setAlpha:0.4];
    
    [VXSleepTime8Button setEnabled:NO];
    [VXSleepTime8Button setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
    [VXSleepTime8Button setAlpha:0.4];
    
    [VXStatusLabel setText:@"VX600 Not Connected"];
}

//MARK: -
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];

    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

    self.versionLabel.text = [NSString stringWithFormat:@"SCClient Version %@", appVersionString];
    
    // need a notification in case VX comes on line after this view appears
    
    BOOL VX600Connected = [[[VStore sharedVStore] pinPad] pinpadConnected];
    if (VX600Connected) {
        [self setVXConnectedUIState];
    } else {
        [self setVXDisconnectedUIState];
    }
    
    [self addObservers];
}

//MARK: IBActions

- (IBAction)exitServerSetup
{
    //if (![[self modalViewController] isBeingDismissed]) { - deprecated in iOS 6.0
    if (![[self presentedViewController] isBeingDismissed]) {
        [self dismissViewControllerAnimated:YES completion:^{
            if	([delegate respondsToSelector:@selector(serverSetupPanelDidEndWithIP:vncPort:password:)]) {
                [delegate serverSetupPanelDidEndWithIP:serverAddressField.text
                                               vncPort:vncPortField.text
                                              password:passwordField.text]; // attempts to connect
            }
        }];
    }
    

}

- (IBAction)cancelButtonTapped
{
    //if (![[self modalViewController] isBeingDismissed]) { - deprecated in iOS 6.0
    if (![[self presentedViewController] isBeingDismissed]) {
        [self dismissViewControllerAnimated:YES completion:nil];
        //    if ([delegate respondsToSelector:@selector(serverSetupPanelDidEndWithIP:vncPort:password:)]) {
        //        [delegate serverSetupPanelDidEndWithIP:serverAddressField.text
        //                                       vncPort:vncPortField.text
        //                                      password:passwordField.text]; // attempts to connect
        //    }
        //}];
    }
}

- (IBAction)showPasswordTapped:(UISwitch *)sw
{
    // temp method to show text in secure field for debugging
    BOOL isOn = sw.isOn;
    self.passwordField.secureTextEntry = !isOn;
    [self.passwordField setNeedsDisplay];
    [self.passwordField setNeedsLayout];
}

- (IBAction)adjustVXSleeptimeButtonTapped:(UIButton *)b
{
    NSInteger numHours = [b tag];
    NSString *msg = [NSString stringWithFormat:@"Set VX600 sleep time to %ld hours? VX will reboot.\r\rIf VX is currently starting up, allow it to complete before doing this.", (long)numHours];
    [SCKAlertView showWithTitle:@"VX600 Sleep Time"
                        message:msg
                     usingBlock:^(UIAlertView *alertView, NSUInteger buttonIndex) {
                         if (buttonIndex != [alertView cancelButtonIndex]) {
                             switch (numHours) {
                                 case 8:
                                     [[VStore sharedVStore] setTimeBeforeVX600SleepToEightHours];
                                     break;
                                 case 4:
                                     [[VStore sharedVStore] setTimeBeforeVX600SleepToFourHours];
                                     break;
                                 default:
                                     break;
                             }
                         }
                     }
              cancelButtonTitle:@"Cancel"
              otherButtonTitles:@"OK", nil];
}

//MARK: UITextViewDelegate
-(BOOL)textFieldShouldReturn:(UITextField *)theTextField {
    //Called when the return key is pressed while editing a textField
    [theTextField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField;             // may be called if forced even if shouldEndEditing returns NO (e.g. view removed from window) or endEditing:YES called
{
    if (textField == self.passwordField) {
        self.passwordField.secureTextEntry = YES;
        [self.passwordField setNeedsDisplay];
        [self.showPasswordSlider setOn:NO animated:YES];
    }
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
    
    [self removeObservers];
    
    [self setVersionLabel:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
	
	self.serverAddressField = nil;
	self.vncPortField = nil;
	self.passwordField = nil;
    self.showPasswordSlider = nil;
}


- (void)dealloc {
	
    [self removeObservers];

	delegate = nil;
	[serverAddressField release];
	[vncPortField release];
	[passwordField release];
	[showPasswordSlider release];
    
    [_versionLabel release];
    [super dealloc];
}


@end
