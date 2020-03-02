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
#import "C64Proxy+Private.h"
#import "OEC64SystemResponderClient.h"
#import "VirtualC64-Swift.h"

#import <OpenGL/gl.h>
#import <Carbon/Carbon.h>
#import <OpenEmuBase/OERingBuffer.h>

#define SOUNDBUFFERSIZE 2048

@interface VC64GameCore () <OEC64SystemResponderClient>
{
    C64 *c64;
    C64Proxy *_proxy;
    KeyboardController *_kbd;
    BOOL                _isJoystickPortSwapped;
    NSString *_fileToLoad;
    float    *_soundBuffer;
    uint32_t *_videoBuffer;
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
        c64     = new C64();
        _proxy  = [[C64Proxy alloc] initWithC64:c64];
        _kbd    = [[KeyboardController alloc] initWithC64:_proxy];

        _soundBuffer = (float *)calloc(SOUNDBUFFERSIZE, sizeof(*_soundBuffer));

        isC64Ready      = false;
        isAtReadyPrompt = false;
        waitingForReady = false;
        isStillTyping   = false;
        isGameLoading   = false;
        isGameLoaded    = false;
    }

    return self;
}

- (void)dealloc
{
    free(_soundBuffer);
}

#pragma mark - Execution

- (BOOL)loadFileAtPath:(NSString *)path
{
    _fileToLoad = [path copy];

    // System
    // TODO: Determine region
    c64->vic.setModel(NTSC_6567);
    
    if(![self loadBIOSRoms])
        return NO;

    // Peripherals
    c64->setAlwaysWarp(false);
    // c64->setWarp(false);
    c64->setWarpLoad(false); // Leave disabled otherwise audio can get slightly out of sync
    c64->drive1.setSendSoundMessages(false);
    // c64->drive1.setBitAccuracy(true); // Disable to put drive in a faster, but less compatible read-only mode

    // Audio
    c64->sid.setReSID(true);
    c64->sid.setModel(MOS_6581); // MOS6581 or MOS8580
    c64->sid.setSamplingMethod(SID_SAMPLE_FAST);
    c64->sid.setAudioFilter(false);

    return YES;
}

- (void)setupEmulation
{
    // Power on sub components
    c64->sid.run();
    c64->cpu.clearErrorState();
    c64->drive1.cpu.clearErrorState();
    c64->drive2.cpu.clearErrorState();
    c64->restartTimer();
}

- (void)executeFrame
{
    // Run the game loop ourselves
    int samples = c64->sid.getSampleRate() / c64->vic.getFramesPerSecond();

    c64->executeOneFrame();
    
    // copy video buffer
    memcpy(_videoBuffer, c64->vic.screenBuffer(), self.bufferSize.width * self.bufferSize.height * sizeof(uint32_t));
    
    if(_didRUN)
    {
        c64->sid.readMonoSamples(_soundBuffer, samples);
        [[self audioBufferAtIndex:0] write:_soundBuffer maxLength:samples * sizeof(*_soundBuffer)];
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
                        [self typeText:@"run\n" withDelay:0];
                        _didRUN=true;
                    }
                }
            }
        }
    }
}

- (void)resetEmulation
{
    c64->cpu.reset();
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
    return c64->vic.getFramesPerSecond();
}

// Doesn't seem to work correctly, audio still goes out of sync
// Use setWarp instead of Always warp
-(void)fastForward:(BOOL)flag
{
   // flag ? c64->setWarp(true) : c64->setWarp(false);
    
    [super fastForward:flag];
}


#pragma mark - Video

- (const void*)getVideoBufferWithHint:(void *)hint {
    _videoBuffer = static_cast<uint32_t *>(hint);
    return hint;
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
    return GL_UNSIGNED_INT_8_8_8_8_REV;
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

- (NSUInteger)audioBitDepth
{
    return 32;
}

- (NSUInteger)channelCount
{
    return 1;
}

#pragma mark - Save States

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    c64->takeUserSnapshotSafe();
    auto nr = c64->numUserSnapshots() - 1;
    auto saveState = c64->userSnapshot(nr);
    block(saveState->writeToFile(fileName.fileSystemRepresentation),nil);
    c64->deleteUserSnapshot(nr);
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    Snapshot *saveState = new Snapshot;
    block(saveState->readFromFile(fileName.fileSystemRepresentation),nil);
    c64->loadFromSnapshotSafe(saveState);
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

- (oneway void)keyDown:(unsigned short)keyHIDCode characters:(NSString *)characters charactersIgnoringModifiers:(NSString *)charactersIgnoringModifiers flags:(NSEventModifierFlags)modifierFlags
{
    // Do not accept input before RUN
    if(!isC64Ready)
        return;
    
    [_kbd keyDownWithKeyCode:keyHIDCode characters:charactersIgnoringModifiers flags:modifierFlags];
}

- (oneway void)keyUp:(unsigned short)keyHIDCode characters:(NSString *)characters charactersIgnoringModifiers:(NSString *)charactersIgnoringModifiers flags:(NSEventModifierFlags)modifierFlags
{
    // Do not accept input before RUN
    if(!isC64Ready)
        return;
    
    [_kbd keyUpWithKeyCode:keyHIDCode characters:charactersIgnoringModifiers flags:modifierFlags];
}

- (oneway void)didPushC64Button:(OEC64Button)button forPlayer:(NSUInteger)player;
{
    ControlPort *port;
    switch (player) {
        case 1:port = _isJoystickPortSwapped ?  &c64->port1:  &c64->port2;
        case 2:port = _isJoystickPortSwapped ?  &c64->port2 :  &c64->port1;
        default: return;
    }
    
    if(button == OEC64JoystickUp)    { port->trigger(PULL_UP); }
    if(button == OEC64JoystickDown)  { port->trigger(PULL_DOWN); }
    if(button == OEC64JoystickLeft)  { port->trigger(PULL_LEFT); }
    if(button == OEC64JoystickRight) { port->trigger(PULL_RIGHT); }
    if(button == OEC64ButtonFire)    { port->trigger(PRESS_FIRE); }
    
}

- (oneway void)didReleaseC64Button:(OEC64Button)button forPlayer:(NSUInteger)player;
{
    ControlPort *port;
    
    switch (player) {
        case 1:port = _isJoystickPortSwapped ?  &c64->port1:  &c64->port2;
        case 2:port = _isJoystickPortSwapped ?  &c64->port2 :  &c64->port1;
        default: return;
    }
    
    switch (button) {
        case OEC64JoystickUp:
        case OEC64JoystickDown:
            port->trigger(RELEASE_Y);
            break;
            
        case OEC64JoystickLeft:
        case OEC64JoystickRight:
            port->trigger(RELEASE_X);
            break;
            
        case OEC64ButtonFire:
            port->trigger(RELEASE_FIRE);
            break;
            
        default:
            break;
    }
}

- (oneway void)swapJoysticks {
    // do port swap
       _isJoystickPortSwapped = !_isJoystickPortSwapped;
}

#pragma mark - Misc & Helpers

- (BOOL)loadBIOSRoms
{
    // Get The 4 BIOS ROMs
    
    // BASIC ROM
    NSString *basicROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"basic.901226-01.bin"];
    if (!ROMFile::isBasicRomFile(basicROM.UTF8String))
    {
        NSLog(@"VirtualC64: %@ is not a valid Basic ROM!", basicROM);
        return NO;
    }
    
    // "Kernal" ROM
    NSString *kernelROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"JiffyDOS_C64.bin"];
    if (!ROMFile::isKernalRomFile(kernelROM.UTF8String) || TAPFile::isTAPFile(_fileToLoad.UTF8String))
    {
       kernelROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"kernal.901227-03.bin"];
        if (!ROMFile::isKernalRomFile(kernelROM.UTF8String))
        {
            NSLog(@"VirtualC64: %@ is not a valid Kernal ROM!", kernelROM);
            return NO;
        }
    }
    
    // Char ROM
    NSString *charROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"characters.901225-01.bin"];
    if (!ROMFile::isCharRomFile(charROM.UTF8String))
    {
        NSLog(@"VirtualC64: %@ is not a valid Char ROM!", charROM);
        return NO;
    }
    
    // C1541 aka Floppy ROM
    NSString *C1541ROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"JiffyDOS_C1541.bin"];
    if (!ROMFile::isVC1541RomFile(C1541ROM.UTF8String))
    {
         C1541ROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"1541-II.355640-01.bin"];
           if (!ROMFile::isVC1541RomFile(C1541ROM.UTF8String))
           {
               NSLog(@"VirtualC64: %@ is not a valid C1541 ROM!", charROM);
               return NO;
           }
    }
    
    // Load Basic, Kernel, Char and C1541 Floppy ROMs
    c64->loadRom([basicROM UTF8String]);
    c64->loadRom([kernelROM UTF8String]);
    c64->loadRom([charROM UTF8String]);
    c64->loadRom([C1541ROM UTF8String]);
    
    return YES;
}

- (void)typeText:(NSString *)text
{
    [self typeText:text withDelay:0];
}

- (void)typeText:(NSString *)text withDelay:(int)delay
{
    while (isStillTyping)
        usleep(50);
    
    isStillTyping = YES;
    [_kbd typeWithString:text initialDelay:delay completion:^{
        self->isStillTyping = NO;
    }];
}

- (void) _loadGame:(NSString *)fileExtension
{
    isGameLoading = true;
   
    if (CRTFile::isCRTFile(_fileToLoad.UTF8String)) {
        //Cartridge Loading
           _didRUN = true;
          c64->expansionport.attachCartridgeAndReset( CRTFile::makeWithFile(_fileToLoad.UTF8String));

    }else if (TAPFile::isTAPFile(_fileToLoad.UTF8String)) {
        // Tape Loading
        c64->datasette.insertTape(TAPFile::makeWithFile(_fileToLoad.UTF8String));
       
        isStillTyping = YES;
         [_kbd typeWithString:@"LOAD\n" initialDelay:0 completion:^{
             self->isStillTyping = NO;
             c64->datasette.pressPlay();
         }];
    } else {
        //Disk Image/Archive Loading
        auto archive = AnyArchive::makeWithFile(_fileToLoad.UTF8String);
        if (archive != nullptr) {
            c64->drive1.prepareToInsert();
            c64->drive1.insertDisk(archive);
            [self typeText:@"load \"*\",8,1\n" withDelay:500];
        } else {
            [self typeText:@"This is an unknow image file.  C64 cannot load it." withDelay:500];
        }
    }
    
    isGameLoading   = false;
    isGameLoaded    = true;
}

- (void) checkForReady
{
    int pnt = (c64->mem.peek(0x00d1) | (c64->mem.peek(0x00d2) << 8));  //Get Current Cursor position
    int pntr = c64->mem.peek(0x00d3);     // Current column on the line
    int lnmx = c64->mem.peek(0x00d5) + 1; // Get the line lenght
    int blnsw = c64->mem.peek(0x00cc);    // is the curson blinking?  0 is yes, 1 in no
    int addrStrt = pnt - lnmx;            //  set the start position in Ram to start looking at the previous line
    char const *s = "READY.";             //  We are looking for READY.
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
        isAtReadyPrompt = true;
        isC64Ready      = true;
        NSLog(@"Screen address: %d,%d, %d, %d", pnt,pntr, blnsw, lnmx);
    }
}
@end
