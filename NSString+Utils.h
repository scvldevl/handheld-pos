//
//  NSString+Utils.h
//  Bongiovi
//
//  Created by Bill Monk on 1/4/12.
//  Copyright 2012 Big Nerd Ranch. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSString (Utils)

BOOL isEmptyString(NSString *string);
@end

@interface NSString (ConsoleUtilities)
- (void) writeToFileHandle:(NSFileHandle *) handle;
- (void) writeToStdOut;
- (void) writeToStdErr;
@end

