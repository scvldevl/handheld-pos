/*
     File: TCPServer.h
 Abstract: A TCP server that listens on an arbitrary port.
  Version: 1.8
 
 
 Copyright (C) 2010 Apple Inc. All Rights Reserved.
 
 */

#import <Foundation/Foundation.h>

@class TCPServer;

NSString * const TCPServerErrorDomain;

typedef enum {
    kTCPServerCouldNotBindToIPv4Address = 1,
    kTCPServerCouldNotBindToIPv6Address = 2,
    kTCPServerNoSocketsAvailable = 3,
} TCPServerErrorCode;


@protocol TCPServerDelegate <NSObject>
@optional
- (void) serverDidEnableBonjour:(TCPServer*)server withName:(NSString*)name;
- (void) serverDidDisableBonjour:(TCPServer*)server withName:(NSString*)name;
- (void) server:(TCPServer*)server didNotEnableBonjour:(NSDictionary *)errorDict;
- (void) didAcceptConnectionForServer:(TCPServer*)server inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr;
@end


@interface TCPServer : NSObject <NSNetServiceDelegate> {
@private
	id _delegate;
    uint16_t _port;
	uint32_t protocolFamily;
	CFSocketRef _socket;
	NSNetService* _netService;
}
	
- (BOOL) start:(NSError **)error;
- (BOOL) stop;
- (BOOL) enableBonjourWithDomain:(NSString*)domain applicationProtocol:(NSString*)protocol name:(NSString*)name TXTRecordDictionary:(NSDictionary *)d; //Pass "nil" for the default local domain - Pass only the application protocol for "protocol" e.g. "myApp"
- (void) disableBonjour;
- (void) setTXTRecordWithDictionary:(NSDictionary *)d;

@property(assign) id<TCPServerDelegate> delegate;
@property(nonatomic,retain) NSNetService* netService;

+ (NSString*) bonjourTypeFromIdentifier:(NSString*)identifier;

@end
