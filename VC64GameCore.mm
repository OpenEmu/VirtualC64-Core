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

typedef struct
{
    NSUInteger hidCode;
    int rowBit;
    int columnBit;
} _VirtualKeyCodeTriplet;

static const _VirtualKeyCodeTriplet _VirtualKeyCodesTable[] = {
    { kHIDUsage_Keyboard0                  , 4 , 3 },
    { kHIDUsage_Keyboard1                  , 7 , 0 },
    { kHIDUsage_Keyboard2                  , 7 , 3 },
    { kHIDUsage_Keyboard3                  , 1 , 0 },
    { kHIDUsage_Keyboard4                  , 1 , 3 },
    { kHIDUsage_Keyboard5                  , 2 , 0 },
    { kHIDUsage_Keyboard6                  , 2 , 3 },
    { kHIDUsage_Keyboard7                  , 3 , 0 },
    { kHIDUsage_Keyboard8                  , 3 , 3 },
    { kHIDUsage_Keyboard9                  , 4 , 0 },
    { kHIDUsage_Keyboard0                  , 4 , 3 },
    { kHIDUsage_KeyboardA                  , 1 , 2 },
    { kHIDUsage_KeyboardB                  , 3 , 4 },
    { kHIDUsage_KeyboardC                  , 2 , 4 },
    { kHIDUsage_KeyboardD                  , 2 , 2 },
    { kHIDUsage_KeyboardE                  , 1 , 6 },
    { kHIDUsage_KeyboardF                  , 2 , 5 },
    { kHIDUsage_KeyboardG                  , 3 , 2 },
    { kHIDUsage_KeyboardH                  , 3 , 5 },
    { kHIDUsage_KeyboardI                  , 4 , 1 },
    { kHIDUsage_KeyboardJ                  , 4 , 2 },
    { kHIDUsage_KeyboardK                  , 4 , 5 },
    { kHIDUsage_KeyboardL                  , 5 , 2 },
    { kHIDUsage_KeyboardM                  , 4 , 4 },
    { kHIDUsage_KeyboardN                  , 4 , 7 },
    { kHIDUsage_KeyboardO                  , 4 , 6 },
    { kHIDUsage_KeyboardP                  , 5 , 1 },
    { kHIDUsage_KeyboardQ                  , 7 , 6 },
    { kHIDUsage_KeyboardR                  , 2 , 1 },
    { kHIDUsage_KeyboardS                  , 1 , 5 },
    { kHIDUsage_KeyboardT                  , 2 , 6 },
    { kHIDUsage_KeyboardU                  , 3 , 6 },
    { kHIDUsage_KeyboardV                  , 3 , 7 },
    { kHIDUsage_KeyboardW                  , 1 , 1 },
    { kHIDUsage_KeyboardX                  , 2 , 7 },
    { kHIDUsage_KeyboardY                  , 3 , 1 },
    { kHIDUsage_KeyboardZ                  , 1 , 4 },
    { kHIDUsage_KeyboardGraveAccentAndTilde, 7 , 1 }, // Grave Accent and Tilde
    { kHIDUsage_KeyboardHyphen             , 5 , 3 }, // - or _
    { kHIDUsage_KeyboardEqualSign          , 6 , 5 }, // = or +
    { kHIDUsage_KeyboardQuote              , 6 , 2 }, // ' or "
//    { kHIDUsage_KeyboardOpenBracket        , kVK_ANSI_LeftBracket   , nil          }, // [ or {
//    { kHIDUsage_KeyboardCloseBracket       , kVK_ANSI_RightBracket  , nil          }, // ] or }
    { kHIDUsage_KeyboardBackslash          , 5 , 0 }, // \ or |
    { kHIDUsage_KeyboardSemicolon          , 5 , 5 }, // ; or :
    { kHIDUsage_KeyboardComma              , 5 , 7 }, // , or <
    { kHIDUsage_KeyboardPeriod             , 5 , 4 }, // . or >
    { kHIDUsage_KeyboardSlash              , 6 , 7 }, // / or ?
    { kHIDUsage_KeyboardReturnOrEnter      , 0 , 1 },
//    { kHIDUsage_KeyboardTab                , kVK_Tab                , @"⇥"         },
    { kHIDUsage_KeyboardSpacebar           , 7 , 4 },
    { kHIDUsage_KeyboardDeleteOrBackspace  , 0 , 0 },
//    { kHIDUsage_KeyboardEscape             , kVK_Escape             , @"⎋"         },
    { kHIDUsage_KeyboardLeftShift          , 1 , 7 },
//    { kHIDUsage_KeyboardCapsLock           , kVK_CapsLock           , @"Caps Lock" },
    { kHIDUsage_KeyboardLeftAlt            , 7 , 5 }, // Commodore key (ALT)
    { kHIDUsage_KeyboardLeftControl        , 7 , 2 },
    { kHIDUsage_KeyboardRightShift         , 6 , 4 },
    { kHIDUsage_KeyboardRightAlt           , 7 , 5 }, // Commodore key (ALT)
    { kHIDUsage_KeyboardF1                 , 0 , 4 },
    //{ kHIDUsage_KeyboardF2                 , kVK_F2 , @"F2" },
    { kHIDUsage_KeyboardF3                 , 0 , 5 },
    //{ kHIDUsage_KeyboardF4                 , kVK_F4 , @"F4" },
    { kHIDUsage_KeyboardF5                 , 0 , 6 },
    //{ kHIDUsage_KeyboardF6                 , kVK_F6 , @"F6" },
    { kHIDUsage_KeyboardF7                 , 0 , 3 },
    //{ kHIDUsage_KeyboardF8                 , kVK_F8 , @"F8" },
    { kHIDUsage_KeyboardLeftArrow          , 0 , 2 },
//    { kHIDUsage_KeyboardRightArrow         , kVK_RightArrow         , @"→"         },
//    { kHIDUsage_KeyboardDownArrow          , kVK_DownArrow          , @"↓"         },
    { kHIDUsage_KeyboardUpArrow            , 0 , 7 },
//    { kHIDUsage_KeyboardNonUSPound         , 0xFFFF                 , @"#"         },
//    { kHIDUsage_KeyboardNonUSBackslash     , 0xFFFF                 , @"|"         },
};

@interface VC64GameCore () <OEC64SystemResponderClient>
{
    C64 *c64;
    NSString *_fileToLoad;
    uint16_t *_soundBuffer;
    uint32_t  _pressedKeys[256];
    BOOL      _didRUN;
}

- (void)pressKey:(char)c;
- (void)releaseKey:(char)c;
- (void)typeText:(NSString *)text;
- (void)typeText:(NSString *)text withDelay:(int)delay;
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

- (oneway void)keyDown:(unsigned short)keyCode
{
    // TODO: should be using NSEvent and Keyboard::pressKey instead
    // TODO: support other C64 special keys and match up keyboard layout

    // Do not accept input before RUN
    if(!_didRUN)
        return;

    // Ignore keys that are already pressed
    if (_pressedKeys[(unsigned char)keyCode])
        return;

    // Ignore command key
    if(keyCode == kHIDUsage_KeyboardLeftGUI || keyCode == kHIDUsage_KeyboardRightGUI)
        return;

    // Translate key from HID to C64 keyboard matrix bits
    for(int i = 0; i < sizeof(_VirtualKeyCodesTable) / sizeof(*_VirtualKeyCodesTable); ++i)
    {
        if(_VirtualKeyCodesTable[i].hidCode == keyCode)
        {
            // Press key
            _pressedKeys[(unsigned char)keyCode] = keyCode;
            c64->keyboard->pressKey(_VirtualKeyCodesTable[i].rowBit, _VirtualKeyCodesTable[i].columnBit);

            break;
        }
    }
}

- (oneway void)keyUp:(unsigned short)keyCode
{
    // TODO: should be using NSEvent and Keyboard::releaseKey instead

    // Do not accept input before RUN
    if(!_didRUN)
        return;

    // Only proceed if the released key is on the records
    if (!_pressedKeys[(unsigned char)keyCode])
        return;

    // Translate key from HID to C64 keyboard matrix bits
    for(int i = 0; i < sizeof(_VirtualKeyCodesTable) / sizeof(*_VirtualKeyCodesTable); ++i)
    {
        if(_VirtualKeyCodesTable[i].hidCode == keyCode)
        {
            // Release key
            _pressedKeys[(unsigned char)keyCode] = 0;
            c64->keyboard->releaseKey(_VirtualKeyCodesTable[i].rowBit, _VirtualKeyCodesTable[i].columnBit);

            break;
        }
    }
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
