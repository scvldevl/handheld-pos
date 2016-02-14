//
//  UILabel+Utils.m
//  GEForms3
//
//  Created by Bill Monk on 11/15/10.
//  Copyright (c) 2010-2011 Big Nerd Ranch. All rights reserved.
//

#import "UILabel+Utils.h"

@implementation UILabel (UILabelUtils)

- (void)setFontSizeTo:(CGFloat)newSize
{
	UIFont *font = [self font];
	if (!font) {
		font = [UIFont systemFontOfSize:[UIFont labelFontSize]]; // headers say nil UILabel font means system font of size 17, plain
	}
	if ([font pointSize] != newSize) {
		UIFont *newFont = [UIFont fontWithName:[font fontName] size:newSize];
		
		[self setFont:newFont];
	}
}

- (void)multiplyFontSizeBy:(CGFloat)multiplier
{
	CGFloat currentPointSize = [[self font] pointSize];
	[self setFontSizeTo:currentPointSize * multiplier];
}

@end
