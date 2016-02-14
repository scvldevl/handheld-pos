//
//  UIView+Utils.m
//  Bongiovi
//
//  Created by Bill Monk on 3/31/12.
//  Copyright 2012 Big Nerd Ranch. All rights reserved.
//

#import "UIView+Utils.h"


@implementation UIView (Utils)

// MARK: - Gesture recognizers

- (void)removeAllGestureRecognizers
{
    for (UIGestureRecognizer *g in self.gestureRecognizers) {
        [self removeGestureRecognizer:g];
    }
}


@end
