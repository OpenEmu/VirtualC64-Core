/*
 Copyright (c) 2009, OpenEmu Team


 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the OpenEmu Team nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "VC64GameCore.h"
#import <OpenEmuBase/OERingBuffer.h>
#import <OpenEmuBase/OpenEmuBase.h>
#import "OEC64SystemResponderClient.h"
#import <OpenGL/gl.h>


@interface VC64GameCore () <OEC64SystemResponderClient>
{
    uint16_t *videoBuffer;
    int videoWidth, videoHeight;
    int16_t pad[2][16];
    NSString *romName;
    double sampleRate;
}


@end
/*
NSUInteger FCEUEmulatorValues[] = { SNES_DEVICE_ID_JOYPAD_UP, SNES_DEVICE_ID_JOYPAD_DOWN, SNES_DEVICE_ID_JOYPAD_LEFT, SNES_DEVICE_ID_JOYPAD_RIGHT, SNES_DEVICE_ID_JOYPAD_A, SNES_DEVICE_ID_JOYPAD_B, SNES_DEVICE_ID_JOYPAD_START, SNES_DEVICE_ID_JOYPAD_SELECT };
NSString *FCEUEmulatorKeys[] = { @"Joypad@ Up", @"Joypad@ Down", @"Joypad@ Left", @"Joypad@ Right", @"Joypad@ A", @"Joypad@ B", @"Joypad@ Start", @"Joypad@ Select"};
*/

@implementation VC64GameCore

static VC64GameCore *current;
static OERingBuffer *ringBuffer;

#pragma mark VirtualC64: Input
- (oneway void)didPushNESButton:(OEC64Button)button forPlayer:(NSUInteger)player;
{
//    pad[player - 1][FCEUEmulatorValues[button]] = 0xFFFF;
    //pad[player - 1][FCEUEmulatorValues[button]] = 1;
}

- (oneway void)didReleaseNESButton:(OEC64Button)button forPlayer:(NSUInteger)player;
{
//    pad[player - 1][FCEUEmulatorValues[button]] = 0;
}

#define u32 unsigned short
#define BUFFERSIZE 2048

#pragma mark VirtualC64: Init
- (id)init
{
    if((self = [super init]))
    {
        current = self;
        
        c64 = new C64();
        
        // Todo: Should we determine region ?
        c64->setPAL();
        
        if (![self loadTheBIOSRoms])
            return nil;
        
        if (c64->isRunnable())
        {
            NSLog(@"VirtualC64: We can run");
            return self;
        }
    }
    
    return nil;
}

- (void)dealloc
{
    free(c64);
}

//  Helper methods to load the BIOS ROMS
- (BOOL)loadTheBIOSRoms
{
    // Get The 4 BIOS ROMS
    
    // BASIC ROM
    NSString *basicROM = [[[[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"]
                                                stringByAppendingPathComponent:@"Application Support"]
                                                stringByAppendingPathComponent:@"OpenEmu"]
                                                stringByAppendingPathComponent:@"BIOS"]
                                                stringByAppendingPathComponent:@"Basic.rom"];
    
    if (!c64->mem->isBasicRom([basicROM UTF8String]))
    {
        NSLog(@"VirtualC64: %@ is not a valid Basic ROM!", basicROM);
        return NO;
    }

    // Kernel ROM
    NSString *kernelROM = [[[[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"]
                                                stringByAppendingPathComponent:@"Application Support"]
                                                stringByAppendingPathComponent:@"OpenEmu"]
                                                stringByAppendingPathComponent:@"BIOS"]
                                                stringByAppendingPathComponent:@"Kernel.rom"];
    
    if (!c64->mem->isKernelRom([kernelROM UTF8String]))
    {
        NSLog(@"VirtualC64: %@ is not a valid Kernel ROM!", kernelROM);
        return NO;
    }
    
    // Char ROM
    NSString *charROM = [[[[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"]
                                                stringByAppendingPathComponent:@"Application Support"]
                                                stringByAppendingPathComponent:@"OpenEmu"]
                                                stringByAppendingPathComponent:@"BIOS"]
                                                stringByAppendingPathComponent:@"Char.rom"];
    
    if (!c64->mem->isCharRom([charROM UTF8String]))
    {
        NSLog(@"VirtualC64: %@ is not a valid Kernel ROM!", charROM);
        return NO;
    }
    
    // C1541 aka Floppy ROM
    NSString *C1541ROM = [[[[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"]
                                                stringByAppendingPathComponent:@"Application Support"]
                                                stringByAppendingPathComponent:@"OpenEmu"]
                                                stringByAppendingPathComponent:@"BIOS"]
                                                stringByAppendingPathComponent:@"C1541.rom"];
    
    // We've Basic, Kernel and Char ROMS and CP1541 Floppy ROM load them into c64
    c64->loadRom([basicROM UTF8String]);
    c64->loadRom([kernelROM UTF8String]);
    c64->loadRom([charROM UTF8String]);
    c64->loadRom([C1541ROM UTF8String]);
    
    return YES;
}

// Debug: KeyPresses Test
- (void)sendKeyPress
{
    // See Keyboard Matrix in Keboyard.h
    // Note: order is row,column
    //       If you use the overloaded function to send a char it should be a small letter of the ascii table, ie 'a' not 'A'
    
    c64->keyboard->pressKey(5,2);
    usleep(100000);
    c64->keyboard->releaseKey(5,2);
    
    char Oh = 'o';
    
    c64->keyboard->pressKey(Oh);
    usleep(100000);
    c64->keyboard->releaseKey(Oh);
}

#pragma mark Exectuion

- (void)executeFrame
{
    [self executeFrameSkippingFrame:NO];
}

BOOL didRUN = false;

- (BOOL)isC64ReadyToRUN
{
    // HACK: Wait until enough cycles have passed to assume we're at the prompt
    // and ready to RUN whatever has been flashed ("flush") into memory
    if (c64->getCycles() >= 2803451 && !didRUN)
    {
        return YES;
    }
    
    return NO;
}

- (void)executeFrameSkippingFrame:(BOOL)skip
{
    // Lazy/Late Init, we need to send RUN when the system is ready
    if ([self isC64ReadyToRUN])
    {
        c64->mountArchive(D64Archive::archiveFromArbitraryFile([fileToLoad UTF8String]));
        c64->flushArchive(D64Archive::archiveFromArbitraryFile([fileToLoad UTF8String]), 0);
        
        c64->keyboard->typeRun();
        didRUN = YES;
    }
}

NSString *fileToLoad;

- (BOOL)loadFileAtPath:(NSString *)path
{
    fileToLoad = [[NSString alloc] initWithString:path];

    return YES;
}

#pragma mark Video
- (const void *)videoBuffer
{
    if(c64->isRunning())
    {
        return c64->vic->screenBuffer();
    }
    
    return NULL;
}

- (OEIntRect)screenRect
{
    return OEIntRectMake(0,0,(float)c64->vic->getTotalScreenWidth() ,(float)c64->vic->getTotalScreenHeight() );
}

- (OEIntSize)bufferSize
{
    return OEIntSizeMake((float)c64->vic->getTotalScreenWidth() ,(float)c64->vic->getTotalScreenHeight() );
}

- (BOOL)rendersToOpenGL
{
    return false;
}

- (void)setupEmulation
{
    c64->run();
}

- (void)resetEmulation
{
    c64->reset();
    [super resetEmulation];
}

// ToDo: Fix, I probably forked up somewhere and managed to break stopEmulation (the GUI stop button actually pause)
// pause/resume are working fine however
- (void)stopEmulation
{
    c64->halt();
    didRUN = NO;
    [super stopEmulation];
}

#pragma mark Video & Audio format and size
- (GLenum)pixelFormat
{
    return GL_RGBA;
}

- (GLenum)pixelType
{
    return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat
{
    return GL_RGBA;
}

- (double)audioSampleRate
{
    return sampleRate ? sampleRate : 48000;
}

- (NSTimeInterval)frameInterval
{
    return c64->vic->PAL_REFRESH_RATE;
}

- (NSUInteger)channelCount
{
    return 2;
}

#pragma mark Save State
- (BOOL)saveStateToFileAtPath:(NSString *)fileName
{
    //ToDo: Implement
    return YES;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName
{
    //ToDo: Implement
    return YES;
}

@end
