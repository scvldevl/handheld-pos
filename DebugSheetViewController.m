//
//  DebugSheetViewController.m
//  ShoeCarnival
//
//  Created by Steve Sparks on 10/12/12.
//  Copyright (c) 2012 Big Nerd Ranch. All rights reserved.
//

#import "DebugSheetViewController.h"
#import "VStore.h"

@interface DebugSheetViewController ()

@end

@implementation DebugSheetViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewWillAppear:(BOOL)animated {
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)enableHostPowerMode:(id)sender {
    [[[VStore sharedVStore] payControl] hostPowerEnabled:YES];
}

- (IBAction)disableHostPowerMode:(id)sender {
    [[[VStore sharedVStore] payControl] hostPowerEnabled:NO];
}

- (IBAction)enableXcodeMode:(id)sender {
    [[VStore sharedVStore] enablePassthroughXCodeDebugging:YES];
}

- (IBAction)disableXcodeMode:(id)sender {
    [[VStore sharedVStore] enablePassthroughXCodeDebugging:NO];
}

- (IBAction)dismissButtonPressed:(id)sender {
    [self.view removeFromSuperview];
}

- (void)dealloc {
    [_diagnosticView release];
    [super dealloc];
}

- (void)viewDidUnload {
    [self setDiagnosticView:nil];
    [super viewDidUnload];
}
@end
