

#import <Foundation/Foundation.h>

/**
 * Encapsulating data class utilized by VFIPinpad
 */

@interface VFICipheredData : NSObject {


	int encryptionType;         //!< 00 - None, 01 - VSP, 02 - PKI, 04- VSD DUKPT
	NSString* keyID;            //!< Key ID (variable, max up to 32 digits)
	int dataType;               //!< Encryption mode
	NSString* encryptedBlob_1;  //!< Ciphered Data, Track 2 Data, Track 1 Data (Optional, if CVV value is entered during a manual entry, CVV will be returned in this blob in the following format: PAN'='Expiration Date<FS>CVV
	NSString* encryptedBlob_2;  //!< Ciphered Data (Optional, if Track3 is present) Track 3 Data
	NSString* VSD_Blob;         //!< Ciphered Data, Base64 variable length encrypted blob  containing VSD TLV list (VSD DUKPT encryption mode only)
    NSString* TRA_Blob;         //!< Ciphered Data, Base64 variable length encrypted blob containing TRA fields-  Header(Version and Payload Length) and Payload(TLV list).
	NSString* EParms;           //!< String of data returned by VCL that is then used by the VSD to determine information about the encryption status of the PAN data.
	NSString* TKG1_Track1;      //!< Terminal Generated Key 1, Track 1
	NSString* TKG1_Track2;      //!< Terminal Generated Key 1, Track 2
	NSString* TKG2_Track1;      //!< Terminal Generated Key 2, Track 1
	NSString* TKG2_Track2;      //!< Terminal Generated Key 2, Track 2
	NSString* TKG3_Track1;      //!< Terminal Generated Key 3, Track 1
	NSString* TKG3_Track2;      //!< Terminal Generated Key 3, Track 2
    int fileType;               //!< Numeric value of file type requested in E24
    NSString* version;          //!< Alphanumeric version returned from E24

}
/**
 * clears all VFICipheredData properties
 */
-(void)clear;
/**
 * Singleton instance of VFICipheredData utilized by VFIPinpad
 */
+ (VFICipheredData *)sharedController;

#if !__has_feature(objc_arc)
    @property int encryptionType;
    @property (nonatomic, retain) NSString* keyID;
    @property int dataType;
    @property (nonatomic, retain) NSString* encryptedBlob_1;
    @property (nonatomic, retain) NSString* encryptedBlob_2;
    @property (nonatomic, retain) NSString* VSD_Blob;
    @property (nonatomic, retain) NSString* TRA_Blob;
    @property (nonatomic, retain) NSString* EParms;
    @property (nonatomic, retain) NSString* TKG1_Track1;
    @property (nonatomic, retain) NSString* TKG1_Track2;
    @property (nonatomic, retain) NSString* TKG2_Track1;
    @property (nonatomic, retain) NSString* TKG2_Track2;
    @property (nonatomic, retain) NSString* TKG3_Track1;
    @property (nonatomic, retain) NSString* TKG3_Track2;
    @property int fileType;
    @property (nonatomic, retain) NSString* version;
#else
    @property int encryptionType;
    @property (nonatomic, strong) NSString* keyID;
    @property int dataType;
    @property (nonatomic, strong) NSString* encryptedBlob_1;
    @property (nonatomic, strong) NSString* encryptedBlob_2;
    @property (nonatomic, strong) NSString* VSD_Blob;
    @property (nonatomic, strong) NSString* TRA_Blob;
    @property (nonatomic, strong) NSString* EParms;
    @property (nonatomic, strong) NSString* TKG1_Track1;
    @property (nonatomic, strong) NSString* TKG1_Track2;
    @property (nonatomic, strong) NSString* TKG2_Track1;
    @property (nonatomic, strong) NSString* TKG2_Track2;
    @property (nonatomic, strong) NSString* TKG3_Track1;
    @property (nonatomic, strong) NSString* TKG3_Track2;
    @property int fileType;
    @property (nonatomic, strong) NSString* version;
#endif

@end
