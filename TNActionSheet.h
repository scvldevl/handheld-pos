//
//  TNActionSheet.h
//  TravelNevada
//
//  Created by Bill Monk on 3/17/13.
//  Copyright (c) 2013 Big Nerd Ranch. All rights reserved.
//

#import <UIKit/UIKit.h>

/*
 Subclass of UIActionSheet that's less-unwieldly than Apple's one-sheet-delegate-fits-all approach.
 A block to be used as the dismissal handler. The sheet is it's *own* delegate, and the button-clicked
 delegate method calls the block when a button is invoked.
 Helps eliminate confusion, cruft, and and object lifetime issues which arise when multiple sheets are
 needed in the same class, forcing them all to share a single delegate callback. (Apple really should've
 allowed passing the selector of a delegate method as is done with NSAlerts)
 The basic idea was stolen from here:
 http://stackoverflow.com/questions/7678341/how-to-determine-which-uialertview-called-the-delegate
 */

typedef void (^TNActionSheetBlock)(UIActionSheet *actioSheet, NSUInteger buttonIndex);

@interface TNActionSheet : UIActionSheet <UIActionSheetDelegate>
{
    TNActionSheetBlock _block;
}

+ (id)showFromTabBar:(UITabBar *)tabBar
           withTitle:(NSString *)title
          usingBlock:(TNActionSheetBlock)block
   cancelButtonTitle:(NSString *)cancelButtonTitle
destructiveButtonTitle:(NSString *)destructiveButtonTitle
   otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;

+ (id)showFromRect:(CGRect)rect
            inView:(UIView *)view
         withTitle:(NSString *)title
        usingBlock:(TNActionSheetBlock)block
 cancelButtonTitle:(NSString *)cancelButtonTitle
destructiveButtonTitle:(NSString *)destructiveButtonTitle
 otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;

@end
