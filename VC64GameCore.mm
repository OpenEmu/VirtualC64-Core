/*
 Copyright (c) 2015, OpenEmu Team


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

#import "OEC64SystemResponderClient.h"
#import <OpenEmuBase/OERingBuffer.h>
#import <OpenGL/gl.h>

#include "C64.h"


#define AUDIOBUFFERSIZE 2048


@interface VC64GameCore () <OEC64SystemResponderClient>
{
    C64 *c64;

    NSString *fileToLoad;
    uint16_t *audioBuffer;
    BOOL      didRUN;
}

- (void)pressKey:(char)c;
- (void)releaseKey:(char)c;
- (void)typeText:(NSString *)text;
- (void)typeText:(NSString *)text withDelay:(int)delay;
@end
/*  ToDo:   Implements Inputs, SaveState, Sounds, also stopEmulation is broken        */

@implementation VC64GameCore

#pragma mark Input
// ToDo
- (void)mouseMovedAtPoint:(OEIntPoint)location;
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

- (void)keyUp:(unsigned short)keyCode
{
    // Do not accept input before RUN
    if(!didRUN)
        return;
    
    c64->keyboard->releaseKey([self MatrixRowForKeyCode:keyCode],[self MatrixColumnForKeyCode:keyCode]);
}
- (void)keyDown:(unsigned short)keyCode
{
    // Do not accept input before RUN
    if(!didRUN)
        return;
    
    c64->keyboard->pressKey([self MatrixRowForKeyCode:keyCode],[self MatrixColumnForKeyCode:keyCode]);
}

- (oneway void)didPushC64Button:(OEC64Button)button forPlayer:(NSUInteger)player;
{
    if(button == OEC64JoystickUp) { c64->joystick1->SetAxisY(JOYSTICK_AXIS_Y_UP); }
    if(button == OEC64JoystickDown) { c64->joystick1->SetAxisY(JOYSTICK_AXIS_Y_DOWN); }
    if(button == OEC64JoystickLeft) { c64->joystick1->SetAxisX(JOYSTICK_AXIS_X_LEFT); }
    if(button == OEC64JoystickRight) { c64->joystick1->SetAxisX(JOYSTICK_AXIS_X_RIGHT); }
    if(button == OEC64ButtonFire) { c64->joystick1->SetButtonPressed(true); }
}

- (oneway void)didReleaseC64Button:(OEC64Button)button forPlayer:(NSUInteger)player;
{
    if(button == OEC64JoystickUp) { c64->joystick1->SetAxisY(JOYSTICK_AXIS_NONE); }
    if(button == OEC64JoystickDown) { c64->joystick1->SetAxisY(JOYSTICK_AXIS_NONE); }
    if(button == OEC64JoystickLeft) { c64->joystick1->SetAxisX(JOYSTICK_AXIS_NONE); }
    if(button == OEC64JoystickRight) { c64->joystick1->SetAxisX(JOYSTICK_AXIS_NONE); }
    if(button == OEC64ButtonFire) { c64->joystick1->SetButtonPressed(false); }
}

#pragma mark Init
- (id)init
{
    if((self = [super init]))
    {
        c64 = new C64();

        audioBuffer = (uint16_t *)malloc(AUDIOBUFFERSIZE * sizeof(uint16_t));
        memset(audioBuffer, 0, AUDIOBUFFERSIZE * sizeof(uint16_t));
    }

    return self;
}

- (void)dealloc
{
    delete c64;
    free(audioBuffer);
}

#pragma mark Execution

- (BOOL)loadFileAtPath:(NSString *)path
{
    fileToLoad = [[NSString alloc] initWithString:path];

    // Todo: Should we determine region ?
    c64->setNTSC();

    if(![self loadBIOSRoms])
        return NO;

    return YES;
}

- (void)setupEmulation
{
    // Power on sub components
    c64->sid->run();

    c64->cpu->clearErrorState();
	c64->floppy->cpu->clearErrorState();
    c64->floppy->setBitAccuracy(true); // Disable to put drive in a faster, but less compatible read-only mode
	c64->restartTimer();
    
    // Peripherals
    //[c64 setWarpLoad:[defaults boolForKey:VC64WarpLoadKey]];
    //[[c64 vc1541] setSendSoundMessages:[defaults boolForKey:VC64DriveNoiseKey]];
    
    // Audio
    //[c64 setReSID:[defaults boolForKey:VC64SIDReSIDKey]];
    //[c64 setAudioFilter:[defaults boolForKey:VC64SIDFilterKey]];
    //[c64 setChipModel:[defaults boolForKey:VC64SIDChipModelKey]];
    //[c64 setSamplingMethod:[defaults boolForKey:VC64SIDSamplingMethodKey]];
}

- (void)executeFrame
{
    // Lazy/Late Init, we need to send RUN when the system is ready
    if([self isC64ReadyToRUN])
    {
        if([[[fileToLoad pathExtension] lowercaseString] isEqualToString:@"d64"] ||
           [[[fileToLoad pathExtension] lowercaseString] isEqualToString:@"p00"] ||
           [[[fileToLoad pathExtension] lowercaseString] isEqualToString:@"prg"] ||
           [[[fileToLoad pathExtension] lowercaseString] isEqualToString:@"t64"])
        {
            c64->mountArchive(D64Archive::archiveFromArbitraryFile([fileToLoad UTF8String]));
            c64->flushArchive(D64Archive::archiveFromArbitraryFile([fileToLoad UTF8String]), 0);

            [self typeText:@"RUN\n" withDelay:500000];
        }
        else if([[[fileToLoad pathExtension] lowercaseString] isEqualToString:@"tap"])
        {
            c64->insertTape(TAPArchive::archiveFromTAPFile([fileToLoad UTF8String]));

            [self typeText:@"LOAD\n" withDelay:500000];

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                usleep(400000);
                c64->datasette.pressPlay();
            });
        }
        else if([[[fileToLoad pathExtension] lowercaseString] isEqualToString:@"crt"])
        {
            c64->attachCartridge(Cartridge::cartridgeFromFile([fileToLoad UTF8String]));
            c64->reset();
        }

        didRUN = YES;
    }

    int cyclesToRun = c64->vic->getCyclesPerFrame();

    for(int i=0; i<cyclesToRun; ++i)
        c64->executeOneCycle();

    int audioBufferSize = c64->sid->getSampleRate() / c64->vic->getFramesPerSecond();

    if(didRUN)
    {
        for(unsigned i = 0; i < audioBufferSize; i++)
        {
            float bytes = c64->sid->readData();
            bytes = bytes * 32767.0;
            audioBuffer[i] = (uint16_t)bytes;
        }
        [[self ringBufferAtIndex:0] write:audioBuffer maxLength:audioBufferSize * sizeof(uint16_t)];
    }
}

/*- (void)setPauseEmulation:(BOOL)pauseEmulation
{
    if(pauseEmulation)
        c64->suspend();
    else
        c64->resume();
    
    [super setPauseEmulation:pauseEmulation];
}*/

- (void)resetEmulation
{
    c64->reset();
    didRUN = NO;
}

// ToDo: Fix, I probably forked up somewhere and managed to break stopEmulation (the GUI stop button actually pause)
// pause/resume are working fine however
- (void)stopEmulation
{
    c64->halt();
    didRUN = NO;
    [super stopEmulation];
}

#pragma mark Video
- (const void *)videoBuffer
{
    return c64->vic->screenBuffer();
}

- (OEIntSize)bufferSize
{
    //return OEIntSizeMake(c64->vic->getTotalScreenWidth() ,c64->vic->getTotalScreenHeight() );
    return OEIntSizeMake(NTSC_PIXELS, NTSC_RASTERLINES);
}

- (OEIntRect)screenRect
{
    return OEIntRectMake(0, 0, NTSC_PIXELS, NTSC_RASTERLINES);
}

- (OEIntSize)aspectSize
{
    return OEIntSizeMake(NTSC_PIXELS * (3.0/4.0), NTSC_RASTERLINES);
}

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

#pragma mark Audio
- (double)audioSampleRate
{
    return c64->sid->getSampleRate();
}

- (NSTimeInterval)frameInterval
{
    return c64->vic->getFramesPerSecond();
}

- (NSUInteger)channelCount
{
    return 1;
}

#pragma mark Save State
/*
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
}*/

#pragma mark Misc & Helpers
- (BOOL)isC64ReadyToRUN
{
    // HACK: Wait until enough cycles have passed to assume we're at the prompt
    // and ready to RUN whatever has been flashed ("flush") into memory
    if (c64->getCycles() >= 2803451 && !didRUN)
        return YES;
    else
        return NO;
}

//  Helper methods to load the BIOS ROMS
- (BOOL)loadBIOSRoms
{
    // Get The 4 BIOS ROMS

    // BASIC ROM
    NSString *basicROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"Basic.rom"];
    if(!c64->mem->isBasicRom([basicROM UTF8String]))
    {
        NSLog(@"VirtualC64: %@ is not a valid Basic ROM!", basicROM);
        return NO;
    }

    // Kernel ROM
    NSString *kernelROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"Kernel.rom"];
    if(!c64->mem->isKernelRom([kernelROM UTF8String]))
    {
        NSLog(@"VirtualC64: %@ is not a valid Kernel ROM!", kernelROM);
        return NO;
    }

    // Char ROM
    NSString *charROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"Char.rom"];
    if(!c64->mem->isCharRom([charROM UTF8String]))
    {
        NSLog(@"VirtualC64: %@ is not a valid Char ROM!", charROM);
        return NO;
    }

    // C1541 aka Floppy ROM
    NSString *C1541ROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"C1541.rom"];

    // We've Basic, Kernel and Char and CP1541 Floppy ROMS, load them into c64
    c64->loadRom([basicROM UTF8String]);
    c64->loadRom([kernelROM UTF8String]);
    c64->loadRom([charROM UTF8String]);
    c64->loadRom([C1541ROM UTF8String]);

    return YES;
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
            // F1
        case 122:
            row = 0;
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
            // F1
        case 122:
            row = 5;
            break;
            //...
            /* ToDo: Special Keys like C= */
            
        default:
            row=0;
            break;
    }
    
    return row;
}

- (void)pressKey:(char)c
{
    c64->keyboard->pressKey(c);
}

- (void)releaseKey:(char)c
{
    c64->keyboard->releaseKey(c);
}

- (void)typeText:(NSString *)text
{
    [self typeText:text withDelay:0];
}

- (void)typeText:(NSString *)text withDelay:(int)delay
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self _typeText:text withDelay:delay];
    });
}

- (void)_typeText:(NSString *)text withDelay:(int)delay
{
    const unsigned MAXCHARS = 256;
    const unsigned KEYDELAY = 27500;
    unsigned i;

    fprintf(stderr,"Typing: ");

    usleep(delay);
    for (i = 0; i < [text length] && i < MAXCHARS; i++) {

        unichar uc = [text characterAtIndex:i];
        char c = (char)uc;

        if (isupper(c))
            c = tolower(c);

        fprintf(stderr,"%c",c);

        usleep(KEYDELAY);
        [self pressKey:c];
        usleep(KEYDELAY);
        [self releaseKey:c];
    }

    if (i != [text length]) {
        // Abbreviate text by three dots
        for (i = 0; i < 3; i++) {
            [self pressKey:'.'];
            usleep(KEYDELAY);
            [self releaseKey:'.'];
            usleep(KEYDELAY);
        }
    }

    fprintf(stderr,"\n");
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
