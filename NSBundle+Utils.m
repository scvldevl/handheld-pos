//
//  NSBundle+Utils.m
//  GEForms3
//
//  Created by Bill Monk on 9/16/11.
//  Copyright 2011 Big Nerd Ranch. All rights reserved.
//

#import "NSBundle+Utils.h"


@implementation NSBundle (NSBundleUtils)

+ (NSString *)bundlePathForResourceName:(NSString *)aResourceName;
{	
	if (!aResourceName) return nil; // if name is nil, pathForResource (annoyingly) doesn't fail and return nil, rather it (in earlier iOS versions?) defaults to the app icon

	NSString *name = [aResourceName stringByDeletingPathExtension];
	NSString *extension = [aResourceName pathExtension];
	NSString *resourcePath = [[NSBundle mainBundle] pathForResource:name ofType:extension]; 
	return resourcePath;
}	


@end
