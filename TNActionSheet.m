//
//  TNActionSheet.m
//
//  Created by Bill Monk on 3/17/13.
//  Copyright (c) 2013 Big Nerd Ranch. All rights reserved.
//

#import "TNActionSheet.h"

@implementation TNActionSheet

+ (id)actionSheetWithTitle:(NSString *)title
                usingBlock:(TNActionSheetBlock)block
         cancelButtonTitle:(NSString *)cancelButtonTitle
    destructiveButtonTitle:(NSString *)destructiveButtonTitle
     firstOtherButtonTitle:(NSString *)firstOtherButtonTitle
      anyOtherButtonTitles:(va_list)anyOtherButtonTitles
{
    //
    // Create a sheet with no "other" buttons, then add them separately
    // if any button titles exist in firstOtherButtonTitle and anyOtherButtonTitles.
    TNActionSheet *sheet = [[TNActionSheet alloc] initWithTitle:title
                                                       delegate:nil
                                              cancelButtonTitle:cancelButtonTitle
                                         destructiveButtonTitle:destructiveButtonTitle
                                              otherButtonTitles:nil];
    sheet.delegate = sheet;
    sheet->_block = [block copy];
    
    for (NSString *buttonTitle = firstOtherButtonTitle; buttonTitle != nil; buttonTitle = va_arg(anyOtherButtonTitles, NSString *))
    {
        [sheet addButtonWithTitle:buttonTitle];
    }
    
    return sheet;
}

+ (id)showFromTabBar:(UITabBar *)tabBar
           withTitle:(NSString *)title
          usingBlock:(TNActionSheetBlock)block
   cancelButtonTitle:(NSString *)cancelButtonTitle
destructiveButtonTitle:(NSString *)destructiveButtonTitle
   otherButtonTitles:(NSString *)otherButtonTitles, ...
{
    va_list args;
	va_start(args, otherButtonTitles);
    
    // varargs are always a little fun...
    // After calling va_start(), otherButtonTitles is now the first NSString param, or nil.
    // For a little more clarity, we'll call this firstOtherButtonTitle, and
    // pass it and args (which points to any remaining vararg params), and the call-ee
    // will pull out any other button titles via va_arg().
    NSString *firstOtherButtonTitle = otherButtonTitles;
    
    TNActionSheet *sheet = [TNActionSheet actionSheetWithTitle:title
                                                    usingBlock:block
                                             cancelButtonTitle:cancelButtonTitle
                                        destructiveButtonTitle:destructiveButtonTitle
                                         firstOtherButtonTitle:firstOtherButtonTitle
                                          anyOtherButtonTitles:args];
    va_end(args);
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [sheet showFromTabBar:tabBar];
    }];
    
    return sheet;
}

+ (id)showFromRect:(CGRect)rect
            inView:(UIView *)view 
           withTitle:(NSString *)title
          usingBlock:(TNActionSheetBlock)block
   cancelButtonTitle:(NSString *)cancelButtonTitle
destructiveButtonTitle:(NSString *)destructiveButtonTitle
   otherButtonTitles:(NSString *)otherButtonTitles, ...
{
    va_list args;
	va_start(args, otherButtonTitles);
    
    // varargs are always a little fun...
    // After calling va_start(), otherButtonTitles is now the first NSString param, or nil.
    // For a little more clarity, we'll call this firstOtherButtonTitle, and
    // pass it and args (which points to any remaining vararg params), and the call-ee
    // will pull out any other button titles via va_arg().
    NSString *firstOtherButtonTitle = otherButtonTitles;
    
    TNActionSheet *sheet = [TNActionSheet actionSheetWithTitle:title
                                                    usingBlock:block
                                             cancelButtonTitle:cancelButtonTitle
                                        destructiveButtonTitle:destructiveButtonTitle
                                         firstOtherButtonTitle:firstOtherButtonTitle
                                          anyOtherButtonTitles:args];
    va_end(args);
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [sheet showFromRect:rect inView:view animated:YES];
    }];
    
    return sheet;
}

/* 
 // Someday implement all of these on the pattern of -showFromTabBar...
 - (void)showFromToolbar:(UIToolbar *)view;
 - (void)showFromTabBar:(UITabBar *)view;
 - (void)showFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated NS_AVAILABLE_IOS(3_2);
 - (void)showFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated NS_AVAILABLE_IOS(3_2);
 - (void)showInView:(UIView *)view;
 
 */

//MARK: - UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (_block)
    {
        _block(actionSheet, buttonIndex);
        _block = nil;
    }
}

@end