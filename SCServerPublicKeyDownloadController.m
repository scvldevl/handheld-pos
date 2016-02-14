//
//  SCServerPublicKeyDownloadController.m
//  ShoeCarnival
//
//  Created by Bill Monk on 9/25/12.
//  Copyright (c) 2012 Big Nerd Ranch. All rights reserved.
//

#import "SCServerPublicKeyDownloadController.h"
#import "SCServerProtocolController.h"
#import "JBContainedURLConnection.h"

#import "NSString+Utils.h"
#import "NSBundle+Utils.h"

@implementation SCServerPublicKeyDownloadController
@synthesize downloadInProgress, downloadHost, publicKey;

NSString *publicKeyFileName = @"XPIPubKey.PEM";
NSString *publicKeyIDFileName = @"XPIPubKeyId.dat";

// 5/23/13 We are now adding VSP encryption support. Per conf-call with Jim and Dave at ACR and Dean and SC,
// the iOS side will now assume that if it cannot download a .pem from the server, it will use this as a signal
// to attempt to set the VX600 to VSP encryption mode.
//
// This should work fine in stores, but it does introduce a slight kink for development testing of PKI.
// The iOS app (see just above) includes a self-signed public key in its bundle, which allows all the PKI-based
// code downstream to work.
// With the addition of VSP, we will no longer be able to automatically set that key, since BNR will usually not have a
// connection to a store server, which no takes on the meaning of "Set VX600 to VSP mode".
// So we'll have to have a manual toggle here to enable server-less PKI testing.
// Shoe Carnival is moving away from PKI, and would only use it in a pinch, but the intention is that PKI
// should continue to work if needed.
// Per 5/23 conf-call, SC store server will also infer VSP mode by attempting to access the *private* key
// as it normally does for PKI mode. If that fails, it will assume VSP and assume iOS is also in VSP.
// This opens a slight possibility for the two being out of sync, if somehow the store server had one
// key file and not the other, but Dean has this automated so should not occur in practice.
// So if PKI testing is ever needed, the following toggle will need to be manually enabled:
#define kEnableServerlessPKITesting (0 & DEBUG)

//MARK: -

static SCServerPublicKeyDownloadController *sharedInstance = nil;
+ (SCServerPublicKeyDownloadController *)sharedController
{
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
	if (sharedInstance != nil) {
		DLog(@"%@", @"Please use [SCServerPublicKeyDownloadController sharedController], not alloc/init");
		return sharedInstance;
	}
	
    self = [super init];
    if (self) {
#if kEnableServerlessPKITesting
        self.publicKey = [NSString stringWithContentsOfFile:[NSBundle bundlePathForResourceName:@"XPIPubKey.PEM"] encoding:NSASCIIStringEncoding error:nil]; // in-bundle-backup
#endif
    }
    return self;
}

- (void)dealloc {
    [self setDownloadHost:nil];
    
    [super dealloc];
}

//MARK: -

- (NSString *)publicKeyID
{
    // SC / ACI says they don't plan to use a public key ID, and to just use any
    // random number since they will never use it, but something must be set on the sled.
    // I'm not certain about this; thought Tom Salzmann of Verifone said the keyID was generated
    // at the same time as the pub/private key (and should match?). Maybe I misunderstood.
    // Anyway, am leaving this keyID loading code because if SC ever starts rotating keys on
    // their servers, the iOS client may need to eventually download the ID since it is used in transactions
    // on the sled.
    //
    // For now, go ahead and just make up a keyID, and don't log any errors if we don't have a file

    NSString *defaultPublicKeyID = @"77786"; // just some random choice
    
    return defaultPublicKeyID;
}

//MARK: -

#if 0 // unused
- (void)initiatePublicKeyIDDownloadFromHost:(NSString *)host
{
    [self setDownloadInProgress:YES];
        
    NSString *urlStr = [NSString stringWithFormat:@"ftp://%@/pub/%@", [self downloadHost], publicKeyIDFileName];
    
    // NOTE NOTE NOTE currently we expect this to fail; SC is not providing a keyID file; 
    // a dummy ID ia set later on in setPublicKey
        
    // NOTE: this will be flagged by analyzer as a potential leak, but it is not; autoreleased within the completionHandler
    [[JBContainedURLConnection alloc] initWithURLString:urlStr
                                               userInfo:nil 
                                      completionHandler:^(JBContainedURLConnection *connection, 
                                                          NSError *error, 
                                                          NSString *urlString, 
                                                          NSDictionary *userInfo, 
                                                          NSData *data) {
                                          
                                          [connection autorelease];
                                          if (nil != error) {
                                              //DLog(@"%@", @"intiatePublicKeyIDDownload could not download public key ID");
                                             // SPLog(@"intiatePublicKeyIDDownload could not download public key ID");
                                              return;
                                          }
                                          
                                          // Loading succeeded. Use the data, and optionally the URL and userInfo to determine context.
                                          if (![data writeToFile:[self publicKeyIDFilePath] atomically:YES]) {
                                              // SC not using a keyID file, so don't complain. The download code remains in case the start using one in future
                                              // SPLog(@"intiatePublicKeyIDDownload could not write public key ID");
                                             // DLog(@"%@", @"intiatePublicKeyIDDownload could not write public key ID");
                                              return;
                                          }
                                          DLog(@"%@", @"public key ID downloaded OK");
                                          SPLog(@"public key ID downloaded OK");
                                      }];
}
#endif

- (void)initiatePublicKeyDownloadFromHost:(NSString *)host
{
    if ([self downloadInProgress]) {
        //return;
    }
    [self setDownloadInProgress:YES]; // going away
    [self setDownloadHost:host];
        
    // URL on Shoe Carnival server where a .pem file will be exist if server wants us to set the VX600 to PKI encryption mode.
    NSString *urlStr = [NSString stringWithFormat:@"ftp://%@/pub/%@", host, publicKeyFileName];
    SPLog(@"Starting public key download from server:%@", host);
    DLog(@"Starting public key download from server:%@", urlStr);
    
    // NOTE: this line will be flagged by analyzer as a potential leak, but it is not; autoreleased within the completionHandler
    [[JBContainedURLConnection alloc] initWithURLString:urlStr  
                                               userInfo:nil 
                                      completionHandler:^(JBContainedURLConnection *connection, 
                                                          NSError *error, 
                                                          NSString *urlString, 
                                                          NSDictionary *userInfo, 
                                                          NSData *data) {
        [connection autorelease];
        
        if (!error) {
            self.publicKey = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
            
            DLog(@"%@", @"public key downloaded OK");
            SPLog(@"public key downloaded OK");
            
            //[self initiatePublicKeyIDDownloadFromHost:[self downloadHost]];
        } else {
            NSLog(@"intiatePublicKeyDownload failed, error%@", [error userInfo]);
            SPLog(@"download public key failed");
            
#if kEnableServerlessPKITesting
            NSLog(@"%@", @"ServerlessPKITesting is ON. Attempting to use test public key from app bundle");
            SPLog(@"ServerlessPKITesting is ON. Attempting to use test public key from app bundle");
            // in-bundle backup public key. Allows testing PKI without requiring a downloaded .pem from SC store server.
            // When set on the VX600, allows it to encrypt and all iOS-VX card swiping interactions to succeed, but
            // since no one has the corresponding public key, this test data can't be decrypted.
            self.publicKey = [NSString stringWithContentsOfFile:[NSBundle bundlePathForResourceName:@"XPIPubKey.PEM"] encoding:NSASCIIStringEncoding error:nil];
            if (isEmptyString(self.publicKey)) {
                DLog(@"%@", @"ServerlessPKITesting is ON, but no self-signed test public key found in app bundle. Downstream code must infer VSP encryption.");
                SPLog(@"ServerlessPKITesting is ON, but no self-signed test public key found in app bundle. Downstream code must infer VSP encryption.");
            }
#else
            NSLog(@"%@", @"No public key available from server. Interpreting as a request to set VX encyption mode to VSP");
            SPLog(@"No public key available from server. Interpreting as a request to set VX encyption mode to VSP");

            // 5/23/13 conf-call: Failure to download a PKI public key from SC store server
            // will now be used as a signal for iOS to attempt to set VSP encryption mode on VX600.
            // See full comments further up.
            // This means the iOS client of SCServerPublicKeyDownloadController will need to infer encryption mode
            // from the presence or absence of a public key.
            // Serv
            // Monk: my preferred implementation would be for the server to explicitly tell iOS app what encryption mode to set...
            //
            self.publicKey = nil;
#endif
        }
                                          
        [[NSNotificationCenter defaultCenter] postNotificationName:SCServerRequestsEncryptionModeReset object:nil];
        [self setDownloadInProgress:NO];
    }];
}


@end
