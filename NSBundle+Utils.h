//
//  NSBundle+Utils.h
//  GEForms3
//
//  Created by Bill Monk on 9/16/11.
//  Copyright 2011 Big Nerd Ranch. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSBundle (NSBundleUtils)
+ (NSString *)bundlePathForResourceName:(NSString *)aResourceName;
@end
