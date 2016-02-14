//
//  EAAccessoryManager+Utils.m
//  ShoeCarnival
//
//  Created by Bill Monk on 7/9/12.
//  Copyright 2012 Big Nerd Ranch. All rights reserved.
//

#import "EAAccessoryManager+Utils.h"


@implementation EAAccessoryManager (Utils)

+ (BOOL)accessoryProtocolExists:(NSString *)protocolString 
{
	NSArray *accessories = [[EAAccessoryManager sharedAccessoryManager] connectedAccessories];    
	for (EAAccessory *accessory in accessories) {
		if ([[accessory protocolStrings] containsObject:protocolString]){
			return YES;
		}
	}
	return NO; 
}

+ (void)logConnectedAccessories
{
	/*
	 @property(nonatomic, readonly) NSUInteger connectionID __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
	 @property(nonatomic, readonly) NSString *manufacturer __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
	 @property(nonatomic, readonly) NSString *name __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
	 @property(nonatomic, readonly) NSString *modelNumber __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
	 @property(nonatomic, readonly) NSString *serialNumber __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
	 @property(nonatomic, readonly) NSString *firmwareRevision __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
	 @property(nonatomic, readonly) NSString *hardwareRevision __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);

	 */
	NSArray *accessories = [[EAAccessoryManager sharedAccessoryManager] connectedAccessories];    
	for (EAAccessory *accessory in accessories) {
		DLog(@"Found EAAccessory with connectionID:%lu\n, manufacturer:%@\n, name:%@\n, modelNumber:%@\n, serialNumber:%@\n, firmwareRevision:%@\n isConnected:%d\n\n", (unsigned long)[accessory connectionID], 
			 [accessory manufacturer], 
			 [accessory name], 
			 [accessory modelNumber],
			 [accessory serialNumber],
			 [accessory firmwareRevision],
			 [accessory isConnected]
			 );
		for (NSString *protocol in [accessory protocolStrings]) {
			DLog(@"EAAccessory has protcol:%@\n", protocol);
		}
	}
}

@end
