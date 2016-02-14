//
//  VFIPinPadDelegate.m
//  ShoeCarnival
//
//  Created by Bill Monk on 8/21/12.
//  Copyright (c) 2012 Big Nerd Ranch. All rights reserved.
//

#import "VFIPinPadDelegate.h"
#import "VStore.h"

NSString *VerifonePinPadDidReceiveDataNotification = @"VerifonePinPadDidReceiveDataNotification";
NSString *PinPadDataAsStringKey = @"PinPadDataAsStringKey";


@implementation VFIPinPadDelegate


//Monitors connect/disconnect events from [[VStore sharedVStore] pinPad]
- (void)pinpadConnected:(BOOL)isConnected
{
    SPLog(@"pinpadConnected : %@", isConnected ? @"Yes" : @"No");
    DLog(@"pinpadConnected: %d", isConnected);

	static BOOL needInit = NO; // <-- Verifone; why needed?
	
    if (isConnected) {
        static BOOL oneShot = YES;
        if (oneShot) {
            [[VStore sharedVStore] intializeConnectedPinPad];
            oneShot = NO;
        }
    }
    
#if 0
    [miscText setText:[NSString stringWithFormat:@"PPC:BC/PP/CTL - C:%d/%d/%d  I:%d/%d/%d\n%@",  
                       ([[VStore sharedVStore] barcode].connected), 
                       ([[VStore sharedVStore] pinPad].connected),                        
                       ([[VStore sharedVStore] payControl].connected), 
                       ([[VStore sharedVStore] barcode].initialized),                        
                       ([[VStore sharedVStore] pinPad].initialized), 
                       ([[VStore sharedVStore] payControl].initialized), 
                       miscText.text]]; 
#endif
    
    if (isConnected) {
        //UIImage *greenImage = [UIImage imageNamed:@"1287153228_Circle_Green.png"];
        //UIImage *greenButtonImage = [greenImage stretchableImageWithLeftCapWidth:0 topCapHeight:0];
        //[connectButton setImage:greenButtonImage forState:UIControlStateNormal];
        
                
        
    }else {
        //UIImage *redImage = [UIImage imageNamed:@"1287153257_Circle_Red.png"];
        //UIImage *redButtonImage = [redImage stretchableImageWithLeftCapWidth:0 topCapHeight:0];
       // [connectButton setImage:redButtonImage forState:UIControlStateNormal];
        
        needInit = YES; 
        
        // TEST INIT/NOT INIT LOGIC
       // [pinpadNotReady setHidden: NO];
        
        //myInitStarted = NO; 
        //myInitDone = NO; 
        
        
        
    }
    
    
}



//Monitors data being received from the [VStore sharedVStore] pinPad
- (void) pinpadDataReceived:(NSData*)data {
    SPLog(@"pinpadDataReceived %u bytes", [data length]);
    DLog(@"pinpadDataReceived %lu bytes", (unsigned long)[data length]);

    NSString *pinPadDataAsString = [[VStore sharedVStore] nsdataToNSString:data]; 
    
    if ([pinPadDataAsString length] >= 2) {
        if ([[pinPadDataAsString substringToIndex:2] isEqualToString:@"06"]) {
        // Verifone sample code doesn't indicate what this case means... originally nothing was done here
    } else {
        DLog(@"PPRECV: %@", [[VStore sharedVStore] hexToString:[[VStore sharedVStore] nsdataToNSString:data]]);
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:pinPadDataAsString forKey:PinPadDataAsStringKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:VerifonePinPadDidReceiveDataNotification
                                                            object:nil
                                                          userInfo:userInfo];
        
        }	
    }
}


//Monitors data being sent
- (void) pinpadDataSent:(NSData*)data {
	
    NSString *dataAsString = [[VStore sharedVStore] nsdataToNSString:data]; 
    
    if ([dataAsString length] >= 2) {
        if ([[dataAsString substringToIndex:2] isEqualToString:@"06"]) {
            // Verifone sample code doesn't indicate what this case means... originally nothing was done here
        } else {
            // NSLog(@"PPSEND: %@", [[VStore sharedVStore] nsdataToNSString:data]);
            DLog(@"PPSEND: %@", [[VStore sharedVStore] hexToString:dataAsString]);
            
           // [miscText setText:[NSString stringWithFormat:@"PPSEND: %@\n%@", dataAsString, miscText.text]]; 
            
        }	
    }
}

- (void) pinpadLogEntry:(NSString *)logEntry withSeverity:(int)severity{
	
	DLog(@"ppLogEntry: %@", logEntry);
	
	
	
}

- (void) pinpadMSRData:(NSString*)pan  expMonth:(NSString*)month  expYear:(NSString*)year  trackData:(NSString*)track2 
{
    SPLog(@"received pinpadMSRData with month:%@ year:%@ track2 dataLength:%u", month, year, [track2 length]);
   
#if (0)
    lastPan = [NSString stringWithFormat:@"%@", pan]; 
    
    if (myEncryptionType == EncryptionMode_PKI) {
        
        int result = [[[VStore sharedVStore] pinPad] getPKICipheredData];  
        SPLog(@"getPKICipheredData result code:^d", result);
        DLog(@"getPKICipheredData result code:^d", result);
        
        VFICipheredData *cipheredData = [[[VStore sharedVStore] pinPad] vfiCipheredData];
        
        NSString *logStr = [NSString stringWithFormat:@"Encryption Type:%d, Keyid:%@, dataType:%d, blob1 length:%lu, blob2 length:%lu", 
                            cipheredData.encryptionType, 
                            cipheredData.keyID, 
                            cipheredData.dataType,
                            [cipheredData.encryptedBlob_1 length],
                            [cipheredData.encryptedBlob_2 length]];
        SPLog(logStr); 
        DLog(@"%@", logStr); 
        
        DLog(@"Blob1[%@]",[[VStore sharedVStore] pinPad].vfiCipheredData.encryptedBlob_1); 
        DLog(@"Blob2[%@]",[[VStore sharedVStore] pinPad].vfiCipheredData.encryptedBlob_2); 
        
        if (doingBlob) {
            doingBlob = NO; 
            
            [self.myAlert2 dismissWithClickedButtonIndex:0 animated:YES];  
            self.myAlert2 = nil;
            
            self.myAlert2 = [[VStore sharedVStore] showAlertWithMessage:@"Generating Blob File...\nPlease Wait..."];
            
            
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths objectAtIndex:0];
            
            NSString *foofile = [documentsDirectory stringByAppendingPathComponent:                         
                                 [NSString stringWithFormat:@"%@", @"lastBlob.out" ]];
            
            
            NSString *fred = [NSString stringWithFormat:@"%@", [[VStore sharedVStore] pinPad].vfiCipheredData.encryptedBlob_1]; 
            int fredL = [[VStore sharedVStore] pinPad].vfiCipheredData.encryptedBlob_1.length; 
            NSString *fred16 = @""; 
            int ii; 
            for (ii = 0; ii < fredL; ii+=16) {
                // grab 16 bytes and append \n 
                
                // NSLog([@"1234567890" substringWithRange:NSMakeRange(ii, 16)]);
                
                if ((ii+16) > fredL) {
                    
                    fred16 = [NSString stringWithFormat:@"%@%@\n", fred16, [fred substringWithRange:NSMakeRange(ii, (fredL - ii))]]; 
                    
                    
                } else {
                    
                    //  NSString *spud = [fred substringWithRange:NSMakeRange(ii, 16)]; 
                    
                    fred16 = [NSString stringWithFormat:@"%@%@\n", fred16, [fred substringWithRange:NSMakeRange(ii, 16)]]; 
                    
                    //                                                                       [string substringWithRange: NSMakeRange(3, 6)]
                    
                }
                
                
            }
            
            [fred16 writeToFile:foofile atomically:YES encoding:NSUTF8StringEncoding error:nil];
            
            [self.myAlert2 dismissWithClickedButtonIndex:0 animated:YES];  
            self.myAlert2 = nil;
            
        }
        
        
    }
#endif    
}

- (void) pinpadMSRData:(NSString*)pan expMonth:(NSString*)month expYear:(NSString*)year track1Data:(NSString*)track1 track2Data:(NSString*)track2 
{    
    SPLog(@"received pinpadMSRData with month:%@ year:%@ track1 dataLength:%u track2 dataLength:%u", month, year, [track1 length], [track2 length]);

#if 0
    lastPan = [NSString stringWithFormat:@"%@", pan]; 
    
    dispatch_queue_t main = dispatch_get_main_queue();
    dispatch_async(main, ^{
        
        [miscText setText:[NSString stringWithFormat:@"Card Data: %@/%@/%@/%@/%@\n%@", track1, track2, pan, year, month, miscText.text]]; 
    });    
#endif   
}

- (void) pinpadSerialData:(NSData *)data incoming:(BOOL)isIncoming {
	
	
}

- (void) pinpadDownloadInfo:(NSString*)log{
#if 0
	[cardData setText:log];
	[miscText setText:[NSString stringWithFormat:@"%@\n%@", log, miscText.text]]; 
#endif
}

- (void) pinpadDownloadBlocks:(int)TotalBlocks sent:(int)BlocksSent{
#if 0
	NSString *myBlocks; 
	myBlocks = [NSString stringWithFormat:@"%i sent of %i total blocks.",BlocksSent,TotalBlocks];
	[cardData setText:myBlocks];
	// [miscText setText:[NSString stringWithFormat:@"%@\n%@", myBlocks, miscText.text]]; 
    
#endif
}

@end
