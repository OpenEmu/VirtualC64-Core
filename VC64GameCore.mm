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
#import "OEComputerSystemResponderClient.h"
#import <OpenGL/gl.h>

#define SAMPLERATE 44100
#define SIZESOUNDBUFFER 44100 / 60 * 4


@interface VC64GameCore () <OEComputerSystemResponderClient>
{
    uint16_t *videoBuffer;
    int videoWidth, videoHeight;
    int16_t pad[2][16];
    NSString *romName;
    double sampleRate;
}

@end

/*  ToDo:   Implements Inputs, SaveState, Sounds, also stopEmulation is broken        */

@implementation VC64GameCore

static VC64GameCore *current;
static OERingBuffer *ringBuffer;

#pragma mark VirtualC64: Input
// ToDo
- (void)mouseMoved:(OEIntPoint)location
{
    //  ToDo
}
- (void)leftMouseDown
{
    //  ToDo
}
- (void)leftMouseUp
{
    //  ToDo
}
- (void)rightMouseDown
{
    //  ToDo
}
- (void)rightMouseUp
{
    //  ToDo
}

/* 
 The key is specified in the C64 row/column format:

 The C64 keyboard matrix:
 
            0           1           2           3       4           5       6       7
 
 0          DEL         RETURN      CUR LR      F7      F1          F3      F5      CUR UD
 1          3           W           A           4       Z           S       E       LSHIFT
 2          5           R           D           6       C           F       T       X
 3          7           Y           G           8       B           H       U       V
 4          9           I           J           0       M           K       O       N
 5          +           P           L           -       .           :       @       ,
 6          LIRA        *           ;           HOME    RSHIFT      =       ^       /
 7          1           <-          CTRL        2       SPACE       C=      Q       STOP
 
*/

- (void)keyUp:(unsigned short)keyCode
{
    //  ToDo
    c64->keyboard->releaseKey([self MatrixRowForKeyCode:keyCode],[self MatrixColumnForKeyCode:keyCode]);
}
- (void)keyDown:(unsigned short)keyCode
{
    //  ToDo
    c64->keyboard->pressKey([self MatrixRowForKeyCode:keyCode],[self MatrixColumnForKeyCode:keyCode]);
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
        NSLog(@"VirtualC64: %@ is not a valid Char ROM!", charROM);
        return NO;
    }
    
    // C1541 aka Floppy ROM
    NSString *C1541ROM = [[[[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"]
                                                stringByAppendingPathComponent:@"Application Support"]
                                                stringByAppendingPathComponent:@"OpenEmu"]
                                                stringByAppendingPathComponent:@"BIOS"]
                                                stringByAppendingPathComponent:@"C1541.rom"];
        
    // We've Basic, Kernel and Char and CP1541 Floppy ROMS, load them into c64
    c64->loadRom([basicROM UTF8String]);
    c64->loadRom([kernelROM UTF8String]);
    c64->loadRom([charROM UTF8String]);
    c64->loadRom([C1541ROM UTF8String]);
    
    return YES;
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
    c64->suspend();
    
    Snapshot *saveState = new Snapshot;
    c64->saveToSnapshot(saveState);
    saveState->writeToFile([fileName UTF8String]);
    
    c64->resume();
    
    return YES;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName
{
    c64->suspend();
    
    Snapshot *saveState = new Snapshot;
    saveState->readFromFile([fileName UTF8String]);
    c64->loadFromSnapshot(saveState);
    
    c64->resume();
    
    return YES;
}

#pragma Misc & Helpers
// Keyboard Matrix Helpers
- (int)MatrixRowForKeyCode:(unsigned short)keyCode
{
    int row;
    
    switch (keyCode)
    {
            // A
        case 0:
            row = 1;
            break;
            // B
        case 11:
            row = 3;
            break;
            // C
        case 8:
            row = 2;
            break;
            // D
        case 2:
            row = 2;
            break;
            // E
        case 14:
            row = 1;
            break;
            // F
        case 3:
            row = 2;
            break;
            // G
        case 5:
            row = 3;
            break;
            // H
        case 4:
            row = 3;
            break;
            // I
        case 34:
            row = 4;
            break;
            // J
        case 38:
            row = 4;
            break;
            // K
        case 40:
            row = 4;
            break;
            // L
        case 37:
            row = 5;
            break;
            // M
        case 46:
            row = 1;
            break;
            // N
        case 45:
            row = 4;
            break;
            // O
        case 31:
            row = 4;
            break;
            // P
        case 35:
            row = 5;
            break;
            // Q
        case 12:
            row = 7;
            break;
            // R
        case 15:
            row = 2;
            break;
            // S
        case 1:
            row = 1;
            break;
            // T
        case 17:
            row = 2;
            break;
            // U
        case 32:
            row = 3;
            break;
            // V
        case 9:
            row = 3;
            break;
            // W
        case 13:
            row = 1;
            break;
            // X
        case 7:
            row = 2;
            break;
            // Y
        case 6:
            row = 3;
            break;
            // Z
        case 16:
            row = 1;
            break;
            // 1
        case 18:
        case 83:
            row = 7;
            break;
            // 2
        case 19:
        case 84:
            row = 7;
            break;
            // 3
        case 20:
        case 85:
            row = 1;
            break;
            // 4
        case 21:
        case 86:
            row = 1;
            break;
            // 5
        case 23:
        case 87:
            row = 2;
            break;
            // 6
        case 22:
        case 88:
            row = 2;
            break;
            // 7
        case 26:
        case 89:
            row = 3;
            break;
            // 8
        case 28:
        case 91:
            row = 3;
            break;
            // 9
        case 25:
        case 92:
            row = 4;
            break;
            // 0
        case 29:
        case 82:
            row = 4;
            break;
            // RETURN
        case 36:
        case 76:
            row = 0;
            break;
            // SPACE
        case 49:
            row = 7;
            break;
            // HOME
        case 115:
            row = 6;
            break;
            // STOP
        case 119:
            row = 7;
            break;
            //...
            /* ToDo: Special Keys like C= */
            
        default:
            row=0;
            break;
    }
    
    return row;
}

- (int)MatrixColumnForKeyCode:(unsigned short)keyCode
{
    int row;
    
    switch (keyCode)
    {
            // A
        case 0:
            row = 2;
            break;
            // B
        case 11:
            row = 4;
            break;
            // C
        case 8:
            row = 4;
            break;
            // D
        case 2:
            row = 2;
            break;
            // E
        case 14:
            row = 6;
            break;
            // F
        case 3:
            row = 5;
            break;
            // G
        case 5:
            row = 2;
            break;
            // H
        case 4:
            row = 5;
            break;
            // I
        case 34:
            row = 1;
            break;
            // J
        case 38:
            row = 2;
            break;
            // K
        case 40:
            row = 5;
            break;
            // L
        case 37:
            row = 2;
            break;
            // M
        case 46:
            row = 4;
            break;
            // N
        case 45:
            row = 7;
            break;
            // O
        case 31:
            row = 6;
            break;
            // P
        case 35:
            row = 1;
            break;
            // Q
        case 12:
            row = 6;
            break;
            // R
        case 15:
            row = 1;
            break;
            // S
        case 1:
            row = 5;
            break;
            // T
        case 17:
            row = 6;
            break;
            // U
        case 32:
            row = 6;
            break;
            // V
        case 9:
            row = 7;
            break;
            // W
        case 13:
            row = 1;
            break;
            // X
        case 7:
            row = 7;
            break;
            // Y
        case 6:
            row = 1;
            break;
            // Z
        case 16:
            row = 4;
            break;
            // 1
        case 18:
        case 83:
            row = 0;
            break;
            // 2
        case 19:
        case 84:
            row = 3;
            break;
            // 3
        case 20:
        case 85:
            row = 0;
            break;
            // 4
        case 21:
        case 86:
            row = 3;
            break;
            // 5
        case 23:
        case 87:
            row = 0;
            break;
            // 6
        case 22:
        case 88:
            row = 3;
            break;
            // 7
        case 26:
        case 89:
            row = 0;
            break;
            // 8
        case 28:
        case 91:
            row = 3;
            break;
            // 9
        case 25:
        case 92:
            row = 0;
            break;
            // 0
        case 29:
        case 82:
            row = 3;
            break;
            // RETURN
        case 36:
        case 76:
            row = 1;
            break;
            // SPACE
        case 49:
            row = 4;
            break;
            // HOME
        case 115:
            row = 3;
            break;
            // STOP
        case 119:
            row = 7;
            break;
            //...
            /* ToDo: Special Keys like C= */
            
        default:
            row=0;
            break;
    }
    
    return row;
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


@end
