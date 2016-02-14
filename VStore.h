//
//  VariableStore.h
//  based on pwmg2Sandbox
//  Created by Thomas Salzmann on 10/27/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//
//  Altered for Shoe Carnival by BMonk/BigNerdRanch 2012
//
#import <VMF/VMFramework.h>
#import	<ExternalAccessory/ExternalAccessory.h>

@class VFIBarcodeDelegate, VFIPinPadDelegate;

extern NSString *ConnectVX600Notification;

typedef enum VX600LanguageCode
{
    // From Verifone Mobile Framework Specification - Appendix D
    VX600LanguageCodeUSA,
    VX600LanguageCodeFRANCE,
    VX600LanguageCodeGERMANY,
    VX600LanguageCodeUK,
    VX600LanguageCodeDENMARK,
    VX600LanguageCodeSWEDEN,
    VX600LanguageCodeITALY,
    VX600LanguageCodeSPAIN,
    VX600LanguageCodeJAPAN,
    VX600LanguageCodeNORWAY,
    VX600LanguageCodeDENMARK2,
    VX600LanguageCodeCHINA
} VX600LanguageCode;

@interface VStore : NSObject
{
	VFIPinpad *pinPad;
	VFIBarcode *barcode; 
	VFIControl *payControl;
	VFIZontalk *zonTalk;
	
    VFIPinPadDelegate *pinPadDelegate;
    VFIBarcodeDelegate *barcodeDelegate;
    
	BOOL upsideDown; 
	BOOL barcodeEnabled;
}

@property(nonatomic, retain) VFIPinpad *pinPad;
@property(nonatomic, retain) VFIBarcode *barcode;
@property(nonatomic, retain) VFIControl *payControl;
@property(nonatomic, retain) VFIZontalk *zonTalk;

@property(nonatomic, retain) VFIPinPadDelegate *pinPadDelegate;
@property(nonatomic, retain) VFIBarcodeDelegate *barcodeDelegate;

+ (VStore *)sharedVStore;

- (void)intializeConnectedPinPad;
- (void)initializeConnectedBarcode;
- (void)initializeConnectedPayControl;
- (void)initializeConnectedZonTalk;

- (void)displayLCDMessage:(NSString *)line1
                    line2:(NSString *)line2
                    line3:(NSString *)line3
                    line4:(NSString *)line4 forSeconds:(NSInteger)displaySeconds;

- (void)logDiagnostics;

- (void)enablePassthroughXCodeDebugging:(BOOL)flag;

// barcode utils
- (void)barcodeScanOn; 
- (void)barcodeScanOff; 
- (void)barcodeScanOffWhileSleeping;
- (void)barcodeScanOnAfterSleeping;
- (void)enableBarcodeCheckDigit:(BOOL)flag;
- (void)enableBarcodeTransmitsUPCE_as_UPCA:(BOOL)flag;

- (UIAlertView *)showActivityIndicatorAlertWithMessage:(NSString *)waitMessage;
- (UIAlertView *)showAlertWithMessage:(NSString *)waitMessage;

// Sled-sleep utils
- (void)setTimeBeforeVX600SleepToFourHours;
- (void)setTimeBeforeVX600SleepToEightHours;

// various verifone-provided utils
- (NSString*)nsdataToNSString:(NSData*)data;
- (NSString*)dataToString:(NSData*)data;

- (NSString*)hexToString:(NSString*)str;
- (NSData *)hexToData:(NSString*)str;   //Example - Pass string that contains characters "30313233", and it will return a data object containing ascii characters "0123"

- (BOOL)isUpsideDown;
- (void)setUpsideDown:(BOOL)orientation;

// BNR card scanner utils
- (void)disableMSR:(BOOL)msrFlag;
- (void)enableCardScanner:(BOOL)flag; // a positively-named alias for disableMSR

+ (BOOL)verifoneEAAccessoryProtocolExists;

- (void)displayInitCompleteLCDMessage;

@end
