

#import <Foundation/Foundation.h>

@class VFIEncryptionData;
/**
 * Encapsulating data class utilized by VFIPinpad
 */
@interface VFIEncryptionData : NSObject {

	NSData *macBlock;           //!< 8-character MAC Block
	NSData *pinBlock;           //!< 16-character PIN Block as Data (when applicable)
	NSString *pinBlockStr;      //!< 16-character PIN Block as String (when applicable)
	NSString *serialNumber;     //!< Serial Number of the VeriFone PINPad accessory
	int accountSelection;       //!< Account type selection, 1:checking, 2:savings.
}

/**
 * clears all VFIEncryptionData properties
 */
-(void)clear;
/**
 * Singleton instance of VFIEncryptionData utilized by VFIPinpad
 */
+ (VFIEncryptionData *)sharedController;

#if !__has_feature(objc_arc)
    @property (nonatomic, retain) NSData *macBlock;
    @property (nonatomic, retain) NSData *pinBlock;
    @property (nonatomic, retain) NSString *pinBlockStr;
    @property (nonatomic, retain) NSString *serialNumber;
    @property int accountSelection;
#else
    @property (nonatomic, strong) NSData *macBlock;
    @property (nonatomic, strong) NSData *pinBlock;
    @property (nonatomic, strong) NSString *pinBlockStr;
    @property (nonatomic, strong) NSString *serialNumber;
    @property int accountSelection;
#endif

@end
