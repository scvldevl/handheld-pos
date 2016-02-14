//
//  VFIPinPadDelegate.h
//  ShoeCarnival
//
//  Created by Bill Monk on 8/21/12.
//  Copyright (c) 2012 Big Nerd Ranch. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <VMF/VMFramework.h>

extern NSString *VerifonePinPadDidReceiveDataNotification;
extern NSString *PinPadDataAsStringKey;

@interface VFIPinPadDelegate : NSObject <VFIPinpadDelegate>

@end
