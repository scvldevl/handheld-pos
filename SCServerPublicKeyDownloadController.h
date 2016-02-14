//
//  SCServerPublicKeyDownloadController.h
//  ShoeCarnival
//
//  Created by Bill Monk on 9/25/12.
//  Copyright (c) 2012 Big Nerd Ranch. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SCServerPublicKeyDownloadController : NSObject <NSURLConnectionDataDelegate> {
    BOOL downloadInProgress;
    NSString *downloadHost;
}
@property (atomic, assign) BOOL downloadInProgress;         // atomic intentional; actually there is a potential state consistency issue with this class vs. the program at large, since key download is async but cards can be swied at any time...
@property (nonatomic, retain) NSString *downloadHost;


@property (nonatomic, retain) NSString *publicKey;

@property (nonatomic, readonly) NSString *publicKeyID;

+ (SCServerPublicKeyDownloadController *)sharedController;
- (void)initiatePublicKeyDownloadFromHost:(NSString *)host;


@end
