//
//  NavViewController.m
//  ShoeCarnival
//
//  Created by Bill Monk on 7/6/12.
//  Copyright (c) 2012 Big Nerd Ranch. All rights reserved.
//

#import "NavViewController.h"

@implementation NavViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle


// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0.0, -10.0, 320.0, 480.0)] autorelease];
    self.view = v;
}


/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
}
*/

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (interfaceOrientation == UIDeviceOrientationPortraitUpsideDown) {
        return NO;
    }
    return UIDeviceOrientationIsPortrait(interfaceOrientation);
}

@end
