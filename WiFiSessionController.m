//
//  WiFiSessionController.m
//  Based on Apple's EAAccessoryTest
//
//  Created by Bill Monk on 2/16/11.
//  Copyright 2011 Big Nerd Ranch. All rights reserved.
//

#import "WiFiSessionController.h"


@implementation WiFiSessionController

NSString *ReceivedNetworkDataFromWiFiServerNotification = @"ReceivedNetworkDataFromWiFiServerNotification";
NSString *WiFiServerCameOnlineNotification = @"WiFiServerCameOnlineNotification";
NSString *WiFiServerWentOfflineNotification = @"WiFiServerWentOfflineNotification";

@synthesize netService, serviceName;
@synthesize inputStream, outputStream;
@synthesize isOnline;

- (void)wifiLog:(NSString *)str
{
	if (!self.outputStream || ![self.outputStream hasSpaceAvailable]) {
#if LOG_TO_WIFI
        NSLog(@"Wifi logging outputStream not ready, remote terminal running?");
#endif
		return;
	}
	    
	NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0; // smaller than kCFPropertyListXMLFormat_v1_0; highly recommended for network use by Apple in WWDC 2010 Session 108
	if (![NSPropertyListSerialization propertyList:str isValidForFormat:format]) {
        // shoud never happen
        NSString *errStr = [NSString stringWithFormat:@"%@ can't send data to Bonjour stream, invalid property list %@ for format:%lu", [self description], str, (unsigned long)format];
		NSLog(@"%@", errStr);
        str = errStr; // try to send the errStr out wifi!
	}
    
	if (!outputStream) {
		NSLog(@"outputStream is nil in wifiLogString");
	}
	else {
		NSError *error;
		NSInteger bytesWritten = [NSPropertyListSerialization writePropertyList:str toStream:outputStream format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
		if (bytesWritten == 0) 
		{
			NSLog(@"wifiLogString failed, error:%@", [error description]);
			if ([[error domain] isEqualToString:NSPOSIXErrorDomain] && [error code] == 32) {
				// broken pipe; client on other side probably quit; TODO: there may be other errors indicating similar problems
				
				// restart server? No, that would terminate other active Bonjour connections.
				// probably just drop this client object (which is ourself at the moment of the error) from array of clients. 
				NSLog(@"%@ is offline, closing connection. Try relaunching the Bonjour client iOS device.", [self description]);
			}
		}
		else {
			//NSLog(@"WiFi %@ attempting to write %u bytes to Bonjour stream %@", [self description], bytesWritten, [outputStream description]);
		}
	}
}


- (void)validateAndForwardData:(NSData *)data
{
#define kVerboseWiFiSessionLogging 0
	
	if (!data || ![data length]) {  // can happen when server quits or goes offline due to being killed in the debugger
		return;
	}
	
	NSError *error;
	NSPropertyListFormat format = 0;
	NSDictionary *dict = [NSPropertyListSerialization propertyListWithData:data options:0 format:&format error:&error];
	if (!dict) {
		NSLog(@"bad data received. NSPropertyListSerialization reports:%@", [error description]);
	}
	else {		
		NSString *dataType = [dict objectForKey:@"dataType"];
		
		if ([dataType isEqualToString:@"MicroridgeGageRelayData"]) 
		{
#if kVerboseWiFiSessionLogging
			NSLog(@"received property list appears to be microridge data, dataType:%@", dataType);
#endif
			
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:dict, @"microridgeDataDictionary", nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:ReceivedNetworkDataFromWiFiServerNotification object:self userInfo:userInfo];
		}
		if ([dataType isEqualToString:@"MicroridgeGageNotificationData"]) 
		{
			//NSLog(@"received property list appears to be microridge notification data, dataType:%@", dataType);
			
			NSError *e = [NSError errorWithDomain:@"MicroridgeGageServerError" code:1 userInfo:dict];
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:e, @"error", nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:WiFiServerWentOfflineNotification object:self userInfo:userInfo];
		}
		else 
		{
			NSLog(@"this property list does NOT appear to be microridge data, dataType:%@", dataType);	
		}
		
#if kVerboseWiFiSessionLogging
		NSLog(@"received NSPropertyListSerialization format %d property list data from server:%@", format, [dict description]);	
#endif
		
	}

}					  

// MARK: -

// low level write method - write data to the accessory while there is space available and data to write
- (void)_writeData
{
    while (([[self outputStream] hasSpaceAvailable]) && ([_writeData length] > 0))
    {
        NSInteger bytesWritten = [[self outputStream] write:[_writeData bytes] maxLength:[_writeData length]];
        if (bytesWritten == -1)
        {
            NSLog(@"WiFiSessionController write error");
            break;
        }
        else if (bytesWritten > 0)
        {
			[_writeData replaceBytesInRange:NSMakeRange(0, bytesWritten) withBytes:NULL length:0];
        }
    }
}

// low level read method - read data while there is data and space available in the input buffer
- (void)_readData
{
#define EAD_INPUT_BUFFER_SIZE 128
    uint8_t buf[EAD_INPUT_BUFFER_SIZE];
    while ([[self inputStream] hasBytesAvailable])
    {
        NSInteger bytesRead = [[self inputStream] read:buf maxLength:EAD_INPUT_BUFFER_SIZE];
        if (_readData == nil) {
            _readData = [[NSMutableData alloc] init];
        }
        [_readData appendBytes:(void *)buf length:bytesRead];
    }

	//NSLog(@"read %d bytes from input stream", [_readData length]);

	NSData *data = [[_readData copy] autorelease];
	[self validateAndForwardData:data];
	[_readData setLength:0];
	
}

// MARK: -
// MARK: Public Methods

+ (WiFiSessionController *)sharedController
{
    static WiFiSessionController *sessionController = nil;
    if (sessionController == nil) {
        sessionController = [[WiFiSessionController alloc] init];
    }
	
    return sessionController;
}


- (void)dealloc
{
    [self closeSession];
    [netService release];
    [serviceName release];
	
    [super dealloc];
}


- (void)setupControllerForNetService:(NSNetService *)aNetService withName:(NSString *)aName
{
    [netService release];
    netService = [aNetService retain];
    [serviceName release];
    serviceName = [aName retain];
}


- (void)stopStreams
{
	[self setIsOnline:NO];
	
	[[self inputStream] close];
	[[self inputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[[self inputStream] setDelegate:nil];
	[self setInputStream:nil];
	
	[[self outputStream] close];
	[[self outputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[[self outputStream] setDelegate:nil];
	[self setOutputStream:nil];
	
	[_writeData release];
	_writeData = nil;
	[_readData release];
	_readData = nil;
}

- (void)connectToInputStream:(NSInputStream *)inStream
				outputStream:(NSOutputStream *)outStream 
{    
    [self setInputStream:inStream];
    [inStream setDelegate:self];
    [inStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [inStream open];
    
    [self setOutputStream:outStream];
    [outStream setDelegate:self];
    [outStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outStream open];
}


// open a session with the accessory and set up the input and output stream on the default run loop
- (BOOL)openSession
{    
	// need to close existing streams
    [self stopStreams];

	// note getInputStream:outputStream: returns inStream and outStream with a retain count that the caller must eventually release.
	// To accomdate ARC, we now let it to store the retained object pointers into local vars, then put those into our instance vars
    NSInputStream *tempInputStream = nil;
    NSOutputStream *tempOutputStream = nil;
	if([[self netService] getInputStream:(NSInputStream * __strong *)&tempInputStream outputStream:(NSOutputStream * __strong *)&tempOutputStream]) 
	{
        inputStream = tempInputStream;
        outputStream = tempOutputStream;
        
		//NSLog( @"got streams for addresses:%@ on port:%d", [[[self netService] addresses] description], [[self netService] port] );
				
        [self connectToInputStream:inputStream outputStream:outputStream];
		[self setIsOnline:YES];
		[[NSNotificationCenter defaultCenter] postNotificationName:WiFiServerCameOnlineNotification object:self userInfo:nil];

		return YES;
    }
    else
    {
		[self stopStreams];
       // NSLog(@"creating streams failed");
    }
	
    return NO;
}

// close the session with the accessory.
- (void)closeSession
{
	[self stopStreams];
	
    [netService release];
    netService = nil;
	[serviceName release];
	serviceName = nil;
}


// high level write data method
- (void)writeData:(NSData *)data
{
    if (!outputStream) {
        return;
    }

    if (_writeData == nil) {
        _writeData = [[NSMutableData alloc] init];
    }
	
    [_writeData appendData:data];
    [self _writeData];
}


// high level read method 
- (NSData *)readData:(NSUInteger)bytesToRead
{
    NSData *data = nil;
    if ([_readData length] >= bytesToRead) {
        NSRange range = NSMakeRange(0, bytesToRead);
        data = [_readData subdataWithRange:range];
		[_readData setLength:0L];
    }
    return data;
}


// get number of bytes read into local buffer
- (NSUInteger)readBytesAvailable
{
    return [_readData length];
}

// MARK: -
// MARK: NSStreamDelegate methods

- (void)performNotifyWiFiServerWentOfflineNotification:(NSDictionary *)userInfo {
	[[NSNotificationCenter defaultCenter] postNotificationName:WiFiServerWentOfflineNotification object:nil userInfo:userInfo];
}

// asynchronous NSStream handleEvent method
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventNone:
            break;
        case NSStreamEventOpenCompleted:
            break;
			
        case NSStreamEventHasBytesAvailable:
            [self _readData];
            break;
			
        case NSStreamEventHasSpaceAvailable:
            [self _writeData];
            break;
			
        case NSStreamEventErrorOccurred:
			{
				[self stopStreams];
				NSError *e = [aStream streamError];
				NSLog(@"NSStreamEventErrorOccurredL%@", [e description]);
				NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:e, @"error", nil];
				// don't forget we're on a background thread in this method.
				//[[NSNotificationCenter defaultCenter] postNotificationName:WiFiServerWentOfflineNotification object:self userInfo:userInfo];
				[self performSelectorOnMainThread:@selector(performNotifyWiFiServerWentOfflineNotification:) withObject:userInfo waitUntilDone:NO];
			}
            break;
			
        case NSStreamEventEndEncountered:
			[self stopStreams];
			// don't forget we're on a background thread in this method.
			//[[NSNotificationCenter defaultCenter] postNotificationName:WiFiServerWentOfflineNotification object:self userInfo:nil];
			[self performSelectorOnMainThread:@selector(performNotifyWiFiServerWentOfflineNotification:) withObject:nil waitUntilDone:NO];
			break;
        default:
            break;
    }
}


@end
