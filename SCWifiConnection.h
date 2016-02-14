//
//  WifiConnection.h
//  GEForms3
//
//  Created by Bill Monk on 3/8/11.
//  Copyright 2011 Big Nerd Ranch. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface SCWifiConnection : NSObject <NSNetServiceBrowserDelegate, NSNetServiceDelegate> {
    NSMutableArray *netServices; 
    NSNetServiceBrowser *serviceBrowser; 
	
	NSNetService *selectedNetService;
	NSString *selectedServiceName;
    
    BOOL isSearching;
    BOOL isConnected;
}

- (void)startBrowsing;
- (void)stopBrowsing;

@property (nonatomic, assign) BOOL isSearching;
@property (nonatomic, assign) BOOL isConnected;
@end
