//
//  VFIBarcodeDelegate.h
//  ShoeCarnival
//
//  Created by Bill Monk on 7/20/12.
//  Copyright (c) 2012 Big Nerd Ranch. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <VMF/VMFramework.h>

extern NSString *VerifoneBarcodeDidReceiveDataNotification;
extern NSString *BarcodeDataAsStringKey;

@interface VFIBarcodeDelegate : NSObject <VFIBarcodeDelegate>

@end
