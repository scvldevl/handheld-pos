//
//  SCServerProtocolController.h
//  ShoeCarnival
//
//  Created by Bill Monk on 9/20/12.
//  Copyright (c) 2012 Big Nerd Ranch. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

// Notifications sent in response to incoming SC server messages
extern NSString *SCServerRequestsSignatureDataNotification;

extern NSString *SCServerRequestsPINDataNotification;
extern NSString *ServerRequestedAccountNumberStrKey;
extern NSString *SCServerRequestsEncryptionModeReset;
extern NSString *SCServerRequestsChangeCardScannerStateNotification;
extern NSString *ServerRequestedNewCardScanneStateKey;
//

@interface SCServerProtocolController : NSObject <NSStreamDelegate, GCDAsyncSocketDelegate>
{
    dispatch_queue_t socketQueue;
    GCDAsyncSocket *listenSocket;
    NSMutableArray *acceptedSockets;

    BOOL started;
}

- (BOOL)start;
- (void)stop;

+ (SCServerProtocolController *)sharedController;

- (void)sendCardData:(NSString *)str;
- (void)sendEncryptedCardData:(NSString *)str;
- (void)sendPINData:(NSString *)str;
- (void)sendSignatureData:(NSArray *)signaturePointsArray;
- (void)sendCancelledSignatureData;
- (void)sendTestString:(NSString *)str;

@end
