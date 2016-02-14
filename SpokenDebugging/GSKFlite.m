//  iPhone Text To Speech based on Flite
//
//  Copyright (c) 2010 Sam Foster
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
// 
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//  Author: Sam Foster <samfoster@gmail.com> <http://cmang.org>
//  Copyright 2010. All rights reserved.
//
#include <dispatch/dispatch.h>

#import "GSKFlite.h"
#import "flite.h"

cst_voice *register_cmu_us_kal();
cst_voice *register_cmu_us_kal16();
cst_voice *register_cmu_us_rms();
cst_voice *register_cmu_us_awb();
cst_voice *register_cmu_us_slt();
cst_wave *sound;
cst_voice *voice;

typedef struct WAVEChunkHeader
{
    SInt32      riffID;                     // == 'RIFF'
    SInt32      totalSize;                  // == filesize - 8
    SInt32      waveID;                     // == 'WAVE'
    
    // format chunk
    SInt32      formatID;                   // == 'fmt '
    SInt32      formatChunkSize;            // == 16 (unless format is not uncompressed PCM)
    SInt16      compressionType;            // == 1 for uncompressed PCM
    SInt16      numChannels;
    SInt32      sampleRate;
    SInt32      averageBytesPerSec;         // only really matters for streaming; == sampleRate * blockAlign
    SInt16      blockAlign;                 // == significantBitesPerSample / 8 * numChannels
    SInt16      bitsPerSample;              // usually 8, 16, 24 or 32
    
    // data chunk
    SInt32      dataID;                     // == 'data'
    SInt32      sampleDataSize;             // == size of audio sample data
    
    void *      sampleData[];               // little-endian; if multichannel, interleaved
} WAVEChunkHeader;

char *queueCanceledKey = "queueCanceledKey";
char queueCanceledState = 1;

@interface GSKFlite ()
- (void)createNewQueues;
- (void)destroyQueues;
- (NSData *)cst_waveAsWavData:(cst_wave *)w;

void logCoreAudioError(OSStatus status, const char *functionName);
@end

@implementation GSKFlite
@synthesize audioPlayer;

static GSKFlite *sharedSpeechEngine = nil;
+ (GSKFlite *)sharedSpeechEngine
{
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{ 
        sharedSpeechEngine = [[self alloc] init];
    });
    return sharedSpeechEngine;
}

-(id)init
{
    if (sharedSpeechEngine != nil) {
		DLog(@"%@", @"Please use [GSKFlite sharedSpeechEngine], not alloc/init");
		return sharedSpeechEngine;
	}

    self = [super init];
	flite_init();
	// Set a default voice
	// cmu_us_kal
	// cmu_us_kal16
	// cmu_us_rms
	// cmu_us_awb
	// cmu_us_slt
	[self setVoice:@"cmu_us_kal16"];
    
    return self;
}

#define WAVHeaderHackNeeded 0 // hack to get a wav header on the audio data (so AVAudioPlayer can use it)
#if WAVHeaderHackNeeded
- (NSString *)tempFilePath
{
    if (!tempFilePath) {
        NSArray *filePaths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *recordingDirectory = [filePaths objectAtIndex: 0];
        tempFilePath = [NSString stringWithFormat: @"%@/%s", recordingDirectory, "temp.wav"];
    }
    return tempFilePath;
}
#endif

- (NSData *)dataFromFliteSound:(cst_wave *)w
{
#if WAVHeaderHackNeeded
	// save to disk to get data in true wav format then read back in to get it into NSData.
    // It would be slow except with a flash drive it kind of doesn't matter...
	cst_wave_save_riff(w, [[self tempFilePath] fileSystemRepresentation]);
    NSURL *url = [NSURL fileURLWithPath:[self tempFilePath]];
    NSError *err;
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingUncached error:&err];
    [[NSFileManager defaultManager] removeItemAtPath:[self tempFilePath] error:nil];
    return data;
#else 
    return [self cst_waveAsWavData:w];
#endif    
}

- (NSString *)cleanedStringFromString:(NSString *)str
{
	NSMutableString *cleanedString = [NSMutableString string];
    NSUInteger x = 0;
    while (x < [str length])        // what purpose does this serve? just copies the string char by char...
    {
        unichar ch = [str characterAtIndex:x];
        [cleanedString appendFormat:@"%c", ch];
        x++;
    }
    return [[cleanedString copy] autorelease];
}

- (AVAudioPlayer *)preparedAudioPlayerWithSoundData:(NSData *)soundData
{
    NSError *err;
	AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithData:soundData error:&err];
    if (!player) {
        NSLog(@"AVAudioPlayer init failed: %@", [err localizedDescription]);
        logCoreAudioError([err code], __func__);
        return nil;
    }
    [player setDelegate:self];
    [player prepareToPlay];
    return player;
}

- (void)asyncRenderAndSpeakString:(NSString *)string
{   //
    // Render the audio data async, and play it back in order.
    // 
    dispatch_async(renderQueue, ^{
		
        dispatch_queue_t curQ = dispatch_get_current_queue();
        if (curQ != renderQueue) {
            NSLog(@"canceling render of string:\"%@\"", string);
            return;
        }
        if  (&queueCanceledState == dispatch_queue_get_specific(dispatch_get_current_queue(), &queueCanceledKey)) {
            NSLog(@"canceling render of string:\"%@\"", string);
            return;
        }
		
        //NSLog(@"speaking string:\"%@\"", string); // NOTE: don't call DLog here if it is aliases to SPLog, else infinite speech loop
		
        NSString *cleanedStr = [self cleanedStringFromString:string]; // necessary?
        
        cst_wave *renderedSound = flite_text_to_wave([cleanedStr UTF8String], voice);
        NSData *soundData = [self dataFromFliteSound:renderedSound];
        delete_wave(renderedSound);
        
        // dispatch_async() here will repeatedly place the following code block on the playbackQueue in FIFO order 
        // without blocking, but each then each code block will run synchronously, blocking on dispatch_semaphore_wait()
        // until unblocked by the dispatch_semaphore_signal() in the AVAudioPlayerDelegate audioPlayerDidFinishPlaying.
        // That will cause the currently playing player block to exit and the next async-queued block to run, which will
        // again block on dispatch_semaphore_wait(). In this way, the test-to-speech converts each sentence as
        // fast as possible without waiting for playback to complete, yet each sentence's playback waits on
        // any previously-queued sentences and plays them in order. 
        //
        // If there are lots and lots of sentences to play, it may make sense to throttle the renderQueue so that
        // it never gets more than some number of sentences (say 5 or 10) ahead of the playbackQueue. 
		
        dispatch_async(playbackQueue, ^{
            dispatch_queue_t curQ = dispatch_get_current_queue();
            if (curQ != playbackQueue) {
                NSLog(@"canceling play of string:\"%@\"", string);
                return;
            }
			
            audioPlayer = [self preparedAudioPlayerWithSoundData:soundData];
            [audioPlayer play]; // launch async playbackks
            
            dispatch_semaphore_wait(playbackSemaphore, DISPATCH_TIME_FOREVER);
        });
    });
}

- (void)reset
{
    numSentencesToSpeak = 0;
    [audioPlayer stop];
    audioPlayer = nil;
    [self createNewQueues];
}

-(void)speakTextInArray:(NSArray *)sentenceArray
{
    [self reset];
    
    numSentencesToSpeak = [sentenceArray count];
    for (NSString *sentence in sentenceArray) {
        [self asyncRenderAndSpeakString:sentence];
    }
}

-(void)speakTextInArray:(NSArray *)sentenceArray startingAtIndex:(NSUInteger)startIndex
{
    if (startIndex >= [sentenceArray count]) {
        return;
    }
    
    [self reset];
    numSentencesToSpeak = [sentenceArray count] - startIndex;
    
    NSUInteger i = 0;
    for (NSString *sentence in sentenceArray) {
        if (i >= startIndex) {
            [self asyncRenderAndSpeakString:sentence];
        }
        i++;
    }
}

- (void)speakText:(NSString *)text
{
    if (!renderQueue) {
        [self createNewQueues];   
    }
    //[self reset];

    [self asyncRenderAndSpeakString:text];
}

//MARK: - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag 
{    
    dispatch_semaphore_signal(playbackSemaphore); // unblock the dispatch_semaphore_wait() which serializes [audioPlayer play]
    
    --numSentencesToSpeak;
    if (numSentencesToSpeak <= 0) {
		// notify any interested objects
    }
}

- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player 
{
}

//MARK: - voice and transport management

-(void)setPitch:(float)pitch variance:(float)variance speed:(float)speed
{
	feat_set_float(voice->features,"int_f0_target_mean", pitch);
	feat_set_float(voice->features,"int_f0_target_stddev",variance);
	feat_set_float(voice->features,"duration_stretch",speed); 
}

-(void)setVoice:(NSString *)voicename
{
	if([voicename isEqualToString:@"cmu_us_kal"]) {
		voice = register_cmu_us_kal();
	}
	else if([voicename isEqualToString:@"cmu_us_kal16"]) {
		voice = register_cmu_us_kal16();
	}
	else if([voicename isEqualToString:@"cmu_us_rms"]) {
		voice = register_cmu_us_rms();
	}
	else if([voicename isEqualToString:@"cmu_us_awb"]) {
		voice = register_cmu_us_awb();
	}
	else if([voicename isEqualToString:@"cmu_us_slt"]) {
		voice = register_cmu_us_slt();
	}
}

-(void)stopTalking
{
	[audioPlayer stop];
}

-(void)pauseSpeech
{
    if ([audioPlayer isPlaying])
        [audioPlayer pause];
    else
        [audioPlayer play];
}

//MARK: - queue management

- (void)createNewQueues
{
    if (renderQueue) {
        dispatch_suspend(renderQueue);
        dispatch_queue_set_specific(renderQueue, &queueCanceledKey, &queueCanceledState, NULL);
        dispatch_resume(renderQueue);
        dispatch_release(renderQueue);
    }
    renderQueue = dispatch_queue_create("renderQueue", DISPATCH_QUEUE_SERIAL);
    
    if (playbackQueue) {
        dispatch_suspend(playbackQueue);
        dispatch_queue_set_specific(playbackQueue, &queueCanceledKey, &queueCanceledState, NULL);
        dispatch_resume(playbackQueue);
        dispatch_release(playbackQueue);
    }
    playbackQueue =  dispatch_queue_create("playbackQueue", DISPATCH_QUEUE_SERIAL);
    
    if (playbackSemaphore) {
        long semaphore = 0;
        do  {
			semaphore = dispatch_semaphore_signal(playbackSemaphore); // unblock the dispatch_semaphore_wait() which serializes [audioPlayer play]
        } while (semaphore);
    }
    playbackSemaphore = dispatch_semaphore_create(0L);
}

- (void)destroyQueues
{
    if (playbackSemaphore) {
        dispatch_release(playbackSemaphore);
        playbackSemaphore = nil;
    }
    if (renderQueue) {
        dispatch_release(renderQueue);
        renderQueue = nil;
    }
    if (playbackQueue) {
        dispatch_release(playbackQueue);
        playbackQueue = nil;
    }
}

//MARK: - CA utils


- (NSData *)cst_waveAsWavData:(cst_wave *)w
{
    NSUInteger cst_waveSampleSize = (w->num_channels * w->num_samples * sizeof(short));
    size_t mallocSize = sizeof(WAVEChunkHeader) + cst_waveSampleSize;
    WAVEChunkHeader *header = malloc(mallocSize);
    if (!header) {
        return nil;
    }
    bzero(header, mallocSize);
    
    //header->riffID = 'RIFF';
    header->riffID = 'FFIR';
    
    header->totalSize = (w->num_samples * w->num_channels * sizeof(short)) + 8 + 16 + 12; 
    // header->totalSize = (w->num_samples * w->num_channels * sizeof(short)) + 4 + 16 + 12; 
    
    //header->waveID = 'WAVE';
    header->waveID = 'EVAW';
    
	// header->formatID = 'fmt ';
    header->formatID = ' tmf';
    
    header->formatChunkSize = 16;
    header->compressionType = 1;
    header->numChannels = w->num_channels;
    header->sampleRate = w->sample_rate;
    header->averageBytesPerSec = (w->sample_rate * w->num_channels * sizeof(short));
    header->blockAlign = (w->num_channels * sizeof(short));
    header->bitsPerSample = 2 * 8;
    
    //header->dataID = 'data';
    header->dataID = 'atad';
    
    header->sampleDataSize = cst_waveSampleSize;
    memcpy(header->sampleData, w->samples, cst_waveSampleSize);
	
    NSUInteger totalSize = (sizeof(WAVEChunkHeader) + header->sampleDataSize);
    NSData *data = [NSData dataWithBytes:header length:totalSize];
    
    return data;
}

void logCoreAudioError(OSStatus status, const char *functionName) {
	// Core aAudio status errors are usually really of OSType, i.e. FourCharCode, i.e. 4 ascii chars in big endian order.
	// NSFileTypeForHFSTypeCode() is available for this conversion on Mac but not on iOS.
#define FourCC2Str(code) (char[5]){(code >> 24) & 0xFF, (code >> 16) & 0xFF, (code >> 8) & 0xFF, code & 0xFF, 0} 
    
	if (status != noErr) {
		NSString *errorDescription = nil;
		switch (status) {
			case kAudioFileUnspecifiedError:
				errorDescription = @"kAudioFileUnspecifiedError";
				break;
			case kAudioFileUnsupportedFileTypeError:
				errorDescription = @"kAudioFileUnsupportedFileTypeError";
				break;
			case kAudioFileUnsupportedDataFormatError:
				errorDescription = @"kAudioFileUnsupportedDataFormatError";
				break;
			case kAudioFileUnsupportedPropertyError:
				errorDescription = @"kAudioFileUnsupportedPropertyError";
				break;
			case kAudioFileBadPropertySizeError:
				errorDescription = @"kAudioFileBadPropertySizeError";
				break;
			case kAudioFilePermissionsError:
				errorDescription = @"kAudioFilePermissionsError";
				break;
			case kAudioFileNotOptimizedError:
				errorDescription = @"kAudioFileNotOptimizedError";
				break;
			case kAudioFileInvalidChunkError:
				errorDescription = @"kAudioFileInvalidChunkError";
				break;
			case kAudioFileDoesNotAllow64BitDataSizeError:
				errorDescription = @"kAudioFileDoesNotAllow64BitDataSizeError";
				break;
			case kAudioFileInvalidPacketOffsetError:
				errorDescription = @"kAudioFileInvalidPacketOffsetError";
				break;
			case kAudioFileInvalidFileError:
				errorDescription = @"kAudioFileInvalidFileError";
				break;
			case kAudioFileOperationNotSupportedError:
				errorDescription = @"kAudioFileOperationNotSupportedError";
				break;
			case kAudioFileNotOpenError:
				errorDescription = @"kAudioFileNotOpenError";
				break;
			case kAudioFileEndOfFileError:
				errorDescription = @"kAudioFileEndOfFileError";
				break;
			case kAudioFilePositionError:
				errorDescription = @"kAudioFilePositionError";
				break;
			case kAudioFileFileNotFoundError:
				errorDescription = @"kAudioFileFileNotFoundError";
				break;
			default:
                errorDescription = @"<no description available>";
				break;
		}
        NSLog(@"Core Audio error:'%s' \"%@\" in %s", FourCC2Str(status), errorDescription, functionName == nil ? "" : functionName); 
	}
}

@end



