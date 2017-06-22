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
#import "C64.h"
#import "OEC64SystemResponderClient.h"

#import <OpenGL/gl.h>
#import <Carbon/Carbon.h>
#import <OpenEmuBase/OERingBuffer.h>

#define SOUNDBUFFERSIZE 2048

@interface VC64GameCore () <OEC64SystemResponderClient>
{
    C64 *c64;
    NSString *_fileToLoad;
    uint16_t *_soundBuffer;
    uint32_t  _pressedKeys[256];
    BOOL      _didRUN;
    
    //  Used to tell the system that the C64 has finished loading and is ready for interaction
    BOOL      isC64Ready;
    
    // Used to control if we are still waiting for the prompt, or if we are finally there
    BOOL      isAtReadyPrompt;
    BOOL      waitingForReady;
    
    //  Used to make sure we don't send more text if it is in the process of auto typing already
    BOOL      isStillTyping;
    
    //Controls weather we have loaded the game or still in the process of doing so
    BOOL      isGameLoading;
    BOOL      isGameLoaded;
}

- (int)translateKey:(char)key plainkey:(char)plainkey keycode:(short)keycode flags:(int)flags;
- (void)pressKey:(char)c;
- (void)releaseKey:(char)c;
- (void)typeText:(NSString *)text;
- (void)typeText:(NSString *)text withDelay:(int)delay;
- (void)checkForReady;
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
        
        isC64Ready = false;
        
        isAtReadyPrompt=false;
        waitingForReady=false;
        
        isStillTyping = false;
        
        isGameLoading=false;
        isGameLoaded=false;

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
    c64->setWarp(false);
    c64->setWarpLoad(false); // Leave disabled otherwise audio can get slightly out of sync
    c64->floppy.setSendSoundMessages(false);
    c64->floppy.setBitAccuracy(true); // Disable to put drive in a faster, but less compatible read-only mode

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
    c64->sid.run();
    c64->cpu.clearErrorState();
    c64->floppy.cpu.clearErrorState();
    c64->restartTimer();

}

- (void)executeFrame
{
    // Run the game loop ourselves
    int rasterLinesToRun = c64->vic.getRasterlinesPerFrame();
    int samples = c64->sid.getSampleRate() / (c64->isPAL() ? PAL_REFRESH_RATE : NTSC_REFRESH_RATE);

    for(int i=0; i < rasterLinesToRun; ++i)
        c64->executeOneLine();

    
    if(_didRUN)
    {
        for(unsigned i = 0; i < samples; i++)
        {
            float bytes = c64->sid.readData();
            bytes = bytes * 32767.0;
            _soundBuffer[i] = (uint16_t)bytes;
        }

        [[self ringBufferAtIndex:0] write:_soundBuffer maxLength:samples * sizeof(uint16_t)];
    }
    else
    {
        if (!isC64Ready)
        {
            [self checkForReady];  //this is called every Execute frame C64 if not at ready prompt.
        }
        else
        {
            if(!isGameLoaded && !isGameLoading)  //If there is not game loaded, and we are not in the process of loading one
            {
                //start the load procedure
                NSString *fileExtension = [[_fileToLoad pathExtension] lowercaseString];

                [self _loadGame:fileExtension ];
            }
            else
            {
                if(isGameLoaded && !_didRUN && !isStillTyping)
                {
                    if (!waitingForReady )
                    {
                        isAtReadyPrompt=false;
                        waitingForReady=true;
                    }
                    if (!isAtReadyPrompt)
                    {
                        [self checkForReady];
                    }
                    else
                    {
                        [self typeText:@"run \n" withDelay:0];
                        _didRUN=true;
                    }
                }
            }
        }
    }
}

- (void)resetEmulation
{
    c64->reset();
    isC64Ready=false;
    isAtReadyPrompt=false;
    isGameLoaded=false;
    isGameLoading=false;
    waitingForReady=false;
    _didRUN = NO;
}

- (void)stopEmulation
{
    c64->halt();
    isC64Ready=false;
    isAtReadyPrompt=false;
    isGameLoaded=false;
    isGameLoading=false;
    waitingForReady=false;
    _didRUN = NO;

    [super stopEmulation];
}

- (NSTimeInterval)frameInterval
{
    return c64->isPAL() ? PAL_REFRESH_RATE : NTSC_REFRESH_RATE;
}

// Doesn't seem to work correctly, audio still goes out of sync
// Use setWarp instead of Always warp
-(void)fastForward:(BOOL)flag
{
   flag ? c64->setWarp(true) : c64->setWarp(false);
    
    [super fastForward:flag];
}

#pragma mark - Video

- (const void *)videoBuffer
{
    return c64->vic.screenBuffer();
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
    return c64->sid.getSampleRate();
}

- (NSUInteger)channelCount
{
    return 1;
}

#pragma mark - Save States

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    c64->suspend();

    Snapshot *saveState = new Snapshot;
    c64->saveToSnapshotSafe(saveState);
    block(saveState->writeToFile(fileName.fileSystemRepresentation),nil);

    c64->resume();
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    c64->suspend();

    Snapshot *saveState = new Snapshot;
    block(saveState->readFromFile(fileName.fileSystemRepresentation),nil);
    c64->loadFromSnapshotSafe(saveState);

    c64->resume();
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
    switch (keycode)
    {
        case kVK_F1: return C64KEY_F1;
        case kVK_F2: return C64KEY_F2;
        case kVK_F3: return C64KEY_F3;
        case kVK_F4: return C64KEY_F4;
        case kVK_F5: return C64KEY_F5;
        case kVK_F6: return C64KEY_F6;
        case kVK_F7: return C64KEY_F7;
        case kVK_F8: return C64KEY_F8;
        case kVK_Delete: return (flags & NSShiftKeyMask) ? C64KEY_INS : C64KEY_DEL;
        case kVK_Return: return C64KEY_RET;
        case kVK_LeftArrow: return C64KEY_CL;
        case kVK_RightArrow: return C64KEY_CR;
        case kVK_UpArrow: return C64KEY_CU;
        case kVK_DownArrow: return C64KEY_CD;
        case kVK_Escape: return C64KEY_RUNSTOP;
        case kVK_Tab: return C64KEY_RESTORE;
        case kVK_ISO_Section: return '^';
        case kVK_ANSI_Grave: if (plainkey != '<' && plainkey != '>') return C64KEY_ARROW; else break;
    }

    if (flags & NSAlternateKeyMask)
    {
        // Commodore key (ALT) is pressed
        return (int)plainkey | C64KEY_COMMODORE;
    }
    else
    {
        // No special translation needed here
        return (int)key;
    }
}

- (oneway void)keyDown:(unsigned short)keyHIDCode characters:(NSString *)characters charactersIgnoringModifiers:(NSString *)charactersIgnoringModifiers flags:(NSEventModifierFlags)modifierFlags
{
    // Do not accept input before RUN
    if(!isC64Ready)
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
    c64->keyboard.pressKey(c64key);
}

- (oneway void)keyUp:(unsigned short)keyHIDCode characters:(NSString *)characters charactersIgnoringModifiers:(NSString *)charactersIgnoringModifiers flags:(NSEventModifierFlags)modifierFlags
{
    // Do not accept input before RUN
    if(!isC64Ready)
        return;

    unsigned short keycode = keyHIDCode;
    //unsigned int   flags   = modifierFlags;

    // NSLog(@"keyUp: keycode: %02X flags: %08X", keycode, flags);

    // Only proceed if the released key is on the records
    if (!_pressedKeys[(unsigned char)keycode])
        return;

    // Release key
    // NSLog(@"Releasing stored key %c for keycode %ld",pressedKeys[keycode], (long)keycode);
    c64->keyboard.releaseKey(_pressedKeys[keycode]);
    _pressedKeys[(unsigned char)keycode] = 0;
}

- (oneway void)didPushC64Button:(OEC64Button)button forPlayer:(NSUInteger)player;
{
    // Port 2 is used as the default for most programs and games due to technical reasons
    if (player == 1)
    {
        if(button == OEC64JoystickUp) { c64->joystickA.setAxisY(JOYSTICK_UP); }
        if(button == OEC64JoystickDown) { c64->joystickA.setAxisY(JOYSTICK_DOWN); }
        if(button == OEC64JoystickLeft) { c64->joystickA.setAxisX(JOYSTICK_LEFT); }
        if(button == OEC64JoystickRight) { c64->joystickA.setAxisX(JOYSTICK_RIGHT); }
        if(button == OEC64ButtonFire) { c64->joystickA.setButtonPressed(true); }
    }
    else if (player ==2)
    {
        if(button == OEC64JoystickUp) { c64->joystickB.setAxisY(JOYSTICK_UP); }
        if(button == OEC64JoystickDown) { c64->joystickB.setAxisY(JOYSTICK_DOWN); }
        if(button == OEC64JoystickLeft) { c64->joystickB.setAxisX(JOYSTICK_LEFT); }
        if(button == OEC64JoystickRight) { c64->joystickB.setAxisX(JOYSTICK_RIGHT); }
        if(button == OEC64ButtonFire) { c64->joystickB.setButtonPressed(true); }
    }
}

- (oneway void)didReleaseC64Button:(OEC64Button)button forPlayer:(NSUInteger)player;
{
    if (player == 1)
    {
        if(button == OEC64JoystickUp) { c64->joystickA.setAxisY(JOYSTICK_RELEASED); }
        if(button == OEC64JoystickDown) { c64->joystickA.setAxisY(JOYSTICK_RELEASED); }
        if(button == OEC64JoystickLeft) { c64->joystickA.setAxisX(JOYSTICK_RELEASED); }
        if(button == OEC64JoystickRight) { c64->joystickA.setAxisX(JOYSTICK_RELEASED); }
        if(button == OEC64ButtonFire) { c64->joystickA.setButtonPressed(false); }
    }
    else if (player == 2)
    {
        if(button == OEC64JoystickUp) { c64->joystickB.setAxisY(JOYSTICK_RELEASED); }
        if(button == OEC64JoystickDown) { c64->joystickB.setAxisY(JOYSTICK_RELEASED); }
        if(button == OEC64JoystickLeft) { c64->joystickB.setAxisX(JOYSTICK_RELEASED); }
        if(button == OEC64JoystickRight) { c64->joystickB.setAxisX(JOYSTICK_RELEASED); }
        if(button == OEC64ButtonFire) { c64->joystickB.setButtonPressed(false); }
    }
}

#pragma mark - Misc & Helpers

- (BOOL)loadBIOSRoms
{
    // Get The 4 BIOS ROMs

    // BASIC ROM
    NSString *basicROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"basic.901226-01.bin"];
    if(!c64->mem.isBasicRom([basicROM UTF8String]))
    {
        NSLog(@"VirtualC64: %@ is not a valid Basic ROM!", basicROM);
        return NO;
    }

    // "Kernal" ROM
    NSString *kernelROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"kernal.901227-03.bin"];
    if(!c64->mem.isKernelRom([kernelROM UTF8String]))
    {
        NSLog(@"VirtualC64: %@ is not a valid Kernal ROM!", kernelROM);
        return NO;
    }

    // Char ROM
    NSString *charROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"characters.901225-01.bin"];
    if(!c64->mem.isCharRom([charROM UTF8String]))
    {
        NSLog(@"VirtualC64: %@ is not a valid Char ROM!", charROM);
        return NO;
    }

    // C1541 aka Floppy ROM
    NSString *C1541ROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"1541-II.355640-01.bin"];
    if(!c64->floppy.mem.is1541Rom([C1541ROM UTF8String]))
    {
        NSLog(@"VirtualC64: %@ is not a valid C1541 ROM!", charROM);
        return NO;
    }

    // Load Basic, Kernel, Char and C1541 Floppy ROMs
    c64->loadRom([basicROM UTF8String]);
    c64->loadRom([kernelROM UTF8String]);
    c64->loadRom([charROM UTF8String]);
    c64->loadRom([C1541ROM UTF8String]);

    return YES;
}

- (void)pressKey:(char)c
{
    c64->keyboard.pressKey(c);
}

- (void)releaseKey:(char)c
{
    c64->keyboard.releaseKey(c);
}

- (void)typeText:(NSString *)text
{
    [self _typeText:text withDelay:0];
}

- (void)typeText:(NSString *)text withDelay:(int)delay
{
    while (isStillTyping)
        usleep(50);
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ [self _typeText:text withDelay:delay]; });
}

- (void)_typeText:(NSString *)text withDelay:(int)delay
{
    const unsigned MAXCHARS = 256;
    const unsigned KEYDELAY = 27500;
    unsigned i;
    
    isStillTyping= true;
    
    fprintf(stderr, "Typing: ");
    
    usleep(delay);
    for (i = 0; i < [text length] && i < MAXCHARS; i++)
    {
        unichar uc = [text characterAtIndex:i];
        char c = (char)uc;
        
        if (isupper(c))
            c = tolower(c);
        
        fprintf(stderr, "%c",c);
        
        usleep(KEYDELAY);
        [self pressKey:c];
        usleep(KEYDELAY);
        [self releaseKey:c];
    }
    
    if (i != [text length])
    {
        // Abbreviate text by three dots
        for (i = 0; i < 3; i++)
        {
            [self pressKey:'.'];
            usleep(KEYDELAY);
            [self releaseKey:'.'];
            usleep(KEYDELAY);
        }
    }
    
    isStillTyping=false;
    
    fprintf(stderr,"\n");
}

- (void) _loadGame:(NSString *)fileExtension
{
    isGameLoading=true;
    
    if([fileExtension isEqualToString:@"d64"] ||
       [fileExtension isEqualToString:@"p00"] ||
       [fileExtension isEqualToString:@"prg"] ||
       [fileExtension isEqualToString:@"t64"])
    {
        if(c64->mountArchive(D64Archive::archiveFromArbitraryFile([_fileToLoad UTF8String])) &&
           c64->flushArchive(D64Archive::archiveFromArbitraryFile([_fileToLoad UTF8String]), 0)){
            
            [self typeText:@"load \"*\",8,1\n" withDelay:1000 ];
            
        }
        else if([fileExtension isEqualToString:@"tap"])
        {
            if(c64->insertTape(TAPContainer::containerFromTAPFile([_fileToLoad UTF8String])))
            {
                
                [self typeText:@"LOAD\n" withDelay:10000];
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{usleep(400000);c64->datasette.pressPlay();});
            }
        }
        
    }
    else if([fileExtension isEqualToString:@"crt"])
    {
        if(c64->attachCartridge(Cartridge::cartridgeFromFile([_fileToLoad UTF8String])))
        {
            isGameLoaded=true;
            _didRUN=true;
            c64->reset();
        }
    }
    isGameLoading=false;
    isGameLoaded=true;
}

- (void) checkForReady
{
    int pnt = (c64->mem.peek(0x00d1) | (c64->mem.peek(0x00d2) << 8));  //Get Current Cursor position
    int pntr = c64->mem.peek(0x00d3);     // Current column on the line
    int lnmx = c64->mem.peek(0x00d5) + 1;   // Get the line lenght
    int blnsw = c64->mem.peek(0x00cc);    // is the curson blinking?  0 is yes, 1 in no
    int addrStrt = pnt - lnmx;            //  set the start position in Ram to start looking at the previous line
    char *s = "READY.";                   //  We are looking for READY.
    bool charsFound = false;

    for (int i = 0; s[i] != '\0'; i++)
    {
        if (c64->mem.peek(addrStrt + i) == (s[i] % 64))
        {
            charsFound = true;
        }
        else
        {
            charsFound=false;
        }
    }
    
    if (charsFound)
    {
        isAtReadyPrompt=true;
        isC64Ready = true;
        NSLog(@"Screen address: %d,%d, %d, %d", pnt,pntr, blnsw, lnmx);
    }
}
@end
