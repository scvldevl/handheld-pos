//
//  EAAccessoryManager+Utils.h
//  ShoeCarnival
//
//  Created by Bill Monk on 7/9/12.
//  Copyright 2012 Big Nerd Ranch. All rights reserved.
//

#import <Foundation/Foundation.h>
#import	<ExternalAccessory/ExternalAccessory.h>


@interface EAAccessoryManager (Utils)
+ (BOOL)accessoryProtocolExists:(NSString *)protocolString;
+ (void)logConnectedAccessories;
@end
