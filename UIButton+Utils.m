//
//  UIButton+Utils.m
//  ShoeCarnival
//
//  Created by Bill Monk on 6/19/12.
//  Copyright 2012 MonkWorks. All rights reserved.
//

#import "UIButton+Utils.h"


@implementation UIButton (Utils)

- (void)alignTextAndImageOfButton
{
	CGFloat spacing = 2; // the amount of spacing to appear between image and title
	self.imageView.backgroundColor=[UIColor clearColor];
	//self.titleLabel.lineBreakMode = UILineBreakModeWordWrap; - deprecated in iOS 6.0
    self.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
	//self.titleLabel.textAlignment = UITextAlignmentCenter; - deprecated in iOS 6.0
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
	// get the size of the elements here for readability
	CGSize imageSize = self.imageView.frame.size;
	
	// lower the text and push it left to center it
	self.titleEdgeInsets = UIEdgeInsetsMake(0.0, - imageSize.width, - (imageSize.height   + spacing), 0.0);
	
	// the text width might have changed (in case it was shortened before due to 
	// lack of space and isn't anymore now), so we get the frame size again
	CGSize titleSize = self.titleLabel.frame.size;
	
	// raise the image and push it right to center it
	self.imageEdgeInsets = UIEdgeInsetsMake(- (titleSize.height + spacing), 0.0, 0.0, -     titleSize.width);
}

@end
