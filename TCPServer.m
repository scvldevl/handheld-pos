/*
     File: TCPServer.m
 Abstract: A TCP server that listens on an arbitrary port.
  Version: 1.8
 
 
 Copyright (C) 2010 Apple Inc. All Rights Reserved.
 
 */

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <MobileCoreServices/MobileCoreServices.h>

#import "TCPServer.h"

NSString * const TCPServerErrorDomain = @"TCPServerErrorDomain";

@interface TCPServer ()
@property(assign) uint16_t port;
@end

@implementation TCPServer

@synthesize delegate=_delegate, netService=_netService, port=_port;

- (id)init {
    return self;
}

- (void)dealloc {
    [self stop];
    [super dealloc];
}

- (void)handleNewConnectionFromAddress:(NSData *)addr inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr {
    // if the delegate implements the delegate method, call it  
    if (self.delegate && [self.delegate respondsToSelector:@selector(didAcceptConnectionForServer:inputStream:outputStream:)]) { 
        [self.delegate didAcceptConnectionForServer:self inputStream:istr outputStream:ostr];
    }
}

// This function is called by CFSocket when a new connection comes in.
// We gather some data here, and convert the function call to a method
// invocation on TCPServer.
static void TCPServerAcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    TCPServer *server = (TCPServer *)info;
    if (kCFSocketAcceptCallBack == type) { 
        // for an AcceptCallBack, the data parameter is a pointer to a CFSocketNativeHandle
        CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
        uint8_t name[SOCK_MAXADDRLEN];
        socklen_t namelen = sizeof(name);
        NSData *peer = nil;
        if (0 == getpeername(nativeSocketHandle, (struct sockaddr *)name, &namelen)) {
            peer = [NSData dataWithBytes:name length:namelen];
        }
        CFReadStreamRef readStream = NULL;
		CFWriteStreamRef writeStream = NULL;
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &readStream, &writeStream);
        if (readStream && writeStream) {
            CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            [server handleNewConnectionFromAddress:peer inputStream:(NSInputStream *)readStream outputStream:(NSOutputStream *)writeStream];
        } else {
            // on any failure, need to destroy the CFSocketNativeHandle 
            // since we are not going to use it any more
            close(nativeSocketHandle);
        }
        if (readStream) CFRelease(readStream);
        if (writeStream) CFRelease(writeStream);
    }
}

- (BOOL)start:(NSError **)errorPtr {

    CFSocketContext socketCtxt = {0, self, NULL, NULL, NULL};	

	// Start by trying to do everything with IPv6.  This will work for both IPv4 and IPv6 clients 
    // via the miracle of mapped IPv4 addresses.	

    _socket = CFSocketCreate(kCFAllocatorDefault, PF_INET6, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)&TCPServerAcceptCallBack, &socketCtxt);
	
	if (_socket != NULL)	// the socket was created successfully
	{
		protocolFamily = PF_INET6;
	} 
    else // there was an error creating the IPv6 socket - could be running under iOS 3.x
	{
		_socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)&TCPServerAcceptCallBack, &socketCtxt);
		if (_socket != NULL)
		{
			protocolFamily = PF_INET;
		}
	}

    if (NULL == _socket) {
        if (errorPtr) *errorPtr = [[NSError alloc] initWithDomain:TCPServerErrorDomain code:kTCPServerNoSocketsAvailable userInfo:nil];
        if (_socket) CFRelease(_socket);
        _socket = NULL;
        return NO;
    }
	
	
    int yes = 1;
    int result = setsockopt(CFSocketGetNative(_socket), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));
	if (result != 0) {
        NSLog(@"setsockopt failed, errno:%d, %s", errno, strerror(errno));
        if (errorPtr) *errorPtr = [[NSError alloc] initWithDomain:TCPServerErrorDomain code:kTCPServerNoSocketsAvailable userInfo:nil];
        return NO;
    }
    
    const int SC_TCP_PORT = 600;
    
	// set up the IP endpoint
	if (protocolFamily == PF_INET6)
	{
		struct sockaddr_in6 addr6;
		memset(&addr6, 0, sizeof(addr6));
		addr6.sin6_len = sizeof(addr6);
		addr6.sin6_family = AF_INET6;
		addr6.sin6_port = SC_TCP_PORT;
		addr6.sin6_flowinfo = 0;
		addr6.sin6_addr = in6addr_any;
		NSData *address6 = [NSData dataWithBytes:&addr6 length:sizeof(addr6)];
		
		if (kCFSocketSuccess != CFSocketSetAddress(_socket, (CFDataRef)address6)) {
			if (errorPtr) {
                *errorPtr = [[NSError alloc] initWithDomain:TCPServerErrorDomain code:kTCPServerCouldNotBindToIPv6Address userInfo:nil];
            }
			if (_socket) CFRelease(_socket);
			_socket = NULL;
			return NO;
		}
		
		// now that the binding was successful, we get the port number 
		// -- we will need it for the NSNetService
		NSData *addr = [(NSData *)CFSocketCopyAddress(_socket) autorelease];
		memcpy(&addr6, [addr bytes], [addr length]);
		[self setPort:ntohs(addr6.sin6_port)];
		
	} else {
		struct sockaddr_in addr4;
		memset(&addr4, 0, sizeof(addr4));
		addr4.sin_len = sizeof(addr4);
		addr4.sin_family = AF_INET;
		addr4.sin_port = SC_TCP_PORT;
		addr4.sin_addr.s_addr = htonl(INADDR_ANY);
		NSData *address4 = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];
		
		if (kCFSocketSuccess != CFSocketSetAddress(_socket, (CFDataRef)address4)) {
			if (errorPtr) *errorPtr = [[NSError alloc] initWithDomain:TCPServerErrorDomain code:kTCPServerCouldNotBindToIPv4Address userInfo:nil];
			if (_socket) CFRelease(_socket);
			_socket = NULL;
			return NO;
		}
		
		// now that the binding was successful, we get the port number 
		// -- we will need it for the NSNetService
		NSData *addr = [(NSData *)CFSocketCopyAddress(_socket) autorelease];
		memcpy(&addr4, [addr bytes], [addr length]);
		[self setPort:ntohs(addr4.sin_port)];
	}
	
    // set up the run loop sources for the sockets
    CFRunLoopRef cfrl = CFRunLoopGetCurrent();
    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0);
    CFRunLoopAddSource(cfrl, source, kCFRunLoopCommonModes);
    CFRelease(source);
	
    return YES;
}

- (BOOL)stop {
    [self disableBonjour];

	if (_socket) {
		CFSocketInvalidate(_socket);
		CFRelease(_socket);
		_socket = NULL;
	}
	
	
    return YES;
}

- (void)setTXTRecordWithDictionary:(NSDictionary *)d
{
	// The dictionary must be properly formattted for a TXT record:
	// keys can be anything desired (and understood by the peer)
	// and the objects must be NSData, each containing a UTF8 string 
	// containing the text value for each key
	NSData *TXTRecordData = [NSNetService dataFromTXTRecordDictionary:d]; 
	[_netService setTXTRecordData:TXTRecordData]; 
}

- (BOOL) enableBonjourWithDomain:(NSString*)domain applicationProtocol:(NSString*)protocol name:(NSString*)name TXTRecordDictionary:(NSDictionary *)txtRecordDict
{
	if(![domain length])
		domain = @""; //Will use default Bonjour registration doamins, typically just ".local"
	if(![name length])
		name = @""; //Will use default Bonjour name, e.g. the name assigned to the device in iTunes
	
	if(!protocol || ![protocol length] || _socket == NULL)
		return NO;
	

	[self setNetService:[[[NSNetService alloc] initWithDomain:domain type:protocol name:name port:[self port]] autorelease]];
	if([self netService] == nil)
		return NO;
	
	if (txtRecordDict) {
		[self setTXTRecordWithDictionary:txtRecordDict];
	}
	
	[[self netService] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[[self netService] publish];
	[[self netService] setDelegate:self];
	
	return YES;
}

/*
 Bonjour will not allow conflicting service instance names (in the same domain), and may have automatically renamed
 the service if there was a conflict.  We pass the name back to the delegate so that the name can be displayed to
 the user.
 See http://developer.apple.com/networking/bonjour/faq.html for more information.
 */

- (void)netServiceDidPublish:(NSNetService *)sender
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(serverDidEnableBonjour:withName:)])
		[self.delegate serverDidEnableBonjour:self withName:sender.name];
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
	if (self.delegate && [self.delegate respondsToSelector:@selector(server:didNotEnableBonjour:)])
		[self.delegate server:self didNotEnableBonjour:errorDict];
}

- (void)netServiceDidStop:(NSNetService *)sender
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(serverDidDisableBonjour:withName:)])
		[self.delegate serverDidDisableBonjour:self withName:sender.name];
}

- (void) disableBonjour
{
	if ([self netService]) {
		NSLog(@"about to call NetService:stop");
		[[self netService] stop];
		[[self netService] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
		[self setNetService:nil];
	}
}

- (NSString*) description
{
	return [NSString stringWithFormat:@"<%@ = 0x%08X | port %d | netService = %@>", [self class], (long)self, [self port], [self netService]];
}

+ (NSString*) bonjourTypeFromIdentifier:(NSString*)identifier {
	if (![identifier length])
		return nil;
    
    return [NSString stringWithFormat:@"_%@._tcp.", identifier];
}

@end
