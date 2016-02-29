/*!
 * @header      PixelEngine.h
 * @author      Dirk W. Hoffmann, www.dirkwhoffmann.de
 * @copyright   2015 - 2016 Dirk W. Hoffmann
 */
/*              This program is free software; you can redistribute it and/or modify
 *              it under the terms of the GNU General Public License as published by
 *              the Free Software Foundation; either version 2 of the License, or
 *              (at your option) any later version.
 *
 *              This program is distributed in the hope that it will be useful,
 *              but WITHOUT ANY WARRANTY; without even the implied warranty of
 *              MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *              GNU General Public License for more details.
 *
 *              You should have received a copy of the GNU General Public License
 *              along with this program; if not, write to the Free Software
 *              Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef _PIXELENGINGE_INC
#define _PIXELENGINGE_INC

#include "VirtualComponent.h"
#include "VIC_globals.h"

// Forward declarations
class VIC;

// Depth of different drawing layers
#define BORDER_LAYER_DEPTH 0x10         /* in front of everything */
#define SPRITE_LAYER_FG_DEPTH 0x20      /* behind border */
#define FOREGROUND_LAYER_DEPTH 0x30     /* behind sprite 1 layer  */
#define SPRITE_LAYER_BG_DEPTH 0x40      /* behind foreground */
#define BACKGROUD_LAYER_DEPTH 0x50      /* behind sprite 2 layer */
#define BEIND_BACKGROUND_DEPTH 0x60     /* behind background */

//! Display mode
enum DisplayMode {
    STANDARD_TEXT             = 0x00,
    MULTICOLOR_TEXT           = 0x10,
    STANDARD_BITMAP           = 0x20,
    MULTICOLOR_BITMAP         = 0x30,
    EXTENDED_BACKGROUND_COLOR = 0x40,
    INVALID_TEXT              = 0x50,
    INVALID_STANDARD_BITMAP   = 0x60,
    INVALID_MULTICOLOR_BITMAP = 0x70
};

//! @class   PixelEngine
/*! @details This component is part of the virtual VICII chip and encapulates all functionality 
 *           that is related to the synthesis of pixels. Its main entry point are prepareForCycle() 
 *           and draw() which are called in every VIC cycle inside the viewable range.
 */
class PixelEngine : public VirtualComponent {
    
    friend class VIC;
    
public:

    //! @brief    Reference to the connected video interface controller (VIC)
    VIC *vic;
    
    //! @brief    Constructor
    PixelEngine();
    
    //! @brief    Destructor
    ~PixelEngine();
    
    //! @brief    Restores the initial state
    void reset();

    //! @brief    Initializes both screenBuffers
    /*! @details  This function is needed for debugging, only. It write some recognizable pattern 
     *            into both buffers 
     */
    void resetScreenBuffers();

    
    // -----------------------------------------------------------------------------------------------
    //                                     Constant definitions
    // -----------------------------------------------------------------------------------------------
    
    //! @brief    VIC colors
    enum Color {
        BLACK   = 0x00,
        WHITE   = 0x01,
        RED     = 0x02,
        CYAN    = 0x03,
        PURPLE  = 0x04,
        GREEN   = 0x05,
        BLUE    = 0x06,
        YELLOW  = 0x07,
        LTBROWN = 0x08,
        BROWN   = 0x09,
        LTRED   = 0x0A,
        GREY1   = 0x0B,
        GREY2   = 0x0C,
        LTGREEN = 0x0D,
        LTBLUE  = 0x0E,
        GREY3   = 0x0F
    };
    
    
    // -----------------------------------------------------------------------------------------------
    //                                    Pixel buffers and colors
    // -----------------------------------------------------------------------------------------------
    
private:
    
    //! @brief    All sixteen C64 colors in RGBA format
     uint32_t colors[16] = {
        LO_LO_HI_HI(0x10, 0x10, 0x10, 0xFF),
        LO_LO_HI_HI(0xff, 0xff, 0xff, 0xFF),
        LO_LO_HI_HI(0xe0, 0x40, 0x40, 0xFF),
        LO_LO_HI_HI(0x60, 0xff, 0xff, 0xFF),
        LO_LO_HI_HI(0xe0, 0x60, 0xe0, 0xFF),
        LO_LO_HI_HI(0x40, 0xe0, 0x40, 0xFF),
        LO_LO_HI_HI(0x40, 0x40, 0xe0, 0xFF),
        LO_LO_HI_HI(0xff, 0xff, 0x40, 0xFF),
        LO_LO_HI_HI(0xe0, 0xa0, 0x40, 0xFF),
        LO_LO_HI_HI(0x9c, 0x74, 0x48, 0xFF),
        LO_LO_HI_HI(0xff, 0xa0, 0xa0, 0xFF),
        LO_LO_HI_HI(0x54, 0x54, 0x54, 0xFF),
        LO_LO_HI_HI(0x88, 0x88, 0x88, 0xFF),
        LO_LO_HI_HI(0xa0, 0xff, 0xa0, 0xFF),
        LO_LO_HI_HI(0xa0, 0xa0, 0xff, 0xFF),
        LO_LO_HI_HI(0xc0, 0xc0, 0xc0, 0xFF)
    };
    
    /*! @brief    First screen buffer
     *  @details  The VIC chip writes it output into this buffer. The contents of the array is 
     *            later copied into to texture RAM of your graphic card by the drawRect method 
     *            in the GPU related code. 
     */
    int screenBuffer1[PAL_RASTERLINES][NTSC_PIXELS];
    
    /*! @brief    Second screen buffer
     *  @details  The VIC chip uses double buffering. Once a frame is drawn, the VIC chip writes 
     *            the next frame to the second buffer. 
     */
    int screenBuffer2[PAL_RASTERLINES][NTSC_PIXELS];
    
    /*! @brief    Target screen buffer for all rendering methods
     *  @details  The variable points either to screenBuffer1 or screenBuffer2 
     */
    int *currentScreenBuffer;
    
    /*! @brief    Pointer to the beginning of the current rasterline
     *  @details  This pointer is used by all rendering methods to write pixels. It always points 
     *            to the beginning of a rasterline, either in screenBuffer1 or screenBuffer2. 
     *            It is reset at the beginning of each frame and incremented at the beginning of 
     *            each rasterline. 
     */
    int *pixelBuffer;
        
    /*! @brief    Z buffer
     *  @details  Virtual VICII uses depth buffering to determine pixel priority. In the various
     *            render routines, a pixel is only written to the screen buffer, if it is closer 
     *            to the view point. The depth of the closest pixel is kept in the z buffer. 
     *            The lower the value of the z buffer, the closer it is to the viewer. 
     */
    int zBuffer[8];
    
    /*! @brief    Indicates the source of a drawn pixel
     *  @details  Whenever a foreground pixel or sprite pixel is drawn, a distinct bit in the 
     *            pixelSource array is set. The information is utilized to detect sprite-sprite 
     *            and sprite-background collisions. 
     */
    int pixelSource[8];
    
    /*! @brief    Offset into pixelBuffer
     *  @details  Variable points to the first pixel of the currently drawn 8 pixel chunk 
     */
    short bufferoffset;
    
public:
    
    /*! @brief    Get screen buffer that is currently stable
     *  @details  This method is called by the GPU code at the beginning of each frame. 
     */
    inline void *screenBuffer() {
        return (currentScreenBuffer == screenBuffer1[0]) ? screenBuffer2[0] : screenBuffer1[0]; }

    
    // -----------------------------------------------------------------------------------------------
    //                                  Rastercycle information
    // -----------------------------------------------------------------------------------------------

private:
    
    /*! @brief    Indicates wether we are in a visible display column or not
     *  @details  The visible columns comprise canvas columns and border columns. The first visible 
     *            column is drawn in cycle 14 (first left border column) and the last in cycle ?? 
     *            (fourth right border column).
     */
    bool visibleColumn;
    
    
    // -----------------------------------------------------------------------------------------------
    //                                    Execution functions
    // -----------------------------------------------------------------------------------------------

public:
    
    //! @brief    Prepares for a new frame
    void beginFrame();
    
    //! @brief    Prepares for a new rasterline
    void beginRasterline();
    
    //! @brief    Finishes up a rasterline
    void endRasterline();
    
    //! @brief    Finishes up a frame
    void endFrame();

    
    // -----------------------------------------------------------------------------------------------
    //                                   VIC state latching
    // -----------------------------------------------------------------------------------------------

    //! @brief    Register pipe
    PixelEnginePipe pipe;

    //! @brief    Border color pipe
    BorderColorPipe bpipe;
    
    //! @brief    Canvas color pipe
    CanvasColorPipe cpipe;

    //! @brief    Sprite color pipe
    SpriteColorPipe spipe;

    /*! @brief    Latched VIC state
     *  @details  To draw pixels right, it is important to gather the necessary information at the right time.
     *            Some VIC and memory registers need to be looked up one cycle before drawing, others need
     *            to be looked up at the same cycle or even in the middle of drawing an 8 pixel chunk. To make
     *            this process transparent, all gatheres information is stored in this structure. 
     */

    // TODO:
    // Rename dc to spriteOnOffPipe
    // Rename spriteOnOffPipe to spriteOnOff1
    // Rename spriteOnOff to spriteOnOff2
    struct {
        uint8_t spriteOnOffPipe;
        uint8_t spriteOnOff;

    } dc;
    
    /*! @brief    Current display mode
     *  @details  The display mode is determined by three bits (one in register 0xD016 and two in register 0xD011).
     *            These bits don't show up simultanously. They are latched in method drawCanvas() after
     *            after certain pixels have been draw. 
     */
    uint8_t displayMode;

    /*! @brief    Latches the sprite enable bits
     *  @details  This method is called in drawSprites()
     */
    void updateSpriteOnOff();
    
    
    // -----------------------------------------------------------------------------------------------
    //               Shift register logic for canvas pixels (handled in drawCanvasPixel)
    // -----------------------------------------------------------------------------------------------
    
    //! @brief    Main shift register
    /*! @details  An eight bit shift register used to synthesize the canvas pixels.
     */
    
    struct {
        
        //! @brief    Shift register data
        uint8_t data;

        /*! @brief    Indicates whether the shift register can load data
         *  @details  If true, the register is loaded when the current x scroll offset matches the
         *            current pixel number. 
         */
        bool canLoad; 
         
        /*! @brief    Multi-color synchronization flipflop
         *  @details  Whenever the shift register is loaded, the synchronization flipflop is also set.
         *            It is toggled with each pixel and used to synchronize the synthesis of 
         *            multi-color pixels. */
        bool mc_flop;
        
        /*! @brief    Latched character info
         *  @details  Whenever the shift register is loaded, the current character value (which was 
         *            once read during a gAccess) is latched. This value is used until the shift 
         *            register loads again. 
         */
        uint8_t latchedCharacter;
        
        /*! @brief    Latched color info
         *  @details  Whenever the shift register is loaded, the current color value (which was 
         *            once read during a gAccess) is latched. This value is used until the shift 
         *            register loads again. 
         */
        uint8_t latchedColor;
        
        /*! @brief    Color bits
         *  @details  Every second pixel (as synchronized with mc_flop), the  multi-color bits are
         *            remembered. 
         */
        uint8_t colorbits;

    } sr;
    
    
    // -----------------------------------------------------------------------------------------------
    //              Shift register logic for sprite pixels (handled in drawSpritePixel)
    // -----------------------------------------------------------------------------------------------
    
    /*! @brief    Sprite shift registers
     *  @details  The VIC chip has a 24 bit (3 byte) shift register for each sprite. It stores the sprite
     *            for one rasterline. If a sprite is a display candidate in the current rasterline, its
     *            shift register is activated when the raster X coordinate matches the sprites X coordinate.
     *            The comparison is done in method drawSprite().
     *            Once a shift register is activated, it remains activated until the beginning of the next
     *            rasterline. However, after an activated shift register has dumped out its 24 pixels, it
     *            can't draw anything else than transparent pixels (which is the same as not to draw anything).
     *            An exception is during DMA cycles. When a shift register is activated during such a cycle,
     *            it freezes a short period of time in which it repeats the previous drawn pixel.
     */
    struct {
        
        //! @brief    Shift register data (24 bit)
        uint32_t data;
        
        //! @brief    The shift register data is read in three chunks
        uint8_t chunk1, chunk2, chunk3;
        
        /*! @brief    Remaining bits to be pumped out
         *  @details  At the beginning of each rasterline, this value is initialized with -1 and set to
         *            26 when the horizontal trigger condition is met (sprite X trigger coord reaches xCounter).
         *            When all bits are drawn, this value reaches 0. 
         */
        int remaining_bits;

        /*! @brief    Multi-color synchronization flipflop
         *  @details  Whenever the shift register is loaded, the synchronization flipflop is also set.
         *            It is toggled with each pixel and used to synchronize the synthesis of multi-color pixels. 
         */
        bool mc_flop;

        //! @brief    x expansion synchronization flipflop
        bool exp_flop;

        /*! @brief    Color bits of the currently processed pixel
         *  @details  In single-color mode, these bits are updats every cycle
         *            In multi-color mode, these bits are updats every second cycle (synchronized with mc_flop) 
         */
        uint8_t col_bits;

    } sprite_sr[8];

    /*! @brief    Loads the sprite shift register.
     *  @details  The shift register is loaded with the three data bytes fetched in the previous sAccesses.
     */
    inline void loadShiftRegister(unsigned nr) {
        sprite_sr[nr].data = (sprite_sr[nr].chunk1 << 16) | (sprite_sr[nr].chunk2 << 8) | sprite_sr[nr].chunk3;
    }
    
    // -----------------------------------------------------------------------------------------------
    //                          High level drawing (canvas, sprites, border)
    // -----------------------------------------------------------------------------------------------

public:
  
    /*! @brief    Synthesize 8 pixels according the the current drawing context.
     *  @details  This is the main entry point and is invoked in each VIC drawing cycle, except cycle 17 and
     *            cycle 55 which are handles seperately for speedup purposes.
     *            To get the correct output, preparePixelEngineForCycle() must be called one cycle before. 
     */
    void draw();

    //! @brief    Special draw routine for cycle 17
    void draw17();

    //! @brief    Special draw routine for cycle 55
    void draw55();

    /*! @brief    Draw routine for cycles outside the visible screen region.
     *  @details  The sprite sequencer needs to be run outside the visible area, although no
     *            pixels will be drawn (drawing is omitted by having visibleColumn set to false 
     */
    void drawOutsideBorder();
    
private:
    
    /*! @brief    Draws 8 border pixels
     *  @details  Invoked inside draw() 
     */
    void drawBorder();
    
    /*! @brief    Draws 8 border pixels
     *  @details  Invoked inside draw17() 
     */
    void drawBorder17();
    
    /*! @brief    Draws 8 border pixels
     *  @details  Invoked inside draw55()
     */
    void drawBorder55();

    /*! @brief    Draws 8 canvas pixels
     *  @details  Invoked inside draw()
     */
    void drawCanvas();
    
    /*! @brief    Draws a single canvas pixel
     *  @param    pixelnr is the pixel number and must be in the range 0 to 7 
     */
    void drawCanvasPixel(uint8_t pixelnr);
    
    /*! @brief    Draws 8 sprite pixels
     *  @details  Invoked inside draw() 
     */
    void drawSprites();

    /*! @brief    Draws a single sprite pixel for all sprites
     *  @param    pixelnr  Pixel number (0 to 7)
     *  @param    freeze   If the i-th bit is set to 1, the i-th shift register will freeze temporarily
     *  @param    halt     If the i-th bit is set to 1, the i-th shift register will be deactivated
     *  @param    load     If the i-th bit is set to 1, the i-th shift register will grab new data bits 
     */
    void drawSpritePixel(unsigned pixelnr, uint8_t freeze, uint8_t halt, uint8_t load);

    /*! @brief    Draws a single sprite pixel for a single sprite
     *  @param    spritenr Sprite number (0 to 7)
     *  @param    pixelnr  Pixel number (0 to 7)
     *  @param    freeze   If set to true, the sprites shift register will freeze temporarily
     *  @param    halt     If set to true, the sprites shift shift register will be deactivated
     *  @param    load     If set to true, the sprites shift shift register will grab new data bits 
     */
    void drawSpritePixel(unsigned spritenr, unsigned pixelnr, bool freeze, bool halt, bool load);

    /*! @brief    Draws all sprites into the pixelbuffer
     *  @details  A sprite is only drawn if it's enabled and if sprite drawing is not switched off for debugging 
     */
    void drawAllSprites();
    
    /*! @brief    Draw single sprite into pixel buffer
     *  @details  Helper function for drawSprites 
     */
    void drawSprite(uint8_t nr);
    
    
    // -----------------------------------------------------------------------------------------------
    //                         Mid level drawing (semantic pixel rendering)
    // -----------------------------------------------------------------------------------------------

private:
    
    /*! @brief    This is where loadColors() stores all retrieved colors
     *  @details  [0] : color for '0' pixels in single color mode or '00' pixels in multicolor mode
     *            [1] : color for '1' pixels in single color mode or '01' pixels in multicolor mode
     *            [2] : color for '10' pixels in multicolor mode
     *            [3] : color for '11' pixels in multicolor mode 
     */
    int col_rgba[4];
    
    //! @brief    loadColors() also determines if we are in single-color or multi-color mode
    bool multicol;

public:
    
    //! @brief    Determines pixel colors accordig to the provided display mode
    void loadColors(DisplayMode mode, uint8_t characterSpace, uint8_t colorSpace);
    
    /*! @brief    Draws single canvas pixel in single-color mode
     *  @details  1s are drawn with setForegroundPixel, 0s are drawn with setBackgroundPixel.
     *            Uses the drawing colors that are setup by loadColors(). 
     */
    void setSingleColorPixel(unsigned pixelnr, uint8_t bit);
    
    /*! @brief    Draws single canvas pixel in multi-color mode
     *  @details  The left of the two color bits determines whether setForegroundPixel or setBackgroundPixel is used.
     *            Uses the drawing colors that are setup by loadColors(). 
     */
    void setMultiColorPixel(unsigned pixelnr, uint8_t two_bits);
    
    /*! @brief    Draws single sprite pixel in single-color mode
     *  @details  Uses the drawing colors that are setup by updateSpriteColors 
     */
    void setSingleColorSpritePixel(unsigned spritenr, unsigned pixelnr, uint8_t bit);
    
    /*! @brief    Draws single sprite pixel in multi-color mode
     *  @details  Uses the drawing colors that are setup by updateSpriteColors 
     */
    void setMultiColorSpritePixel(unsigned spritenr, unsigned pixelnr, uint8_t two_bits);

    /*! @brief    Draws a single sprite pixel
     *  @details  This function is invoked by setSingleColorPixel() and setMultiColorPixel().
     *            It takes care of collison and invokes setSpritePixel(4) to actually render the pixel. 
     */
    void setSpritePixel(unsigned pixelnr, int color, int nr);

    
    // -----------------------------------------------------------------------------------------------
    //                        Low level drawing (pixel buffer access)
    // -----------------------------------------------------------------------------------------------
    
public:

    //! @brief    Draw a single frame pixel
    void setFramePixel(unsigned pixelnr, int rgba);
    
    //! @brief    Draw a single foreground pixel
    void setForegroundPixel(unsigned pixelnr, int rgba);
    
    //! @brief    Draw a single background pixel
    void setBackgroundPixel(unsigned pixelnr, int rgba);

    //! @brief    Draw eight background pixels in a row
    inline void setEightBackgroundPixels(int rgba) {
        for (unsigned i = 0; i < 8; i++) setBackgroundPixel(i, rgba); }

    //! @brief    Draw a single sprite pixel
    void setSpritePixel(unsigned pixelnr, int rgba, int depth, int source);

    /*! @brief    Extend border to the left and right to look nice.
     *  @details  This functions replicates the color of the leftmost and rightmost pixel 
     */
    void expandBorders();

    /*! @brief    Draw a horizontal colored line into the screen buffer
     *  @details  This method is utilized for debugging purposes, only.
     */
    void markLine(uint8_t color, unsigned start = 0, unsigned end = NTSC_PIXELS);
    
};

#endif