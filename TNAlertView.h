//
//  TNAlertView.h
//  TravelNevada
//
//  Created by Bill Monk on 3/17/13.
//  Copyright (c) 2013 Big Nerd Ranch. All rights reserved.
//

#import <UIKit/UIKit.h>

//MARK: - TNAlertView

typedef void (^TNAlertBlock)(UIAlertView *alertView, NSUInteger buttonIndex);

/*
 Subclass of UIAlaertView that's less-unwieldly than Apple's one-sheet-delegate-fits-all approach.
 A block to be used as the dismissal handler. The alert is it's *own* delegate, and the button-clicked
 delegate method calls the block when a button is invoked.
 Helps eliminate confusion, cruft, and and object lifetime issues which arise when multiple sheets are
 needed in the same class, forcing them all to share a single delegate callback. (Apple really should've
 allowed passing the selector of a delegate method as with NSAlerts)
 The basic idea was stolen from here:
 http://stackoverflow.com/questions/7678341/how-to-determine-which-uialertview-called-the-delegate
 */

@interface TNAlertView : UIAlertView <UIAlertViewDelegate>
{
    TNAlertBlock _block;
}

@end
