//
//  SCWifiConnection.m
//  GEForms3
//
//  Created by Bill Monk on 3/8/11.
//  Copyright 2011 Big Nerd Ranch. All rights reserved.
//

#import "SCWifiConnection.h"
#import "WiFiSessionController.h"

@implementation SCWifiConnection
@synthesize isSearching, isConnected;

- (id)init 
{ 
    self = [super init];
	if (self) {
		netServices = [[NSMutableArray alloc] init]; 
		serviceBrowser = [[NSNetServiceBrowser alloc] init];
		
		[serviceBrowser setDelegate:self]; 
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverWentOffline:) name:WiFiServerWentOfflineNotification object:nil];
	}
    return self; 
} 

// MARK: -

// WiFiServerWentOfflineNotification
- (void)serverWentOffline:(NSNotification *)note
{
	[[WiFiSessionController sharedController] closeSession];
	[[WiFiSessionController sharedController] setupControllerForNetService:nil withName:nil]; 
    isConnected = NO;

    SPLog(@"Wifi logging server went offline, starting new search for server");
	[self performSelector:@selector(startBrowsing) withObject:nil afterDelay:0.0];
}


- (void)startBrowsing
{
	// Bonjour application protocol, which must match the MicroridgeGageServer, and:
	// 1) be no longer than 14 characters
	// 2) contain only lower-case letters, digits, and hyphens
	// 3) begin and end with lower-case letter or digit
	// It should also be descriptive and human-readable
	// See the following for more information:
	// http://developer.apple.com/networking/bonjour/faq.html
#define kMicroridgeRelayServerIdentifier @"microridgegage"

    if (isSearching) {
        return;
    }
    
    NSString *protocolString = [NSString stringWithFormat:@"_%@._tcp.", kMicroridgeRelayServerIdentifier];
	[serviceBrowser searchForServicesOfType:protocolString 
                                   inDomain:@""]; 
}


- (void)stopBrowsing
{
	// Called by app delegate when app resigns active
	[serviceBrowser stop];
}


- (NSDictionary *)TXTDictionaryForNetService:(NSNetService *)ns
{
	NSMutableDictionary *resultDictionary = [NSMutableDictionary dictionary];
	
    // Try to get the TXT Record  (no TXT data in unresolved services) 
    NSData *data = [ns TXTRecordData]; 
    if (data) 
	{ 
		NSString *message = @"<No Message>";
		
		// Get the data that the BT server added for the message key 
        NSDictionary *txtDict = [NSNetService dictionaryFromTXTRecordData:data]; 
        NSData *data = [txtDict objectForKey:@"message"]; 
        if (data) { 
            message = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]; 
        } 
		[resultDictionary setObject:message forKey:@"message"]; 
		
        data = [txtDict objectForKey:@"version"]; 
        if (data) { 
            NSString *version = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]; 
			[resultDictionary setObject:version forKey:@"version"]; 
        } 
    } 
	
	return resultDictionary;
}


// MARK: -
// MARK: NSNetService delegate methods

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser 
           didFindService:(NSNetService *)aNetService 
               moreComing:(BOOL)moreComing 
{ 
    NSLog(@"adding bonjour service %@", [aNetService description]); 
    [netServices addObject:aNetService]; 

    // Start resolution to get TXT record 
    [aNetService setDelegate:self]; 
    [aNetService resolveWithTimeout:30]; 
} 


- (void)netServiceDidResolveAddress:(NSNetService *)aService 
{
    //SPLog(@"resolved to Bonjour on:%@", [aService name]);
    
	NSDictionary *TXTDict = [self TXTDictionaryForNetService:aService];
    NSString *message = [TXTDict objectForKey:@"message"]; 
    NSString *version = [TXTDict objectForKey:@"version"]; 
	message = [message stringByAppendingFormat:@" vers:%@", version];

	// need an array of session controllers? We don't expect a multitude of microridge servers,
	// but there's really no reason it couldn't happen in or shouldn't work. 
	[self performSelector:@selector(stopBrowsing) withObject:nil afterDelay:0.0];
	
	[[WiFiSessionController sharedController] setupControllerForNetService:aService withName:message]; 
	if ([[WiFiSessionController sharedController] openSession]) {
        isConnected = YES;
        NSString *msg = [NSString stringWithFormat:@"WiFi Logging Connected to Bonjour on:%@", [aService name]];
        [[WiFiSessionController sharedController] performSelector:@selector(wifiLog:) withObject:msg afterDelay:2.0];
        SPLog(msg);
    }
}


- (void)netServiceBrowser:(NSNetServiceBrowser *)browser 
         didRemoveService:(NSNetService *)aNetService 
               moreComing:(BOOL)moreComing 
{ 
    NSLog(@"Bonjour service was lost: %@", aNetService); 
    [netServices removeObject:aNetService]; 
	
	if ([[[WiFiSessionController sharedController] netService] isEqual:aNetService]) {
		[[WiFiSessionController sharedController] closeSession];
        isConnected = NO;
        SPLog(@"WiFi Logging disconnecting from Bonjour");
	}
	
}

//MARK: -

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser {
    isSearching = YES;
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser {
    isSearching = NO;
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict {
    isSearching = NO;
}


//MARK: -

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[netServices release];
	[serviceBrowser setDelegate:nil];
	[serviceBrowser release];
	[selectedNetService release];
	[selectedServiceName release];
	
    [super dealloc];
}


@end
