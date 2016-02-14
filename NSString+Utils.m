//
//  NSString+Utils.m
//  Bongiovi
//
//  Created by Bill Monk on 1/4/12.
//  Copyright 2012 Big Nerd Ranch. All rights reserved.
//

#import "NSString+Utils.h"

@implementation NSString (Utils)


BOOL isEmptyString(NSString *string) {
	return string == nil || 
                [[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""];
}

@end

@implementation NSString (ConsoleUtilities)

// Some console I/O conveniences.
- (void) writeToFileHandle:(NSFileHandle *) handle { [handle writeData:[self dataUsingEncoding:NSUTF8StringEncoding]]; }
- (void) writeToStdOut { [self writeToFileHandle:[NSFileHandle fileHandleWithStandardOutput]]; }
- (void) writeToStdErr { [self writeToFileHandle:[NSFileHandle fileHandleWithStandardError]]; }

@end
