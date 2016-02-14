//
//  ScrawlDrawView.h
//  GEForms3
//
//  Created by Steve Marriott on 10/7/11.
//  Copyright (c) 2011 Big Nerd Ranch. All rights reserved.
//
//  Adapted from BNR iOS book example "TouchDraw"

#import <Foundation/Foundation.h>
#import     "SoundEffect.h"
#import "Scrawl.h"

@interface ScrawlDrawView : UIView <NSCoding>

{
    NSMutableDictionary *scrawlInProcess;
    NSMutableArray		*completeScrawls;
	
	SoundEffect			*erasingSound;
	BOOL				doubletapClearsDrawing;
	BOOL				shakeClearsDrawing;
	BOOL				shakeClearsIncrementally;

	UIColor				*scrawlColor;
}
@property (nonatomic, retain) NSMutableArray *completeScrawls;
@property (nonatomic, retain) SoundEffect *erasingSound;
@property (nonatomic, retain) UIColor *scrawlColor;
@property (nonatomic, assign) BOOL doubletapClearsDrawing;
@property (nonatomic, assign) BOOL shakeClearsDrawing;
@property (nonatomic, assign) BOOL shakeClearsIncrementally;

- (id)initWithFrame:(CGRect)r scrawlColor:(UIColor *)scrColor backGroundColor:(UIColor *)bgColor;
+ (id)createWithFrame:(CGRect)r scrawlColor:(UIColor *)scrColor backGroundColor:(UIColor *)bgColor;

- (void)clearAll;
- (void)clearLastScrawl;
- (void)clearEachScrawl;

- (void)endTouches:(NSSet *)touches;
- (NSMutableArray *)completedScrawls;

- (void)saveScrawlArray:(NSMutableArray *)scrawlArray forStepNumber:(NSInteger)stepNumber inSection:(NSInteger)sectionNumber;

- (NSMutableArray *)loadScrawlForStepNumber:(NSInteger)stepNumber inSection:(NSInteger)sectionNumber;

- (NSString *)scrawlPathForStepNumber:(NSInteger)stepNumber inSection:(NSInteger)sectionNumber;
- (NSString *)scrawlDocumentsPath;

- (UIImage *)imageWithScrawlColor:(UIColor *)desiredScrawlColor backgroundColor:(UIColor *)desiredBackgroundColor;
- (UIImage *)image;
@end
