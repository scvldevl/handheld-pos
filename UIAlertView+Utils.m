//
//  UIAlertView+Utils.m
//  ShoeCarnival
//
//  Created by Bill Monk on 10/5/12.
//  Copyright (c) 2012 Big Nerd Ranch. All rights reserved.
//

#import "UIAlertView+Utils.h"

@implementation UIAlertView (Utils)

+ (void)displayAlertOnNextRunLoopInvocationWithTitle:(NSString *)title
                                             message:(NSString *)msg
                                            delegate:(id)del
                                   cancelButtonTitle:(NSString *)cancelBtnTitle
                                    otherButtonTitle:(NSString *)otherBtnTitle
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [[[[UIAlertView alloc] initWithTitle:title
                                     message:msg
                                    delegate:del
                           cancelButtonTitle:cancelBtnTitle
                           otherButtonTitles:otherBtnTitle, nil] autorelease] show];
    }];
}

@end

//MARK: - SCKAlertView

@implementation SCKAlertView

+ (id)showWithTitle:(NSString *)title
            message:(NSString *)message
         usingBlock:(SCKAlertBlock)block
  cancelButtonTitle:(NSString *)cancelButtonTitle
  otherButtonTitles:(NSString *)otherButtonTitles, ...
{
    SCKAlertView *alert = [[[SCKAlertView alloc] initWithTitle:title
                                                       message:message
                                                      delegate:nil
                                             cancelButtonTitle:cancelButtonTitle
                                            otherButtonTitles:nil] autorelease];
    
    alert.delegate = alert;
    alert->_block = [block copy];
    
    va_list args;
    va_start(args, otherButtonTitles);
    for (NSString *buttonTitle = otherButtonTitles; buttonTitle != nil; buttonTitle = va_arg(args, NSString*))
    {
        [alert addButtonWithTitle:buttonTitle];
    }
    va_end(args);
    
    [alert show];
    
    return alert;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (_block)
    {
        _block(alertView, buttonIndex);
    }
}

@end