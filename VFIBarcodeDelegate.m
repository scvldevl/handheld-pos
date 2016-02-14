//
//  VFIBarcodeDelegate.m
//  ShoeCarnival
//
//  Created by Bill Monk on 7/20/12.
//  Copyright (c) 2012 Big Nerd Ranch. All rights reserved.
//

#import "VFIBarcodeDelegate.h"
#import "VStore.h"

NSString *VerifoneBarcodeDidReceiveDataNotification = @"VerifoneBarcodeDidReceiveDataNotification";
NSString *BarcodeDataAsStringKey = @"BarcodeDataAsStringKey";

@implementation VFIBarcodeDelegate

//MARK: VFIBarcodeDelegate

- (void) barcodeConnected:(BOOL)isConnected {
    SPLog(@"barcodeConnected : %@", isConnected ? @"Yes" : @"No");
    DLog(@"barcodeConnected: %d", isConnected);
    
    static BOOL oneShotPerConnection = YES;

    if (isConnected) {
        if (oneShotPerConnection) {
            [[VStore sharedVStore] initializeConnectedBarcode]; 
            oneShotPerConnection = NO;
        }
    } else {
        oneShotPerConnection = NO;
    }
}

- (void) barcodeDataReceived:(NSData*)data {
    SPLog(@"barcodeDataReceived %u bytes", [data length]);
    DLog(@"barcodeDataReceived %lu bytes", (unsigned long)[data length]);

    NSString *barcodeDataAsString = [[VStore sharedVStore] nsdataToNSString:data]; 
    
    if ([barcodeDataAsString length] >= 2) {
        if ([[barcodeDataAsString substringToIndex:2] isEqualToString:@"06"]) {
            // Verifone sample code doesn't indicate what this case means... originally nothing was done here
        } else {
			
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject:barcodeDataAsString forKey:BarcodeDataAsStringKey];
			[[NSNotificationCenter defaultCenter] postNotificationName:VerifoneBarcodeDidReceiveDataNotification
																object:nil
															  userInfo:userInfo];
        }
    }
}

- (void) barcodeDataSent:(NSData*)data {
	//[miscText setText:[NSString stringWithFormat:@"BCSEND: %@\n%@", [[VStore sharedVStore] nsdataToNSString:data], miscText.text]]; 
}

- (void) barcodeScanData:(NSData*)data barcodeType:(int)barcodeType {
    DLog(@"barcodeScanData:%@\n of type:%d", [data description], barcodeType);
}

- (void) barcodeLogEntry:(NSString*)logEntry withSeverity:(int)severity {
    DLog(@"barcodeLogEntry: %@", logEntry);
}

- (void) barcodeTriggerEvent:(int)triggerCode {
    
    DLog(@"barcodeTriggerEvent: %d", triggerCode);
}


@end
