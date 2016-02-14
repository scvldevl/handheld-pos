//
//  ScrawlViewController.m
//  GEForms3
//
//  Created by Steve Marriott on 10/7/11.
//  Copyright (c) 2011 Big Nerd Ranch. All rights reserved.
//

#import "ScrawlViewController.h"
#import "ScrawlDrawView.h"

#import "UILabel+Utils.h"
#import "UIAlertView+Utils.h"
#import "TNActionSheet.h"

@implementation ScrawlViewController
@synthesize section, step;
@synthesize scrawlDrawView, hasDismissButton, hasClearSignatureButton, hasCancelButton, swipeInButtonPaneClearsDrawing;
@synthesize loadsSavedData;
@synthesize buttonPane, doneButton, clearSignatureButton, cancelButton, shakeLabel, doubleTapLabel, scrawlColor, backgroundColor;
@synthesize delegate = _delegate;

-(void)orientationChanged 
{
    // Call my delegate to close and re-create me.
    if ([[self delegate] respondsToSelector:@selector(recreateScrawlViewPopover)]) {
        // Need to save scrawls first....
        NSMutableArray *completedScrawlsArray = [[self scrawlDrawView] completedScrawls];
        [[self scrawlDrawView] saveScrawlArray:completedScrawlsArray 
								forStepNumber:[self step]
									 inSection:[self section]];
        [[self delegate] recreateScrawlViewPopover];
    }
}

-(void)registerNotifications
{
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
	
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(orientationChanged) 
               name:UIDeviceOrientationDidChangeNotification
             object:nil];
}

-(void)unregisterNotificiations
{
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

//MARK: -

- (id)initWithScrawlColor:(UIColor *)scrColor
     backgroundColorColor:(UIColor *)bgColor
         hasDismissButton:(BOOL)hasDismissBtnFlag
  hasClearSignatureButton:(BOOL)hasClearSignatureBtnFlag
          hasCancelButton:(BOOL)hasCancelBtnFlag
           loadsSavedData:(BOOL)loadsSavedDataFlag
{
    self = [super init];
    if (self) {
        [self registerNotifications];
        
        if (!scrColor) {
            scrColor = [UIColor whiteColor];
        }
        [self setScrawlColor:scrColor];

        if (!bgColor) {
            bgColor = [UIColor blackColor];
        }
        [self setBackgroundColor:bgColor];
        
        [self setHasDismissButton:hasDismissBtnFlag];
        [self setHasClearSignatureButton:hasClearSignatureBtnFlag];
        [self setHasCancelButton:hasCancelBtnFlag];
        
        [self setLoadsSavedData:loadsSavedDataFlag];
    }
    return self;
}

-(id)init {
    return [self initWithScrawlColor:nil backgroundColorColor:nil hasDismissButton:NO hasClearSignatureButton:NO hasCancelButton:NO loadsSavedData:YES];
}

+ (id)createWithScrawlColor:(UIColor *)scrColor
       backgroundColorColor:(UIColor *)bgColor
           hasDismissButton:(BOOL)hasDismissBtnFlag
{
    return [[[self alloc] initWithScrawlColor:scrColor
                         backgroundColorColor:bgColor
                             hasDismissButton:hasDismissBtnFlag
                      hasClearSignatureButton:NO
                              hasCancelButton:NO
                               loadsSavedData:YES] autorelease];
}

+ (id)createWithScrawlColor:(UIColor *)scrColor
       backgroundColorColor:(UIColor *)bgColor
           hasDismissButton:(BOOL)hasDismissBtnFlag
             loadsSavedData:(BOOL)loadsSavedDataFlag
{
    return [[[self alloc] initWithScrawlColor:scrColor
                         backgroundColorColor:bgColor
                             hasDismissButton:hasDismissBtnFlag
                      hasClearSignatureButton:NO
                              hasCancelButton:NO
                               loadsSavedData:loadsSavedDataFlag] autorelease];
}

+ (id)createWithScrawlColor:(UIColor *)scrColor
       backgroundColorColor:(UIColor *)bgColor
           hasDismissButton:(BOOL)hasDismissBtnFlag
           hasClearSignatureButton:(BOOL)hasClearSignatureBtnFlag
             loadsSavedData:(BOOL)loadsSavedDataFlag
{
    return [[[self alloc] initWithScrawlColor:scrColor
                         backgroundColorColor:bgColor
                             hasDismissButton:hasDismissBtnFlag
                      hasClearSignatureButton:hasClearSignatureBtnFlag
                              hasCancelButton:NO
                               loadsSavedData:loadsSavedDataFlag] autorelease];
}

+ (id)createWithScrawlColor:(UIColor *)scrColor
       backgroundColorColor:(UIColor *)bgColor
           hasDismissButton:(BOOL)hasDismissBtnFlag
    hasClearSignatureButton:(BOOL)hasClearSignatureBtnFlag
            hasCancelButton:(BOOL)hasCancelBtnFlag
             loadsSavedData:(BOOL)loadsSavedDataFlag
{
    return [[[self alloc] initWithScrawlColor:scrColor
                         backgroundColorColor:bgColor
                             hasDismissButton:hasDismissBtnFlag
                      hasClearSignatureButton:hasClearSignatureBtnFlag
                              hasCancelButton:hasCancelBtnFlag
                               loadsSavedData:loadsSavedDataFlag] autorelease];
}

//MARK: -

- (void)clearSignatureWithConfirmationAlert
{
    [SCKAlertView showWithTitle:@"Clear Signature?"
                        message:@""
                     usingBlock:^(UIAlertView *alertView, NSUInteger buttonIndex) {
                         if (buttonIndex != [alertView cancelButtonIndex]) {
                             [self.scrawlDrawView clearAll];
                         }
                     }
              cancelButtonTitle:@"Cancel"
              otherButtonTitles:@"OK", nil];
}


//MARK: -

- (void)dismiss {
    if ([[self delegate] respondsToSelector:@selector(scrawlViewControllerWillDismiss:)]) {
        [[self delegate] scrawlViewControllerWillDismiss:self];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)doneButtonTapped
{
    // Show alert if no signature points have been drawn at all. If this happens, Done button
    // may have been tapped by accident
    BOOL signaturePointsExists = ([[[self scrawlDrawView] completeScrawls] count] > 0);
    if (signaturePointsExists) {
        [self dismiss];
    } else {
        [TNActionSheet showFromRect:doneButton.frame
                             inView:buttonPane
                          withTitle:@"Signature Required"
                         usingBlock:^(UIActionSheet *actioSheet, NSUInteger buttonIndex){
                             if (buttonIndex == [actioSheet destructiveButtonIndex]) {
                                 self.scrawlDrawView.completeScrawls = nil; // we should only get here if
                                                                            // [completeScrawls count] == 0 (i.e. customer
                                                                            // did not sign anything) but let's clear it here
                                                                            // to ensure a destructive cancel
                                                                            // really does that no matter what.
                                 [self dismiss];
                             } 
                         }
                  cancelButtonTitle:nil                     // Cancel btn would mean cancel the sheet and return to sig panel
             destructiveButtonTitle:@"Cancel Transaction"   // destructive button means cancel transaction and exit sig panel
                  otherButtonTitles:@"Enter Signature", nil];
    }
}

- (IBAction)cancelButtonTapped
{
    [self.scrawlDrawView clearEachScrawl];
    [self.scrawlDrawView setNeedsDisplay];
    
    self.scrawlDrawView.completeScrawls = nil;
    [self dismiss];
}

- (IBAction)clearSignatureButtonTapped
{
    [self clearSignatureWithConfirmationAlert];
}

//MARK: -

- (void)loadView 
{
    ScrawlDrawView *v = [ScrawlDrawView createWithFrame:CGRectZero
                                            scrawlColor:[self scrawlColor]
                                        backGroundColor:[self backgroundColor]];
    
    [v setShakeClearsDrawing:NO];			// may want to turn this off if too annoying
	[v setShakeClearsIncrementally:NO];     // definitely may way to turn this off
	[v setDoubletapClearsDrawing:NO];       // and experiment with this: easy to trigger while signing.
	
    [self setSwipeInButtonPaneClearsDrawing:NO]; // requested by Dean at SC
    
    [self setScrawlDrawView:v];
    [self setView:scrawlDrawView];
}

- (void)centerView:(UIView *)v betweenLeftView:(UIView *)leftView rightView:(UIView *)rightView
{
    CGRect frame = [v frame];
    frame.origin.x = (leftView.frame.origin.x + leftView.frame.size.width) +
                    ((rightView.frame.origin.x - (leftView.frame.origin.x + leftView.frame.size.width)) - frame.size.width) / 2;
    [v setFrame:frame];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([self hasDismissButton]) {
        CGRect frame = [[self view] bounds];
        const float buttonPaneHeight = 65.0;
        
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7)
            frame.origin.y = [UIScreen mainScreen].bounds.size.height - buttonPaneHeight;
        else
            frame.origin.y = frame.size.height - buttonPaneHeight;
        
        frame.size.height = buttonPaneHeight;
        
        buttonPane = [[UIView alloc] initWithFrame:frame];
        [buttonPane setBackgroundColor:[UIColor blackColor]];
        buttonPane.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        const float edgeInset = 12.0; // eyeballed
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [button setTitle:@"Done" forState:UIControlStateNormal];
        [button sizeToFit];
        frame = [button frame];
        frame.origin.y = (([buttonPane frame].size.height - [button frame].size.height) / 2);
        frame.origin.x = [buttonPane frame].size.width - [button frame].size.width - edgeInset; // eyeballed
        [button setFrame:frame];
        [button addTarget:self action:@selector(doneButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [buttonPane addSubview:button];
        [[self view] addSubview:buttonPane];
        [self setDoneButton:button];
        
        if (self.hasCancelButton) {
            button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
            [button setTitle:@"Cancel" forState:UIControlStateNormal];
            [button sizeToFit];
            frame = [button frame];
            frame.origin.y = (([buttonPane frame].size.height - [button frame].size.height) / 2);
            frame.origin.x = edgeInset; // eyeballed
            [button setFrame:frame];
            [button addTarget:self action:@selector(cancelButtonTapped) forControlEvents:UIControlEventTouchUpInside];
            button.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
            [buttonPane addSubview:button];
            [[self view] addSubview:buttonPane];
            [self setCancelButton:button];
        }

        // clear signature button
        if (self.hasClearSignatureButton) {
            button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
            [button setTitle:@"Clear" forState:UIControlStateNormal];
            [button sizeToFit];
            frame = [button frame];
            frame.origin.y = (([buttonPane frame].size.height - [button frame].size.height) / 2);
            frame.origin.x = edgeInset; // eyeballed
            [button setFrame:frame];
            [button addTarget:self action:@selector(clearSignatureButtonTapped) forControlEvents:UIControlEventTouchUpInside];
            button.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
            [buttonPane addSubview:button];
            [[self view] addSubview:buttonPane];
            [self setClearSignatureButton:button];
        }

        frame = [buttonPane frame];
        frame.origin.y = (([buttonPane frame].size.height - [button frame].size.height) / 2);
        frame.origin.x = edgeInset; // eyeballed
//        frame.origin.x = edgeInset + [self.cancelButton frame].size.width + 30.0; // eyeballed
//        frame.origin.y += 10.0;
        UILabel *label = [[[UILabel alloc] initWithFrame:frame] autorelease];
        [label setTextColor:[UIColor whiteColor]];
        [label setBackgroundColor:[UIColor clearColor]];
        [label setText:@"Shake to Erase"];
        [label multiplyFontSizeBy:.85];
        [label sizeToFit];
//        [self centerView:label betweenLeftView:self.cancelButton rightView:self.doneButton];
        //label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        if (self.scrawlDrawView.shakeClearsDrawing) {
            [self setShakeLabel:label];
            [[self view] addSubview:label];
        }
        
        frame = [shakeLabel frame];
        frame.origin.x = edgeInset + [self.cancelButton frame].size.width + 15.0; // eyeballed
        frame.origin.y += frame.size.height + 6.0; // eyeballed
        label = [[[UILabel alloc] initWithFrame:frame] autorelease];
        [label setTextColor:[UIColor whiteColor]];
        [label setBackgroundColor:[UIColor clearColor]];
        [label setText:@"Double-Tap to Clear"];
        [label multiplyFontSizeBy:.85];
        [label sizeToFit];
        [self centerView:label betweenLeftView:self.cancelButton rightView:self.doneButton];
        //label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        if (self.scrawlDrawView.doubletapClearsDrawing) {
            [self setDoubleTapLabel:label];
            [[self view] addSubview:label];
        }
        
        // Install swipe gesture handler; whether it does anything is controlled by -swipeClearsDrawing
        UISwipeGestureRecognizer *r = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(swipeGestureRecognized:)];
        [r setNumberOfTouchesRequired:3];
        [r setDirection:(UISwipeGestureRecognizerDirectionLeft | UISwipeGestureRecognizerDirectionRight)];
        [buttonPane addGestureRecognizer:r];
    }

    if (self.loadsSavedData) {
        NSMutableArray *completedScrawlsArray = [[self scrawlDrawView] loadScrawlForStepNumber:[self step]
                                                                                     inSection:[self section]];
        if ([completedScrawlsArray count]) {
            // There was something loaded from disk, so draw it
            [[self scrawlDrawView] setNeedsDisplay];
        }

    }
}

//MARK: - Gestures

- (void)swipeGestureRecognized:(UISwipeGestureRecognizer *)r
{
    if ([self swipeInButtonPaneClearsDrawing]) {
        [self clearSignatureWithConfirmationAlert];
    }
}

//MARK: _

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation;
{
    return (toInterfaceOrientation == UIInterfaceOrientationPortrait);

//    if (toInterfaceOrientation == UIDeviceOrientationPortraitUpsideDown) {
//        return NO;
//    }
//    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    CGRect rect = [[self view] bounds];
    CGRect buttonPaneFrame = [buttonPane frame];
    buttonPaneFrame.origin.y = rect.size.height - buttonPaneFrame.size.height;
    [buttonPane setFrame:buttonPaneFrame];
    
    CGRect frame = self.shakeLabel.frame;
    frame.origin.y = buttonPaneFrame.origin.y + 10.0;
    [self.shakeLabel setFrame:frame];
    [self centerView:self.shakeLabel betweenLeftView:self.cancelButton rightView:self.doneButton];
    
    frame = self.shakeLabel.frame;
    float newY = frame.origin.y += frame.size.height + 6.0;
    frame = self.doubleTapLabel.frame;
    frame.origin.y = newY;
    [doubleTapLabel setFrame:frame];
    [self centerView:self.doubleTapLabel betweenLeftView:self.cancelButton rightView:self.doneButton];
}

//MARK: _

- (void)saveSignature
{
    NSMutableArray *completedScrawlsArray = [[self scrawlDrawView] completedScrawls];
    [[self scrawlDrawView] saveScrawlArray:completedScrawlsArray 
							 forStepNumber:[self step]
								 inSection:[self section]];	
}

- (UIImage *)image
{
	ScrawlDrawView *sv = (ScrawlDrawView *)[self view];
	return [sv image];
}

- (UIImage *)imageWithScrawlColor:(UIColor *)desiredScrawlColor backgroundColor:(UIColor *)desiredBackgroundColor;
{
	ScrawlDrawView *sv = (ScrawlDrawView *)[self view];
	return [sv imageWithScrawlColor:desiredScrawlColor backgroundColor:desiredBackgroundColor];
}

//MARK: -

- (void)viewDidAppear:(BOOL)animated
{
	if ([scrawlDrawView shakeClearsDrawing]) {
		[scrawlDrawView becomeFirstResponder];
	}
}

- (void)viewWillDisappear:(BOOL)animated
{

}

- (void)viewDidUnload
{
	[super viewDidUnload];

	[self unregisterNotificiations];
    [self setButtonPane:nil];
	[self setScrawlDrawView:nil];
	[self setDelegate:nil];
}

-(void)dealloc
{
	[self unregisterNotificiations];
	_delegate = nil;
    
    for (UIGestureRecognizer *r in buttonPane.gestureRecognizers) {
        [buttonPane removeGestureRecognizer:r];
    }
    [buttonPane release];
    
	[scrawlDrawView release];
    
    self.doneButton = nil;
    self.clearSignatureButton = nil;
    self.clearSignatureButton = nil;
	
    [super dealloc];
}

@end
