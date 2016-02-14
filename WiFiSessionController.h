//
//  WiFiSessionController.h
//  Based on Apple's EAAccessoryTest
//
//  Created by Bill Monk on 2/16/11.
//  Copyright 2011 Big Nerd Ranch. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *ReceivedNetworkDataFromWiFiServerNotification;
extern NSString *WiFiServerCameOnlineNotification;
extern NSString *WiFiServerWentOfflineNotification;

@interface WiFiSessionController : NSObject <NSStreamDelegate> {
	NSNetService *netService;
	NSString *serviceName;
	
	NSMutableData *_writeData;
    NSMutableData *_readData;

	NSInputStream *inputStream;
    NSOutputStream *outputStream;
	
	BOOL isOnline;
}

@property (nonatomic, readonly) NSNetService *netService;
@property (nonatomic, readonly) NSString *serviceName;
@property (nonatomic, retain) NSInputStream *inputStream;
@property (nonatomic, retain) NSOutputStream *outputStream;
@property (nonatomic, assign) BOOL isOnline;

+ (WiFiSessionController *)sharedController;

- (void)wifiLog:(NSString *)str;

- (void)setupControllerForNetService:(NSNetService *)aNetService withName:(NSString *)aName;

- (BOOL)openSession;
- (void)closeSession;

- (void)writeData:(NSData *)data;

- (NSUInteger)readBytesAvailable;
- (NSData *)readData:(NSUInteger)bytesToRead;


@end
