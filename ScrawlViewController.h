//
//  ScrawlViewController.h
//  GEForms3
//
//  Created by Steve Marriott on 10/7/11.
//  Copyright (c) 2011 Big Nerd Ranch. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ScrawlDrawView.h"

@class ScrawlViewController;

@protocol ScrawlViewControllerDelegate <NSObject>
@optional
- (void)recreateScrawlViewPopover;
- (void)scrawlViewControllerWillDismiss:(ScrawlViewController *)svc;
- (void)scrawlViewControllerDidCancel:(ScrawlViewController *)svc;
@end

@interface ScrawlViewController : UIViewController {
   id<ScrawlViewControllerDelegate> _delegate;
    
}

@property (nonatomic) NSInteger section;
@property (nonatomic) NSInteger step;

@property (nonatomic, retain)  ScrawlDrawView *scrawlDrawView;
@property (nonatomic, assign) id<ScrawlViewControllerDelegate> delegate;

@property (nonatomic, assign) BOOL hasDismissButton;
@property (nonatomic, assign) BOOL hasClearSignatureButton;
@property (nonatomic, assign) BOOL hasCancelButton;

@property (nonatomic, assign) BOOL loadsSavedData;      // set NO to not load saved signatures

@property (nonatomic, retain) UIView *buttonPane;
@property (nonatomic, retain) UIButton *cancelButton;
@property (nonatomic, retain) UIButton *doneButton;
@property (nonatomic, retain) UIButton *clearSignatureButton;
@property (nonatomic, retain) UILabel *shakeLabel;
@property (nonatomic, retain) UILabel *doubleTapLabel;

@property (nonatomic, assign) BOOL swipeInButtonPaneClearsDrawing;

@property (nonatomic, retain)  UIColor *scrawlColor;
@property (nonatomic, retain)  UIColor *backgroundColor;


- (id)initWithScrawlColor:(UIColor *)scrColor
     backgroundColorColor:(UIColor *)bgColor
         hasDismissButton:(BOOL)hasDismissBtnFlag
  hasClearSignatureButton:(BOOL)hasClearSignatureBtnFlag
          hasCancelButton:(BOOL)hasCancelBtnFlag
           loadsSavedData:(BOOL)loadsSavedDataFlag;

+ (id)createWithScrawlColor:(UIColor *)scrColor
       backgroundColorColor:(UIColor *)bgColor
           hasDismissButton:(BOOL)hasDismissBtnFlag;

+ (id)createWithScrawlColor:(UIColor *)scrColor
       backgroundColorColor:(UIColor *)bgColor
           hasDismissButton:(BOOL)hasDismissBtnFlag
             loadsSavedData:(BOOL)loadsSavedDataFlag;

+ (id)createWithScrawlColor:(UIColor *)scrColor
       backgroundColorColor:(UIColor *)bgColor
           hasDismissButton:(BOOL)hasDismissBtnFlag
    hasClearSignatureButton:(BOOL)hasClearSignatureBtnFlag
             loadsSavedData:(BOOL)loadsSavedDataFlag;

+ (id)createWithScrawlColor:(UIColor *)scrColor
       backgroundColorColor:(UIColor *)bgColor
           hasDismissButton:(BOOL)hasDismissBtnFlag
    hasClearSignatureButton:(BOOL)hasClearSignatureBtnFlag
            hasCancelButton:(BOOL)hasCancelBtnFlag
             loadsSavedData:(BOOL)loadsSavedDataFlag;

- (void)saveSignature;

- (UIImage *)image;
- (UIImage *)imageWithScrawlColor:(UIColor *)desiredScrawlColor backgroundColor:(UIColor *)desiredBackgroundColor;

@end
