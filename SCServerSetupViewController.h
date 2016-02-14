//
//  SCServerSetupViewController.h
//  ShoeCarnival
//
//  Created by Bill Monk on 6/19/12.
//  Copyright 2012 Big Nerd Ranch. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface SCServerSetupViewController : UIViewController {
	id delegate;
	IBOutlet UITextField *serverAddressField;
	IBOutlet UITextField *vncPortField;
	IBOutlet UITextField *passwordField;
    
	IBOutlet UISwitch *showPasswordSlider;
}
@property (nonatomic, assign) id delegate;
@property (nonatomic, retain) IBOutlet UITextField *serverAddressField;
@property (nonatomic, retain) IBOutlet UITextField *vncPortField;
@property (nonatomic, retain) IBOutlet UITextField *passwordField;
@property (nonatomic, retain) IBOutlet UISwitch *showPasswordSlider;
@property (retain, nonatomic) IBOutlet UILabel *versionLabel;
@property (retain, nonatomic) IBOutlet UIButton *VXSleepTime4Button;
@property (retain, nonatomic) IBOutlet UIButton *VXSleepTime8Button;
@property (retain, nonatomic) IBOutlet UILabel *VXStatusLabel;

- (IBAction)exitServerSetup;
- (IBAction)showPasswordTapped:(UISwitch *)sw;
- (IBAction)adjustVXSleeptimeButtonTapped:(UIButton *)b;
@end


@protocol SCServerSetupViewControllerDelegate <NSObject>
- (void)serverSetupPanelDidEndWithIP:(NSString *)IPAddress vncPort:(NSString *)vncPort password:(NSString *)password;
@end