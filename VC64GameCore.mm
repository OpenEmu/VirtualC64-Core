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
#import <OpenEmuBase/OERingBuffer.h>
#import "OEC64SystemResponderClient.h"
#import <OpenGL/gl.h>
#import <IOKit/hid/IOHIDUsageTables.h>

#include "C64.h"

#define SOUNDBUFFERSIZE 2048

@interface VC64GameCore () <OEC64SystemResponderClient>
{
    C64 *c64;
    NSString *_fileToLoad;
    uint16_t *_soundBuffer;
    uint32_t  _pressedKeys[256];
    BOOL      _didRUN;
}

- (int)translateKey:(char)key plainkey:(char)plainkey keycode:(short)keycode flags:(int)flags;
- (void)pressKey:(char)c;
- (void)releaseKey:(char)c;
- (void)typeText:(NSString *)text;
- (void)typeText:(NSString *)text withDelay:(int)delay;
- (BOOL)isC64ReadyToRUN;
- (BOOL)loadBIOSRoms;
@end

@implementation VC64GameCore

- (id)init
{
    if((self = [super init]))
    {
        c64 = new C64();

        _soundBuffer = (uint16_t *)malloc(SOUNDBUFFERSIZE * sizeof(uint16_t));
        memset(_soundBuffer, 0, SOUNDBUFFERSIZE * sizeof(uint16_t));

        // Keyboard initialization
        for (int i = 0; i < 256; i++) {
            _pressedKeys[i] = 0;
        }
    }

    return self;
}

- (void)dealloc
{
    delete c64;
    free(_soundBuffer);
}

#pragma mark - Execution

- (BOOL)loadFileAtPath:(NSString *)path
{
    _fileToLoad = [[NSString alloc] initWithString:path];

    // System
    // TODO: Determine region
    c64->setNTSC();

    if(![self loadBIOSRoms])
        return NO;

    // Peripherals
    c64->setWarpLoad(false); // Leave disabled otherwise audio can get slightly out of sync
    c64->floppy->setSendSoundMessages(false);
    c64->floppy->setBitAccuracy(true); // Disable to put drive in a faster, but less compatible read-only mode

    // Audio
    c64->setReSID(true);
    c64->setChipModel(MOS6581); // MOS6581 or MOS8580
    c64->setSamplingMethod(SAMPLE_FAST);
    c64->setAudioFilter(false);

    return YES;
}

- (void)setupEmulation
{
    // Power on sub components
    c64->sid->run();

    c64->cpu->clearErrorState();
    c64->floppy->cpu->clearErrorState();
    c64->restartTimer();
}

- (void)executeFrame
{
    // Lazy/Late Init, we need to send RUN when the system is ready
    if([self isC64ReadyToRUN])
    {
        NSString *fileExtension = [[_fileToLoad pathExtension] lowercaseString];

        if([fileExtension isEqualToString:@"d64"] ||
           [fileExtension isEqualToString:@"p00"] ||
           [fileExtension isEqualToString:@"prg"] ||
           [fileExtension isEqualToString:@"t64"])
        {
            if(c64->mountArchive(D64Archive::archiveFromArbitraryFile([_fileToLoad UTF8String])) &&
               c64->flushArchive(D64Archive::archiveFromArbitraryFile([_fileToLoad UTF8String]), 0))
            {
                [self typeText:@"RUN\n" withDelay:500000];
                //[self typeText:@"LOAD \"*\",8,1\n" withDelay:500000];
                //[self typeText:@"LOAD \"$\",8\n" withDelay:500000];
                //[self typeText:@"LIST\n" withDelay:500000];
            }
        }
        else if([fileExtension isEqualToString:@"tap"])
        {
            if(c64->insertTape(TAPArchive::archiveFromTAPFile([_fileToLoad UTF8String])))
            {
                [self typeText:@"LOAD\n" withDelay:500000];

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    usleep(400000);
                    c64->datasette.pressPlay();
                });
            }
        }
        else if([fileExtension isEqualToString:@"crt"])
        {
            if(c64->attachCartridge(Cartridge::cartridgeFromFile([_fileToLoad UTF8String])))
                c64->reset();
        }

        _didRUN = YES;
    }

    // Run the game loop ourselves
    int cyclesToRun = c64->vic->getCyclesPerFrame();

    for(int i=0; i<cyclesToRun; ++i)
        c64->executeOneCycle();

    int samples = c64->sid->getSampleRate() / (c64->isPAL() ? PAL_REFRESH_RATE : NTSC_REFRESH_RATE);

    if(_didRUN)
    {
        for(unsigned i = 0; i < samples; i++)
        {
            float bytes = c64->sid->readData();
            bytes = bytes * 32767.0;
            _soundBuffer[i] = (uint16_t)bytes;
        }

        [[self ringBufferAtIndex:0] write:_soundBuffer maxLength:samples * sizeof(uint16_t)];
    }
}

- (void)resetEmulation
{
    c64->reset();
    _didRUN = NO;
}

- (void)stopEmulation
{
    c64->halt();
    _didRUN = NO;

    [super stopEmulation];
}

- (NSTimeInterval)frameInterval
{
    return c64->isPAL() ? PAL_REFRESH_RATE : NTSC_REFRESH_RATE;
}

// Doesn't seem to work correctly, audio still goes out of sync
//- (void)fastForward:(BOOL)flag
//{
//    flag ? c64->setAlwaysWarp(true) : c64->setAlwaysWarp(false);
//
//    [super fastForward:flag];
//}

#pragma mark - Video

- (const void *)videoBuffer
{
    return c64->vic->screenBuffer();
}

- (OEIntSize)bufferSize
{
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

#pragma mark - Audio

- (double)audioSampleRate
{
    return c64->sid->getSampleRate();
}

- (NSUInteger)channelCount
{
    return 1;
}

#pragma mark - Save States

- (BOOL)saveStateToFileAtPath:(NSString *)fileName
{
//    c64->suspend();
//
//    Snapshot *saveState = new Snapshot;
//    c64->saveToSnapshot(saveState);
//    saveState->writeToFile([fileName UTF8String]);
//
//    c64->resume();
//
//    return YES;
    return NO;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName
{
//    c64->suspend();
//
//    Snapshot *saveState = new Snapshot;
//    saveState->readFromFile([fileName UTF8String]);
//    c64->loadFromSnapshot(saveState);
//
//    c64->resume();
//
//    return YES;
    return NO;
}

#pragma mark - Input

- (oneway void)mouseMovedAtPoint:(OEIntPoint)point
{

}

- (oneway void)leftMouseDownAtPoint:(OEIntPoint)point
{

}

- (oneway void)leftMouseUp
{

}

- (oneway void)rightMouseDownAtPoint:(OEIntPoint)point
{

}

- (oneway void)rightMouseUp
{

}

- (int)translateKey:(char)key plainkey:(char)plainkey keycode:(short)keycode flags:(int)flags
{
    switch (keycode) {
        case kHIDUsage_KeyboardF1: return Keyboard::C64KEY_F1;
        case kHIDUsage_KeyboardF2: return Keyboard::C64KEY_F2;
        case kHIDUsage_KeyboardF3: return Keyboard::C64KEY_F3;
        case kHIDUsage_KeyboardF4: return Keyboard::C64KEY_F4;
        case kHIDUsage_KeyboardF5: return Keyboard::C64KEY_F5;
        case kHIDUsage_KeyboardF6: return Keyboard::C64KEY_F6;
        case kHIDUsage_KeyboardF7: return Keyboard::C64KEY_F7;
        case kHIDUsage_KeyboardF8: return Keyboard::C64KEY_F8;
        case kHIDUsage_KeyboardDeleteOrBackspace: return (flags & NSShiftKeyMask) ? Keyboard::C64KEY_INS : Keyboard::C64KEY_DEL;
        case kHIDUsage_KeyboardReturnOrEnter: return Keyboard::C64KEY_RET;
        case kHIDUsage_KeyboardLeftArrow: return Keyboard::C64KEY_CL;
        case kHIDUsage_KeyboardRightArrow: return Keyboard::C64KEY_CR;
        case kHIDUsage_KeyboardUpArrow: return Keyboard::C64KEY_CU;
        case kHIDUsage_KeyboardDownArrow: return Keyboard::C64KEY_CD;
        //case MAC_HAT: return '^';
        //case MAC_TILDE_US: if (plainkey != '<' && plainkey != '>') return Keyboard::C64KEY_ARROW; else break;
    }

    if (flags & NSAlternateKeyMask) {
        // Commodore key (ALT) is pressed
        return (int)plainkey | Keyboard::C64KEY_COMMODORE;
    } else {
        // No special translation needed here
        return (int)key;
    }
}

- (oneway void)keyDown:(unsigned short)keyHIDCode characters:(NSString *)characters charactersIgnoringModifiers:(NSString *)charactersIgnoringModifiers flags:(NSEventModifierFlags)modifierFlags
{
    // Do not accept input before RUN
    if(!_didRUN)
        return;

    unsigned char  c       = [characters UTF8String][0];
    unsigned char  c_unmod = [charactersIgnoringModifiers UTF8String][0];
    unsigned short keycode = keyHIDCode;
    unsigned int   flags   = modifierFlags;
    int c64key;

    // NSLog(@"keyDown: '%c' keycode: %02X flags: %08X", (char)c, keycode, flags);

    // Ignore keys that are already pressed
    if (_pressedKeys[(unsigned char)keycode])
        return;

    // Ignore command key
    if (flags & NSCommandKeyMask)
        return;

    // Remove alternate key modifier if present
    if (flags & NSAlternateKeyMask)
        c = [charactersIgnoringModifiers UTF8String][0];

    // Translate key
    if (!(c64key = [self translateKey:c plainkey:c_unmod keycode:keycode flags:flags]))
        return;

    // Press key
    // NSLog(@"Storing key %c for keycode %ld",c64key, (long)keycode);
    _pressedKeys[(unsigned char)keycode] = c64key;
    c64->keyboard->pressKey(c64key);
}

- (oneway void)keyUp:(unsigned short)keyHIDCode characters:(NSString *)characters charactersIgnoringModifiers:(NSString *)charactersIgnoringModifiers flags:(NSEventModifierFlags)modifierFlags
{
    // Do not accept input before RUN
    if(!_didRUN)
        return;

    unsigned short keycode = keyHIDCode;
    //unsigned int   flags   = modifierFlags;

    // NSLog(@"keyUp: keycode: %02X flags: %08X", keycode, flags);

    // Only proceed if the released key is on the records
    if (!_pressedKeys[(unsigned char)keycode])
        return;

    // Release key
    // NSLog(@"Releasing stored key %c for keycode %ld",pressedKeys[keycode], (long)keycode);
    c64->keyboard->releaseKey(_pressedKeys[keycode]);
    _pressedKeys[(unsigned char)keycode] = 0;
}

- (oneway void)didPushC64Button:(OEC64Button)button forPlayer:(NSUInteger)player;
{
    // Port 2 is used as the default for most programs and games due to technical reasons
    if(button == OEC64JoystickUp) { c64->joystick2->SetAxisY(JOYSTICK_AXIS_Y_UP); }
    if(button == OEC64JoystickDown) { c64->joystick2->SetAxisY(JOYSTICK_AXIS_Y_DOWN); }
    if(button == OEC64JoystickLeft) { c64->joystick2->SetAxisX(JOYSTICK_AXIS_X_LEFT); }
    if(button == OEC64JoystickRight) { c64->joystick2->SetAxisX(JOYSTICK_AXIS_X_RIGHT); }
    if(button == OEC64ButtonFire) { c64->joystick2->SetButtonPressed(true); }
}

- (oneway void)didReleaseC64Button:(OEC64Button)button forPlayer:(NSUInteger)player;
{
    if(button == OEC64JoystickUp) { c64->joystick2->SetAxisY(JOYSTICK_AXIS_NONE); }
    if(button == OEC64JoystickDown) { c64->joystick2->SetAxisY(JOYSTICK_AXIS_NONE); }
    if(button == OEC64JoystickLeft) { c64->joystick2->SetAxisX(JOYSTICK_AXIS_NONE); }
    if(button == OEC64JoystickRight) { c64->joystick2->SetAxisX(JOYSTICK_AXIS_NONE); }
    if(button == OEC64ButtonFire) { c64->joystick2->SetButtonPressed(false); }
}

#pragma mark - Misc & Helpers

- (BOOL)isC64ReadyToRUN
{
    // HACK: Wait until enough cycles have passed to assume we're at the prompt
    // and ready to RUN whatever has been flashed ("flush") into memory
    if (c64->getCycles() >= 2803451 && !_didRUN)
        return YES;
    else
        return NO;
}

- (BOOL)loadBIOSRoms
{
    // Get The 4 BIOS ROMs

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

    // Load Basic, Kernel, Char and C1541 Floppy ROMs
    c64->loadRom([basicROM UTF8String]);
    c64->loadRom([kernelROM UTF8String]);
    c64->loadRom([charROM UTF8String]);
    c64->loadRom([C1541ROM UTF8String]);

    return YES;
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

@end
