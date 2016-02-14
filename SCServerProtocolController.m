//
//  SCServerProtocolController.m
//  ShoeCarnival
//
//  Created by Bill Monk on 9/20/12.
//  Copyright (c) 2012 Big Nerd Ranch. All rights reserved.
//
#include <CoreFoundation/CoreFoundation.h>

#import "SCServerProtocolController.h"

#import "Scrawl.h"

#import "UIAlertView+Utils.h"

//
// Controller for message passing between iOS app and Shoe Carnival / ACR server
// over TCP port 600 using ACR protocol.
//
// A convenient way to exercise this without need of a server is to launch iOS side
// then in terminal issue
//
// nc -v <WiFi IP of iOS device> 600
//
//  At this point messages can be sent to iOS side by typing protocol messages in terminal
//  and viewing any return data there.
//
//  For instance typing SIG<return> messages iOS to put up a signature capture screen.
//  When this screen is dismissed, the app sends a SIGDATA: message out port 600 which
//  then appears in terminal.
//

NSString *SCServerRequestsSignatureDataNotification = @"SCServerRequestsSignatureDataNotification";

NSString *SCServerRequestsPINDataNotification = @"SCServerRequestsPINDataNotification";
NSString *ServerRequestedAccountNumberStrKey = @"ServerRequestedAccountNumberStrKey";
NSString *SCServerRequestsEncryptionModeReset = @"SCServerRequestsEncryptionModeReset";
NSString *SCServerRequestsChangeCardScannerStateNotification = @"SCServerRequestsChangeCardScannerStateNotification";
NSString *ServerRequestedNewCardScanneStateKey = @"ServerRequestedNewCardScanneStateKey";

@interface SCServerProtocolController ()
//- (void)writeData:(NSData *)data;
@end

typedef enum SCServerControlProtocolTag {
    // informational only (at this point anyway); these are just
    // set on various AsyncSocket read and write requests to document/indicate
    // the message being sent in the various messages
    kSCServerControlProtocolCardData = 1,
    kSCServerControlProtocolEncryptedCardData,
    kSCServerControlProtocolPINData,
    kSCServerControlProtocolSignatureData
} SCServerControlProtocolTag;

@implementation SCServerProtocolController

- (void)performPostSignatureRequestNotification:(NSDictionary *)userInfo
{
    printf("HI");
    [[NSNotificationCenter defaultCenter] postNotificationName:SCServerRequestsSignatureDataNotification object:userInfo];
}

- (void)performPostPinRequestNotification:(NSString *)requestedAccountNumberStr
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {

        // request PIN for account num
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:requestedAccountNumberStr, 
                                  ServerRequestedAccountNumberStrKey, 
                                  nil];
                
        [[NSNotificationCenter defaultCenter] postNotificationName:SCServerRequestsPINDataNotification
                                                            object:nil
                                                          userInfo:userInfo];
        }
    });
}
- (void)showSignatureUI
{
    SEL sel = @selector(performPostSignatureRequestNotification:);
    [self performSelectorOnMainThread:sel withObject:nil waitUntilDone:NO];
}

- (void)resetEncryptionMode
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SCServerRequestsEncryptionModeReset object:nil];
    });

}


//
//- (void)showSignatureUI
//{
//    NSLog(@"SIG DISPATCH SCHEDULING");
//
//    dispatch_async(dispatch_get_main_queue(), ^{
//        NSLog(@"SIG DISPATCH ENTER");
//    [[NSNotificationCenter defaultCenter] postNotificationName:SCServerRequestsSignatureDataNotification object:nil];
//        NSLog(@"SIG DISPATCH EXIT");
////        @autoreleasepool {
////            [self performSelector:@selector(performPostSignatureRequestNotification:) withObject:nil afterDelay:0.5];
////        }
//    });
//    NSLog(@"SIG DISPATCH SCHEDULING COMPLETE");
//}
//
- (void)postCardScannerEnableRequest:(BOOL)flag
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            
            // request VX600 card scanner to enable/dosable
            NSDictionary *userInfo;
            userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:flag],
                                                                  ServerRequestedNewCardScanneStateKey,
                                                                  nil];
            [[NSNotificationCenter defaultCenter] postNotificationName: SCServerRequestsChangeCardScannerStateNotification
                                                                object:nil
                                                              userInfo:userInfo];
        }
    });
}


//MARK: -

- (NSString *)formatSCServerProtocolSearchString:(NSString *)searchStr
{
#if defined(DEBUG) && DEBUG
    // for each of DEBUG testing via Terminal, omit sentinel byte
    // This makes it easier when doing
    // nc -v <iOS device IP> 600
    // and typing messages to the iOS port 600, no need to
    // hit CNTL-V CNTL-B before typing each message to type the protocol's
    // expected STX ascii char 0x02. 
    return searchStr; 
#endif
    // For live use, go ahead and include the STX in the search string;
    // the server will be sending it, and although we can ignore it and
    // still work fine, it's more reliable to look for the STX too
    return [NSString stringWithFormat:@"%c%@", 0x2, searchStr];
}
- (void)parseReceivedData:(NSData *)data
{
    char d[1024];
    memset(d,0,1024);

    memcpy(d, data.bytes, data.length);

    NSLog(@"***** PARSE RECEIVED DATA: [%s]", d);
	if (!data || ![data length]) {  // can happen when server quits or goes offline due to being killed in the debugger
		return;
	}
	
    NSData *strippedData = [[data copy] autorelease]; // don't bother looking for sentinels since we can use rangeOf...
    
    NSString *dataStr = [[[NSString alloc] initWithData:strippedData encoding:NSASCIIStringEncoding] autorelease];
    dataStr = [dataStr stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    
    //
    // ^BSWIPEON:<1,0>^C
    // turn VX600 card scanner on/off
    //
    NSString *searchStr = [self formatSCServerProtocolSearchString:@"SWIPEON:"];
    NSRange range = [dataStr rangeOfString:searchStr];
    if (range.location != NSNotFound) {
        DLog(@"%@", @"***** Swipeon?");
        
        unichar swipeOnFlag = 0x0;
        if ([dataStr length] > [searchStr length]) {
            swipeOnFlag = [[dataStr substringFromIndex:range.location + range.length] characterAtIndex:0];
        }


        if (swipeOnFlag == '1') {
            DLog(@"%@", @"***** SWIPEON: received flag 1, enabling card scanner");
            SPLog(@"%@", @"SWIPEON: received flag 1, enabling card scanner");
            [self postCardScannerEnableRequest:YES];
        } else if (swipeOnFlag == '0') {
            DLog(@"%@", @"***** SWIPEON: received flag 0, disabling card scanner");
            SPLog(@"%@", @"SWIPEON: received flag 0, disabling card scanner");
            [self postCardScannerEnableRequest:NO];
        } else {
            DLog(@"***** SWIPEON: received unrecognized flag:\"%c\", ignoring", swipeOnFlag);
            SPLog(@"SWIPEON: received un recognized flag: %c, ignoring", swipeOnFlag);
        }
        
        return;
    }

    NSLog(@"***** No swipe. Next command...");
    //
    // ^BSWIPE^C
    // Ignored by this app; server can send as a "ping" message
    //
    searchStr = [self formatSCServerProtocolSearchString:@"SWIPE"];
    range = [dataStr rangeOfString:searchStr];
    if (range.location != NSNotFound) {
        // New message added for ACR's purpose to ensure an established TCP connection to the device.
        // iOS app can ignore thismessage.  It is in the case of a VX600 hardware restart to ensure
        // that ACR software can receive a card swipe.  By sending this we'll establish the TCP
        // connection so that subsequent card swipes are received.
        DLog(@"%@", @"***** received SWIPE on port 600, ignoring per spec");
        return; // Ignored message; server may send this merely to ping our port
    }

    //
    // ^BRESET^C
    // Server requests us to re-download the public key.
    // Per conf-call of 5/23/13, if key does not exist,
    // this will now be interpreted as a request to set
    // VX600 to VSP encryption mode. Note VXs will not
    // honor this request unless they have separately had
    // VSP E2EE encryption activated on them.
    searchStr = [self formatSCServerProtocolSearchString:@"RESET:"];
    range = [dataStr rangeOfString:searchStr];
    if (range.location != NSNotFound) {

        [self resetEncryptionMode];
        return;
    }

    //
    // ^BSIG^C
    // Server requests a customer signature
    //
    searchStr = [self formatSCServerProtocolSearchString:@"SIG"];
    range = [dataStr rangeOfString:searchStr];
    if (range.location != NSNotFound) {
        // request signature data points
        DLog(@"%@", @"***** received SIG on port 600");
        [self showSignatureUI];
        return;
    }

    //
    // ^PIN:<account number as ascii digits>^C
    // Server requests a customer PIN associated with the supplied account #
    //
    searchStr = [self formatSCServerProtocolSearchString:@"PIN:"];
    //searchStr = @"PIN:";
    range = [dataStr rangeOfString:searchStr];
    if (range.location != NSNotFound) {
        DLog(@"%@", @"***** received PIN: on port 600");

        NSString *requestedAccountNumberStr = @"";
        if ([dataStr length] > [searchStr length]) {
            requestedAccountNumberStr = [dataStr substringFromIndex:range.location + range.length];
        }
        
        requestedAccountNumberStr = [requestedAccountNumberStr stringByTrimmingCharactersInSet:[NSCharacterSet controlCharacterSet]];
        requestedAccountNumberStr = [requestedAccountNumberStr stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        //requestedAccountNumberStr = [requestedAccountNumberStr stringByTrimmingCharactersInSet:[NSCharacterSet letterCharacterSet]];

        DLog(@"submitting PIN request for account:%@", requestedAccountNumberStr);

        // I want to serialize all these actions in response to port 600 messages
        [self performPostPinRequestNotification:requestedAccountNumberStr];
        return;
    }
    
    //
    // Other possible future messages
    //
    DLog(@"****** Message not recognized: %@", dataStr);
}

// MARK: -


- (NSData *)standardTrailer
{
    char trailer[] = { 0x03 };
    NSData *d = [NSData dataWithBytes:trailer length:1];
    return d;
}

// MARK: -
// MARK: Public Methods

- (void)sendCardData:(NSString *)str
{
    if (![acceptedSockets count]) {
        return;
    }
    NSMutableData *msg = [NSMutableData data];

    const int headerLength = 7;
    char header[] = { 0x02, 'S', 'W', 'I', 'P', 'E', ':' };
    [msg appendBytes:&header[0] length:headerLength];

    [msg appendData:[str dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES]];
    
    [msg appendData:[self standardTrailer]];
    for(GCDAsyncSocket *sock in acceptedSockets) {
        [sock writeData:msg withTimeout:120 tag:kSCServerControlProtocolCardData];
    }
}

- (void)sendEncryptedCardData:(NSString *)str
{
    if (![acceptedSockets count]) {
        return;
    }

    NSMutableData *msg = [NSMutableData data];

    const int headerLength = 11;
    char header[] = { 0x02, 'E', 'N', 'C', 'R', 'Y', 'P', 'T', 'E', 'D', ':' };
    [msg appendBytes:&header[0] length:headerLength];
    
    [msg appendData:[str dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES]];
    
    [msg appendData:[self standardTrailer]];

    for(GCDAsyncSocket *sock in acceptedSockets) {
        [sock writeData:msg withTimeout:120 tag:kSCServerControlProtocolEncryptedCardData];
    }
}

- (void)sendPINData:(NSString *)str
{
    if (![acceptedSockets count]) {
        return;
    }

    NSMutableData *msg = [NSMutableData data];

    const int headerLength = 5;
    char header[] = { 0x02, 'P', 'I', 'N', ':' };
    [msg appendBytes:&header[0] length:headerLength];
    
    [msg appendData:[str dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES]];
    
    [msg appendData:[self standardTrailer]];

    for(GCDAsyncSocket *sock in acceptedSockets) {
        [sock writeData:msg withTimeout:120 tag:kSCServerControlProtocolPINData];
    }
}

- (void)sendSignatureData:(NSArray *)signaturePointsArray
{
    if (![acceptedSockets count]) {
        return;
    }

    NSMutableData *msg = [NSMutableData data];

    const int headerLength = 9;
    char header[] = { 0x02, 'S', 'I', 'G', 'D', 'A', 'T', 'A', ':' };
    [msg appendBytes:&header[0] length:headerLength];
    
    // flipped (y,x) for landscape; may want to adjust according to current device rotation
    char width[] = { '0', '4', '8', '0' };
    [msg appendBytes:&width[0] length:4];
    
    char height[] = { '0', '3', '2', '0' };
    [msg appendBytes:&height[0] length:4];
    
    //
    // move points into an NSData as 3 ASCII char per (x,y) component
    // Round points to int, and send to SC server as 3 ASCII chars per value,
    // i.e. the point (1,320) will go out as 001320
    //
    // Probably want to flip oth the dimensions above and the points below to (y,x)
    // to represent landscape. Also need to make the sig screen rotate...
    //
    for (Scrawl *scrawl in signaturePointsArray) {
        const char *eolBuffer = { "000000" };
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSArray *thisLinePoints = [scrawl allScrawlPoints];
		for (NSValue *val in thisLinePoints) {
			NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
			CGPoint point = [val CGPointValue];
            int x = (int)roundf(point.x);
            int y = (int)roundf(point.y);
            
            // convert digits to ascii chars
			char components[7] = { 0,0,0,0,0,0,0 };

            /////// SCS
            sprintf(components, "%03d%03d", x, y);
//			components[0] = (x / 100) + 48;
//			components[1] = ((x % 100) / 10) + 48;
//			components[2] = ((x % 100) % 10) + 48;
//			components[3] = (y / 100) + 48;
//			components[4] = ((y % 100) / 10) + 48;
//			components[5] = ((y % 100) % 10) + 48;
            [msg appendBytes:&components[0] length:6];

			[innerPool drain];
			}
        [msg appendBytes:eolBuffer length:6];
		[pool drain];
	}
    
    [msg appendData:[self standardTrailer]];
    
    for(GCDAsyncSocket *sock in acceptedSockets) {
        [sock writeData:msg withTimeout:120 tag:kSCServerControlProtocolSignatureData];
    }
}

- (void)sendCancelledSignatureData
{
    if (![acceptedSockets count]) {
        return;
    }

    NSMutableData *msg = [NSMutableData data];
    
    const int headerLength = 9;
    char header[] = { 0x02, 'S', 'I', 'G', 'D', 'A', 'T', 'A', ':' };
    [msg appendBytes:&header[0] length:headerLength];

    [msg appendData:[self standardTrailer]];

    for(GCDAsyncSocket *sock in acceptedSockets) {
        [sock writeData:msg withTimeout:120 tag:kSCServerControlProtocolSignatureData];
    }
}


- (void)sendTestString:(NSString *)str
{
#if 0
    if (![acceptedSockets count]) {
        return;
    }

    SPLog(@"sending test text response via port 600, actual data will follow if possible");

    NSMutableData *msg = [NSMutableData data];
    [msg appendData:[@"TEST DATA " dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES]];
    
    [msg appendData:[str dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES]];
    
    [msg appendData:[self standardTrailer]];
    
    [[acceptedSockets objectAtIndex:0] writeData:msg withTimeout:120 tag:kSCServerControlProtocolCardData];
#endif
}

//MARK: -

static SCServerProtocolController *sharedInstance = nil;
+ (SCServerProtocolController *)sharedController
{
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
	if (sharedInstance != nil) {
		DLog(@"%@", @"Please use [SCServerProtocolController sharedController], not alloc/init");
		return sharedInstance;
	}
	
    self = [super init];
    if (self) {
        socketQueue = dispatch_queue_create("socketQueue", NULL);
        listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQueue]; 
        
        [listenSocket setAutoDisconnectOnClosedReadStream:NO]; // SC server (which is client on this port) wants to be able to disconnect from us by just closing its write stream (also see GCDAsyncSocket header docs for this method)
        
        acceptedSockets = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [listenSocket setDelegate:nil];
    [listenSocket disconnect];
    [listenSocket dealloc];
    dispatch_release(socketQueue);
    
    [acceptedSockets release];
    
    [super dealloc];
}

//MARK: -

- (BOOL)start
{
    DLog(@"***** Start Requested");

    @synchronized(self) {
        if(started)
            return YES;
        started = YES;
    }



    const int kSCServerControlProtocolPort = 600;
    NSString *kSCServerInterface = @"en0"; // only want wifi interface, not cellular or bluetooth
    NSError *error;
    if (![listenSocket acceptOnInterface:kSCServerInterface port:kSCServerControlProtocolPort error:&error]) {
        DLog(@"***** Socket accept failed on interface:%@ port:%d, error:%@", kSCServerInterface, kSCServerControlProtocolPort, [error localizedDescription]);
        
//        NSString *msg = [NSString stringWithFormat:@"Can't open listening port %d.\nWiFi enabled?", kSCServerControlProtocolPort];
//        [UIAlertView displayAlertOnNextRunLoopInvocationWithTitle:@"Listening Port Not open"
//                                                          message:msg
//                                                         delegate:nil
//                                                cancelButtonTitle:@"OK"
//                                                 otherButtonTitle:nil];

        return NO;
    }
    DLog(@"***** Socket Now Listening");
    return YES;
}

 -(void)stop
{
    DLog(@"***** Socket Listening Finished");
    [listenSocket disconnect];
    started = NO;
}

//MARK: -

#define FORMAT(format, ...) [NSString stringWithFormat:(format), ##__VA_ARGS__]

- (void)log:(NSString *)str
{
	dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
            
			DLog(@"%@", str);
            
		}
	});
}

//MARK: -
// GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket;
{
    @synchronized(acceptedSockets) {
        [acceptedSockets addObject:newSocket];
    }
    
    NSString *host = [newSocket connectedHost];
	UInt16 port = [newSocket connectedPort];
	
    [self log:FORMAT(@"%@:%d accepted client %@:%hu", [newSocket localHost], [newSocket localPort], host, port)];

    [newSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port;
{
    [self log:FORMAT(@"async socket did connect to host:%@ on port:%d", host, port)];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag;
{
//    NSLog(@"***** SOCKET RECEIVED %d BYTES OF DATA [%s]", data.length, data.bytes );
    [self parseReceivedData:data];
    // This method is executed on the socketQueue (not the main thread)
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		@autoreleasepool {
            [sock readDataWithTimeout:-1 tag:0];
        }
    });
}

- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag;
{
    [self log:FORMAT(@"async socket didReadPartialDataOfLength:%lu", (unsigned long)partialLength)];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)error;
{
    if (sock != listenSocket)
	{
        [self log:FORMAT(@"socketDidDisconnect:%@", [error localizedDescription])];
		
		@synchronized(acceptedSockets)
		{
			[acceptedSockets removeObject:sock];
		}
	}
    
	dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
            
			[self performSelector:@selector(start) withObject:nil afterDelay:1.0];
            
		}
	});
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag;
{
    //[self log:FORMAT(@"didWriteDataWithTag:%d", tag)];
}

- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag;
{
    [self log:FORMAT(@"Did write to SCServer:%lu bytes with tag:%ld", (unsigned long)partialLength, tag)];
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length;
{
    [self log:FORMAT(@"Write to SCServer timed out after:%f seconds, bytesDone:%lu", elapsed, (unsigned long)length)];
    return 0.0;
}


@end
