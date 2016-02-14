//
//  DebugSheetViewController.h
//  ShoeCarnival
//
//  Created by Steve Sparks on 10/12/12.
//  Copyright (c) 2012 Big Nerd Ranch. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DebugSheetViewController : UIViewController
- (IBAction)enableHostPowerMode:(id)sender;
- (IBAction)disableHostPowerMode:(id)sender;
- (IBAction)enableXcodeMode:(id)sender;
- (IBAction)disableXcodeMode:(id)sender;
- (IBAction)dismissButtonPressed:(id)sender;

@property (retain, nonatomic) IBOutlet UITextView *diagnosticView;

@end
