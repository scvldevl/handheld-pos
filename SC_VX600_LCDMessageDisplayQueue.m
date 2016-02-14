//
//  SC_VX600_LCDMessageDisplayQueue.m
//  ShoeCarnival
//
//  Created by Bill Monk on 10/3/12.
//  Copyright (c) 2012 Big Nerd Ranch. All rights reserved.
//

#import "SC_VX600_LCDMessageDisplayQueue.h"

#import "VStore.h"

//
// Set a message on the VX600 4-line LCD
// using a serial queue to control display order and duration
//

@implementation SC_VX600_LCDMessageDisplayQueue

- (void)performSetMessage:(NSDictionary *)dict
{
    NSString *line1 = [dict objectForKey:@"line1"];
    NSString *line2 = [dict objectForKey:@"line2"];
    NSString *line3 = [dict objectForKey:@"line3"];
    NSString *line4 = [dict objectForKey:@"line4"];
    
    [[[VStore sharedVStore] pinPad] displayMessages:line1
                                              Line2:line2
                                              Line3:line3
                                              Line4:line4];

}

NSString *stringOrEmptyStringIfNil(NSString * str)
{
    return ((str== nil) ? @"" : str);
}

- (void)displayVX600LCDMessage:(NSString *)line1
                         line2:(NSString *)line2
                         line3:(NSString *)line3
                         line4:(NSString *)line4 forSeconds:(float)displaySeconds
{
    [[[VStore sharedVStore] pinPad] displayMessages:line1
                                              Line2:line2
                                              Line3:line3
                                              Line4:line4];
}

//MARK: -

static SC_VX600_LCDMessageDisplayQueue *sharedInstance = nil;
+ (SC_VX600_LCDMessageDisplayQueue *)sharedQueue
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
		DLog(@"%@", @"Please use [SC_VX600_LCDMessageDisplayQueue sharedQueue], not alloc/init");
		return sharedInstance;
	}
	
    self = [super init];
    if (self) {
        VX600_LCDMessageQueue = dispatch_queue_create("VX600_LCDMessageQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc
{
    dispatch_release(VX600_LCDMessageQueue);
        
    [super dealloc];
}

@end
