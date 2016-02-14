//
//  TNAlertView.m
//  TravelNevada
//
//  Created by Bill Monk on 3/17/13.
//  Copyright (c) 2013 Big Nerd Ranch. All rights reserved.
//

#import "TNAlertView.h"

//MARK: - TNAlertView

@implementation TNAlertView

+ (id)showWithTitle:(NSString *)title
            message:(NSString *)message
         usingBlock:(TNAlertBlock)block
  cancelButtonTitle:(NSString *)cancelButtonTitle
  otherButtonTitles:(NSString *)otherButtonTitles, ...
{
    TNAlertView * alert = [[TNAlertView alloc] initWithTitle:title
                                                     message:message
                                                    delegate:nil
                                           cancelButtonTitle:cancelButtonTitle
                                           otherButtonTitles:nil];
    alert.delegate = alert;
    alert->_block = [block copy];
    
    va_list args;
    va_start(args, otherButtonTitles);
    for (NSString *buttonTitle = otherButtonTitles; buttonTitle != nil; buttonTitle = va_arg(args, NSString*))
    {
        [alert addButtonWithTitle:buttonTitle];
    }
    va_end(args);
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [alert show];
    }];
    
    return alert;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (_block)
    {
        _block(alertView, buttonIndex);
        _block = nil;
    }
}

@end

