//
//  SC_VX600_LCDMessageDisplayQueue.h
//  ShoeCarnival
//
//  Created by Bill Monk on 10/3/12.
//  Copyright (c) 2012 Big Nerd Ranch. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SC_VX600_LCDMessageDisplayQueue : NSObject {
    dispatch_queue_t VX600_LCDMessageQueue;
}
- (void)displayVX600LCDMessage:(NSString *)line1
                         line2:(NSString *)line2
                         line3:(NSString *)line3
                         line4:(NSString *)line4 forSeconds:(float)displaySeconds;

+ (SC_VX600_LCDMessageDisplayQueue *)sharedQueue;
@end
