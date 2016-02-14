//
//  UIAlertView+Utils.h
//  ShoeCarnival
//
//  Created by Bill Monk on 10/5/12.
//  Copyright (c) 2012 Big Nerd Ranch. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UIAlertView (Utils)
+ (void)displayAlertOnNextRunLoopInvocationWithTitle:(NSString *)title
                                             message:(NSString *)msg
                                            delegate:(id)del
                                   cancelButtonTitle:(NSString *)cancelBtnTitle
                                    otherButtonTitle:(NSString *)otherBtnTitle;

@end

//MARK: - SCKAlertView

typedef void (^SCKAlertBlock)(UIAlertView *alertView, NSUInteger buttonIndex);

/** A less-unwieldly specialization of UIAlertView that allows a Block to be used as the dismissal handler.
 This is more flexible and compact than the delegate based approach. It allows all the logic to
 be centralized within the launching method and eliminates confusion and object lifetime issues that arise
 when using multiple alerts in the same class bound to a single delegate. */
// http://stackoverflow.com/questions/7678341/how-to-determine-which-uialertview-called-the-delegate
@interface SCKAlertView : UIAlertView <UIAlertViewDelegate>
{
    SCKAlertBlock _block;
}

+ (id)showWithTitle:(NSString *)title
            message:(NSString *)message
         usingBlock:(SCKAlertBlock)block
  cancelButtonTitle:(NSString *)cancelButtonTitle
  otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;

@end

