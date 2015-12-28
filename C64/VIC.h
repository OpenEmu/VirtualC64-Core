/*
 * (C) 2006 Dirk W. Hoffmann. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef _VIC_INC
#define _VIC_INC

#include "VirtualComponent.h"
#include "VIC_globals.h"
#include "PixelEngine.h"

// Forward declarations
class C64Memory;
class PixelEngine; 


/*! @brief      Virtual Video Controller (VICII)
 *  @discussion VICII is the video controller chip of the Commodore 64.
 *              VICII occupied the memory mapped I/O space from address 0xD000 to 0xD02E. */
class VIC : public VirtualComponent {

    friend class PixelEngine;
   
private:
    
    // Reference to the attached pixel engine (PE). The PE encapsulates all drawing related
    // routines in a seperate class.
    PixelEngine pixelEngine;
    
	//! Reference to the connected CPU
	CPU *cpu;
	
	//! Reference to the connected virtual memory
	C64Memory *mem;
	
public:
    
    //! Dump current configuration into message queue
    void ping();


	// -----------------------------------------------------------------------------------------------
	//                                     Internal state
	// -----------------------------------------------------------------------------------------------

    //! @brief Main pixel engine pipe
    PixelEnginePipe p;

    //! @brief Color pipes
    BorderColorPipe bp;
    CanvasColorPipe cp;
    SpriteColorPipe sp; 
    
    //! Selected chip model (determines whether video mode is PAL or NTSC)
    VICChipModel chipModel;
    
    //! Indicates whether the currently drawn rasterline belongs to VBLANK area
    bool vblank;
    
	//! Internal VIC register, 10 bit video counter
	uint16_t registerVC;
	
	//! Internal VIC-II register, 10 bit video counter base
	uint16_t registerVCBASE; 
	
	//! Internal VIC-II register, 3 bit row counter
	uint8_t registerRC;
	
	//! Internal VIC-II register, 6 bit video matrix line index
	uint8_t registerVMLI; 

    //! Rasterline counter
    /*! The rasterline counter is is usually incremented in cycle 1. The only exception is the
     overflow condition which is handled in cycle 2 */
    uint32_t yCounter;
    
    //! Vertical frame flipflop set condition
    /*! Indicates whether the vertical frame ff needs to be set in current rasterline */
    bool verticalFrameFFsetCond;
    
    //! Vertical frame flipflop clear condition
    /*! Indicates whether the vertical frame ff needs to be cleared in current rasterline */
    bool verticalFrameFFclearCond;

    //! DRAM refresh counter
    /*! "In jeder Rasterzeile führt der VIC fünf Lesezugriffe zum Refresh des
         dynamischen RAM durch. Es wird ein 8-Bit Refreshzähler (REF) zur Erzeugung
         von 256 DRAM-Zeilenadressen benutzt." [C.B.] */
    uint8_t refreshCounter;
    
    //! Address bus
    /*! Whenever VIC performs a memory read, the generated memory address is stored here */
    uint16_t addrBus;

    //! Data bus
    /*! Whenever VIC performs a memory read, the result is stored here */
    uint8_t dataBus;
    
    //! Display mode in latest gAccess
    uint8_t gAccessDisplayMode;
    
    //! Foreground color fetched in latest gAccess
    uint8_t gAccessfgColor;

    //! Background color fetched in latest gAccess
    uint8_t gAccessbgColor;

	//! Indicates that we are curretly processing a DMA line (bad line)
	bool badLineCondition;
	
	//! Determines, if DMA lines (bad lines) can occurr within the current frame.
    /*! Bad lines can only occur, if the DEN bit was set during an arbitary cycle in rasterline 30
	    The DEN bit is located in register 0x11 (CONTROL REGISTER 1) */
    bool DENwasSetInRasterline30;

	//! Display State
	/*! The VIC is either in idle or display state */
	bool displayState;

	//! BA line
	/* Remember: Each CPU cycle is split into two phases
           First phase (LOW):   VIC gets access to the bus
           Second phase (HIGH): CPU gets access to the bus
       In rare cases, VIC needs access in the HIGH phase, too. To block the CPU, the BA line is pulled down.
       Note: The BA line can be pulled down by multiple sources (wired AND). */
    uint16_t BAlow;
	
    //! Remember at which cycle BA line has been pulled down
    uint64_t BAwentLowAtCycle;
    
    
    //! Increase x counter by 8
    inline void countX() { p.xCounter += 8; }
    
    //! Returns true if yCounter needs to be reset to 0 in this rasterline
    bool yCounterOverflow();

    //! cAccesses can only be performed is BA line is down for more than 2 cycles
    bool BApulledDownForAtLeastThreeCycles();
    
    /* "Der VIC benutzt zwei Flipflops, um den Rahmen um das Anzeigefenster
        herum zu erzeugen: Ein Haupt-Rahmenflipflop und ein vertikales
        Rahmenflipflop. [...]

        Die Flipflops werden nach den folgenden Regeln geschaltet:
     
        1. Erreicht die X-Koordinate den rechten Vergleichswert, wird das
           Haupt-Rahmenflipflop gesetzt.
        2. Erreicht die Y-Koordinate den unteren Vergleichswert in Zyklus 63, wird
           das vertikale Rahmenflipflop gesetzt.
        3. Erreicht die Y-Koordinate den oberern Vergleichswert in Zyklus 63 und
           ist das DEN-Bit in Register $d011 gesetzt, wird das vertikale
           Rahmenflipflop gelöscht.
        4. Erreicht die X-Koordinate den linken Vergleichswert und die Y-Koordinate
           den unteren, wird das vertikale Rahmenflipflop gesetzt.
        5. Erreicht die X-Koordinate den linken Vergleichswert und die Y-Koordinate
           den oberen und ist das DEN-Bit in Register $d011 gesetzt, wird das
           vertikale Rahmenflipflop gelöscht.
        6. Erreicht die X-Koordinate den linken Vergleichswert und ist das
           vertikale Rahmenflipflop gelöscht, wird das Haupt-Flipflop gelöscht." [C.B.]
     */

    //! Takes care of the vertical frame flipflop value.
    /*! Invoked in each VIC II cycle */
    void checkVerticalFrameFF();
    
    //! Check frame fliplops at left border
    void checkFrameFlipflopsLeft(uint16_t comparisonValue);

    //! Check frame fliplops at right border
    void checkFrameFlipflopsRight(uint16_t comparisonValue);

    //! Comparison values for frame flipflops
    inline uint16_t leftComparisonValue() { return isCSEL() ? 24 : 31; }
    inline uint16_t rightComparisonValue() { return isCSEL() ? 344 : 335; }
    inline uint16_t upperComparisonValue() { return isRSEL() ? 51 : 55; }
    inline uint16_t lowerComparisonValue() { return isRSEL() ? 251 : 247; }
    
	//! Clear main frame flipflop
    /*  "Das vertikale Rahmenflipflop dient zur Unterstützung bei der Darstellung
         des oberen/unteren Rahmens. Ist es gesetzt, kann das Haupt-Rahmenflipflop
         nicht gelöscht werden." [C.B.] */
    inline void clearMainFrameFF() { if (!p.verticalFrameFF && !verticalFrameFFsetCond) p.mainFrameFF = false; }
     
    
	// -----------------------------------------------------------------------------------------------
	//                              I/O memory handling and RAM access
	// -----------------------------------------------------------------------------------------------

public:
	
	//! I/O Memory
	/*! If a value is poked to the VIC address space, it is stored here. */
	uint8_t iomem[64]; 

private:

    //! Start address of the currently selected memory bank
    /*! There are four banks in total since the VIC chip can only "see" 16 KB of memory at one time
        Two bank select bits in the CIA I/O space determine which quarter of the memory we're actually seeing
     
        \verbatim
        +-------+------+-------+----------+-------------------------------------+
        | VALUE | BITS |  BANK | STARTING |  VIC-II CHIP RANGE                  |
        |  OF A |      |       | LOCATION |                                     |
        +-------+------+-------+----------+-------------------------------------+
        |   0   |  00  |   3   |   49152  | ($C000-$FFFF)                       |
        |   1   |  01  |   2   |   32768  | ($8000-$BFFF)                       |
        |   2   |  10  |   1   |   16384  | ($4000-$7FFF)                       |
        |   3   |  11  |   0   |       0  | ($0000-$3FFF) (DEFAULT VALUE)       |
        +-------+------+-------+----------+-------------------------------------+
        \endverbatim 
    */
    uint16_t bankAddr;

    //! General memory access via address and data bus
    uint8_t memAccess(uint16_t addr);

    //! Idle memory access at address 0x3fff
    uint8_t memIdleAccess();

    
// -----------------------------------------------------------------------------------------------
//                                  Character access (cAccess)
// -----------------------------------------------------------------------------------------------
    
    //! During a cAccess, VIC accesses the video matrix
    void cAccess();
    
    //! cAcess character storage
    /*! Every 8th rasterline, the VIC chips performs a DMA access and fills this array with 
        character information */
    uint8_t characterSpace[40];
    
    //! cAcess color storage
    /*! Every 8th rasterline, the VIC chips performs a DMA access and fills the array with t
        color information */
    uint8_t colorSpace[40];
    
    
    // -----------------------------------------------------------------------------------------------
    //                                  Graphics access (gAccess)
    // -----------------------------------------------------------------------------------------------

    //! During a 'g access', VIC reads graphics data (character or bitmap patterns)
    /*! The result of the gAccess is stored in variables prefixed with 'g_', i.e.,
     *  g_data, g_character, g_color, g_mode */
    void gAccess();
    

    // -----------------------------------------------------------------------------------------------
    //                             Sprite accesses (pAccess and sAccess)
    // -----------------------------------------------------------------------------------------------
    
    //! Sprite pointer access
    void pAccess(unsigned sprite);
    
    //! @brief  First sprite data access
    /*! @result true iff sprite data was fetched (a memory access has occurred) */
    bool sFirstAccess(unsigned sprite);

    //! @brief  Second sprite data access
    /*! @result Returns true iff sprite data was fetched (a memory access has occurred) */
    bool sSecondAccess(unsigned sprite);

    //! @brief  Third sprite data access
    /*! @result Returns true iff sprite data was fetched (a memory access has occurred) */
    bool sThirdAccess(unsigned sprite);

    //! @brief      Finalizes the sprite data access
    /*! @discussion This method is invoked one cycle after the second and third sprite DMA */
    void sFinalize(unsigned sprite);

    //! @brief Bit i is set to 1 iff sprite i performs its first DMA in the current cycle
    uint8_t isFirstDMAcycle;

    //! @brief Bit i is set to 1 iff sprite i performs its second and third DMA in the current cycle
    uint8_t isSecondDMAcycle;

    
    // -----------------------------------------------------------------------------------------------
    //                           Memory refresh accesses (rAccess)
    // -----------------------------------------------------------------------------------------------
    
    //! Performs a DRAM refresh
    inline void rAccess() { (void)memAccess(0x3F00 | refreshCounter--); }
    
    //! Performs a DRAM idle access
    inline void rIdleAccess() { (void)memIdleAccess(); }
    

	// -----------------------------------------------------------------------------------------------
	//                                         Sprites
	// -----------------------------------------------------------------------------------------------

	//! MC register
	/*! MOB data counter (6 bit counter). One register for each sprite */
	uint8_t mc[8];
	
	//! MCBASE register
	/*! MOB data counter (6 bit counter). One register for each sprite */
	uint8_t mcbase[8];
		
	//! Sprite pointer
	/*! Determines where the sprite data comes from */
	uint16_t spritePtr[8];

	//! Sprite on off
	/*! Determines if a sprite needs to be drawn in the current rasterline. Each bit represents a single sprite. */
	uint8_t spriteOnOff;
    
	//! Sprite DMA on off
	/*! Determines  if sprite dma access is enabled or disabled. Each bit represents a single sprite. */
	uint8_t spriteDmaOnOff;
    
	//! Expansion flipflop
	/*! Used to handle Y sprite stretching. One bit for each sprite */
	uint8_t expansionFF;

    //! Remembers which bits the CPU has cleared in the expansion Y register (D017)
    /*! This value is set in pokeIO and cycle 15 and read in cycle 16 */
    uint8_t cleared_bits_in_d017;
	
				
	// -----------------------------------------------------------------------------------------------
	//                                             Lightpen
	// -----------------------------------------------------------------------------------------------
	
	//! Lightpen triggered?
	/*! This variable ndicates whether a lightpen interrupt has occurred within the current frame.
	    The variable is needed, because a lightpen interrupt can only occur once in a frame. It is set to false
	    at the beginning of each frame. */
	bool lightpenIRQhasOccured;
	
	
	// -----------------------------------------------------------------------------------------------
	//                                             Debugging
	// -----------------------------------------------------------------------------------------------
	
	//! Determines whether sprites are drawn or not
	/*! During normal emulation, the value is always true. For debugging purposes, the value can be set to false.
	 In this case, sprites are no longer drawn.
	 */
	bool drawSprites;
	
	//! Enable sprite-sprite collision
	/*! If set to true, the virtual VIC chips checks for sprite-sprite collision as the original C64 does.
	    For debugging purposes and cheating, collision detection can be disabled by setting the variabel to false.
	    Collision detection can be enabled or disabled for each sprite seperately. Each bit is dedicated to a single sprite. 
	*/
	uint8_t spriteSpriteCollisionEnabled;
	
	//! Enable sprite-background collision
	/*! If set to true, the virtual VIC chips checks for sprite-background collision as the original C64 does.
	    For debugging purposes and cheating, collision detection can be disabled by setting the variabel to false.
	    Collision detection can be enabled or disabled for each sprite seperately. Each bit is dedicated to a single sprite. 
	*/
	uint8_t spriteBackgroundCollisionEnabled;
	
	//! Determines whether IRQ lines will be made visible.
	/*! Each rasterline that will potentially trigger a raster IRQ is highlighted. This feature is useful for
	    debugging purposes as it visualizes how the screen is divided into multiple parts. */
	bool markIRQLines;
	
	//! Determines whether DMA lines will be made visible.
	/*! Each rasterline in which the vic will read additional data from the memory and stun the CPU is made visible.
	    Note that partial DMA lines may not appear. */	
	bool markDMALines;

	
	// -----------------------------------------------------------------------------------------------
	//                                             Methods
	// -----------------------------------------------------------------------------------------------

public:
	
	//! Constructor
	VIC();
	
	//! Destructor
	~VIC();
	
	//! Get screen buffer that is currently stable
    inline void *screenBuffer() { return pixelEngine.screenBuffer(); }

	//! Reset the VIC chip to its initial state
	void reset();
		
	//! Dump internal state to console
	void dumpState();	
	
    
	// -----------------------------------------------------------------------------------------------
	//                                         Configuring
	// -----------------------------------------------------------------------------------------------
	
public:
	
    //! Returns true iff virtual vic is running in PAL mode
    inline bool isPAL() { return chipModel == MOS6569_PAL; }

    //! Returns true iff virtual vic is running in NTSC mode
    inline bool isNTSC() { return chipModel == MOS6567_NTSC; }

	//! Get chip model
    inline VICChipModel getChipModel() { return chipModel; }

    //! Set chip model
    void setChipModel(VICChipModel model);
	
    //! Get color
    inline uint32_t getColor(unsigned nr) { assert(nr < 16); return pixelEngine.colors[nr]; }

    //! Get color
    inline void setColor(unsigned nr, int rgba) { assert(nr < 16); pixelEngine.colors[nr] = rgba; }

    // Returns the number of frames per second
    inline unsigned getFramesPerSecond() { return isPAL() ? (unsigned)PAL_REFRESH_RATE : (unsigned)NTSC_REFRESH_RATE; }
    
    //! Returns the number of rasterlines per frame
    inline int getRasterlinesPerFrame() { return isPAL() ? PAL_HEIGHT : NTSC_HEIGHT; }
    
    //! Returns the number of CPU cycles performed per rasterline
    inline int getCyclesPerRasterline() { return isPAL() ? PAL_CYCLES_PER_RASTERLINE : NTSC_CYCLES_PER_RASTERLINE; }
    
    //! Returns the number of CPU cycles performed per frame
    inline int getCyclesPerFrame() {
        return isPAL() ? (PAL_HEIGHT * PAL_CYCLES_PER_RASTERLINE) : (NTSC_HEIGHT * NTSC_CYCLES_PER_RASTERLINE); }
    
    //! Returns the time interval between two frames in nanoseconds
    inline uint64_t getFrameDelay() { return (uint64_t)(1000000000.0 / (isPAL() ? PAL_REFRESH_RATE : NTSC_REFRESH_RATE)); }

    
	// -----------------------------------------------------------------------------------------------
	//                                       Getter and setter
	// -----------------------------------------------------------------------------------------------

public:
	
	//! Returns true if the specified address lies in the VIC I/O range
	static inline bool isVicAddr(uint16_t addr)	{ return (VIC_START_ADDR <= addr && addr <= VIC_END_ADDR); }
		
	//! Get current scanline
	inline uint16_t getScanline() { return yCounter; }
			
	//! Set rasterline
	inline void setScanline(uint16_t line) { yCounter = line; }

	//! Get memory bank start address
	uint16_t getMemoryBankAddr();
	
	//! Set memory bank start address
	void setMemoryBankAddr(uint16_t addr);
			
	//! Get screen memory address
    /*! This function is not needed internally and only invoked by the GUI debug panel */
	uint16_t getScreenMemoryAddr();
	
	//! Set screen memory address
    /*! This function is not needed internally and only invoked by the GUI debug panel */
	void setScreenMemoryAddr(uint16_t addr);
		
	//! Get character memory start address
    /*! This function is not needed internally and only invoked by the GUI debug panel */
	uint16_t getCharacterMemoryAddr();
	
	//! Set character memory start address
    /*! This function is not needed internally and only invoked by the GUI debug panel */
	void setCharacterMemoryAddr(uint16_t addr);
		
	//! Peek fallthrough
	/*! The fallthrough mechanism works as follows:
	 If the memory is asked to peek a value, it first checks whether the RAM, ROM, or I/O space is visible.
	 If an address in the I/O space is specified, the memory is unable to handle the request itself and
	 passes it to the corresponding I/O chip.
	 */
	uint8_t peek(uint16_t addr);
    
	//! Poke fallthrough
	/*! The fallthrough mechanism works as follows:
	 If the memory is asked to poke a value, it first checks whether the RAM, ROM, or I/O space is visible.
	 If an address in the I/O space is specified, the memory is unable to handle the request itself and
	 passes it to the corresponding I/O chip. 
	 */	
	void poke(uint16_t addr, uint8_t value);
	
    //! Return last value on VIC data bus
    inline uint8_t getDataBus() { return dataBus; }
    
    
	// -----------------------------------------------------------------------------------------------
	//                                         Properties
	// -----------------------------------------------------------------------------------------------
	
public:
		
    //! Current value of DEN bit (Display Enabled)
    inline bool DENbit() { return GET_BIT(p.registerCTRL1, 4); }

    //! DEN bit in previous cycle (Display Enabled)
    // inline bool DENbitInPreviousCycle() { return GET_BIT(pixelEngine.pipe.registerCTRL1, 4); }

    //! Current value of BMM bit (Bit Map Mode)
    inline bool BMMbit() { return GET_BIT(p.registerCTRL1, 5); }

    //! BMM bit in previous cycle (Bit Map Mode)
    inline bool BMMbitInPreviousCycle() { return GET_BIT(pixelEngine.pipe.registerCTRL1, 5); }
    
    //! Current value of ECM bit (Extended Character Mode)
    inline bool ECMbit() { return GET_BIT(p.registerCTRL1, 6); }

    //! ECM bit in previous cycle (Extended Character Mode)
    inline bool ECMbitInPreviousCycle() { return GET_BIT(pixelEngine.pipe.registerCTRL1, 6); }

    //! Returns masked CB13 bit (controls memory access)
    inline uint8_t CB13() { return iomem[0x18] & 0x08; }

    //! Returns masked CB13/CB12/CB11 bits (controls memory access)
    inline uint8_t CB13CB12CB11() { return iomem[0x18] & 0x0E; }

    //! Returns masked VM13/VM12/VM11/VM10 bits (controls memory access)
    inline uint8_t VM13VM12VM11VM10() { return iomem[0x18] & 0xF0; }

	//! Returns the state of the CSEL bit
    inline bool isCSEL() { return GET_BIT(p.registerCTRL2, 3); }
	
	//! Returns the state of the RSEL bit
    inline bool isRSEL() { return GET_BIT(p.registerCTRL1, 3); }
    
	//! Returns the currently set display mode
	/*! The display mode is determined by bits 5 and 6 of control register 1 and bit 4 of control register 2. */
	inline DisplayMode getDisplayMode() 
	{ return (DisplayMode)((p.registerCTRL1 & 0x60) | (p.registerCTRL2 & 0x10)); }
	
	//! Set display mode
	inline void setDisplayMode(DisplayMode m) {
        p.registerCTRL1 = (p.registerCTRL1 & ~0x60) | (m & 0x60);
        p.registerCTRL2 = (p.registerCTRL2 & ~0x10) | (m & 0x10); }
	
	//! Get the current screen geometry
	ScreenGeometry getScreenGeometry(void);
	
	//! Set the screen geometry 
	void setScreenGeometry(ScreenGeometry mode);
	
	//! Returns the number of rows to be drawn (24 or 25)
	inline int numberOfRows() { return GET_BIT(p.registerCTRL1, 3) ? 25 : 24; }
	
	//! Set the number of rows to be drawn (24 or 25)
	inline void setNumberOfRows(int rs) { assert(rs == 24 || rs == 25); WRITE_BIT(p.registerCTRL1, 3, rs == 25); }
	
	//! Return the number of columns to be drawn (38 or 40)
	inline int numberOfColumns() { return GET_BIT(p.registerCTRL2, 3) ? 40 : 38; }

	//! Set the number of columns to be drawn (38 or 40)
    inline void setNumberOfColumns(int cs) { assert(cs == 38 || cs == 40); WRITE_BIT(p.registerCTRL2, 3, cs == 40); }
		
	//! Returns the vertical raster scroll offset (0 to 7)
	/*! The vertical raster offset is usally used by games for smoothly scrolling the screen */
	inline uint8_t getVerticalRasterScroll() { return p.registerCTRL1 & 0x07; }
	
	//! Set vertical raster scroll offset (0 to 7)
	inline void setVerticalRasterScroll(uint8_t offset) { p.registerCTRL1 = (p.registerCTRL1 & 0xF8) | (offset & 0x07); }
	
	//! Returns the horizontal raster scroll offset (0 to 7)
	/*! The vertical raster offset is usally used by games for smoothly scrolling the screen */
	inline uint8_t getHorizontalRasterScroll() { return p.registerCTRL2 & 0x07; }
	
	//! Set horizontan raster scroll offset (0 to 7)
	inline void setHorizontalRasterScroll(uint8_t offset) { p.registerCTRL2 = (p.registerCTRL2 & 0xF8) | (offset & 0x07); }
			
	//! Return border color
    inline uint8_t getBorderColor() { return bp.borderColor; }
	
	//! Returns background color
    inline uint8_t getBackgroundColor() { return cp.backgroundColor[0]; }
	
	//! Returns extra background color (for multicolor modes)
    inline uint8_t getExtraBackgroundColor(int offset) { return cp.backgroundColor[offset]; }
	
	
	// -----------------------------------------------------------------------------------------------
	//                                DMA lines, BA signal and IRQs
	// -----------------------------------------------------------------------------------------------

private:
    
    //! Set to true in cycle 1, cycle 63 and cycle 65 iff yCounter equals contents of D012
    /*! Variable is needed to determine if a rasterline should be issued in cycle 1 or 2 */
    bool yCounterEqualsIrqRasterline;
    
    /*! Update bad line condition
        "Ein Bad-Line-Zustand liegt in einem beliebigen Taktzyklus vor, wenn an der
         negativen Flanke von ¯0 zu Beginn des 
         [1] Zyklus RASTER >= $30 und RASTER <= $f7 und
         [2] die unteren drei Bits von RASTER mit YSCROLL übereinstimmen 
         [3] und in einem beliebigen Zyklus von Rasterzeile $30 das DEN-Bit gesetzt war." [C.B.] */
    inline void updateBadLineCondition() {
        badLineCondition =
            yCounter >= 0x30 && yCounter <= 0xf7 /* [1] */ &&
            (yCounter & 0x07) == getVerticalRasterScroll() /* [2] */ &&
            DENwasSetInRasterline30 /* [3] */;
    }
    
    //! Update display state
    /*! Invoked at the end of each VIC cycle */
    inline void updateDisplayState() { if (badLineCondition) displayState = true; }
    
    //! Set BA line
    void setBAlow(uint8_t value);
	
	//! Trigger a VIC interrupt
	/*! VIC interrupts can be triggered from multiple sources. Each one is associated with a specific bit */
	void triggerIRQ(uint8_t source);
		
public: 
	
	//! @brief      Returns next interrupt rasterline
    /*! @discussion In line 0, the interrupt is triggered in cycle 2. In all other lines, it is triggered in cycle 1 */
	inline uint16_t rasterInterruptLine() { return ((p.registerCTRL1 & 0x80) << 1) | iomem[0x12]; }

	//! Set interrupt rasterline 
	inline void setRasterInterruptLine(uint16_t line) {
        iomem[0x12] = line & 0xFF; if (line > 0xFF) p.registerCTRL1 |= 0x80; else p.registerCTRL1 &= 0x7F; }
	
	//! Returns true, iff rasterline interrupts are enabled
    inline bool rasterInterruptEnabled() { return GET_BIT(iomem[0x1A], 1); }

	//! Enable or disable rasterline interrupts
    inline void setRasterInterruptEnable(bool b) { WRITE_BIT(iomem[0x1A], 1, b); }
	
	//! Enable or disable rasterline interrupts
    inline void toggleRasterInterruptFlag() { TOGGLE_BIT(iomem[0x1A], 1); }
	
	//! Simulate a light pen event
	/*! Although we do not support hardware lightpens, we need to take care of it because lightpen interrupts 
	 can be triggered by software. It is used by some games to determine the current X position within 
	 the current rasterline. */
	void triggerLightPenInterrupt();

	
	// -----------------------------------------------------------------------------------------------
	//                                              Sprites
	// -----------------------------------------------------------------------------------------------

private:

    //! Turn off sprite dma if conditions are met
    /*! In cycle 16, the mcbase pointer is advanced three bytes for all dma enabled sprites. Advancing 
        three bytes means that mcbase will then point to the next sprite line. When mcbase reached 63,
        all 21 sprite lines have been drawn and sprite dma is switched off.
        The whole operation is skipped when the y expansion flipflop is 0. This never happens for
        normal sprites (there is no skipping then), but happens every other cycle for vertically expanded 
        sprites. Thus, mcbase advances for those sprites at half speed which actually causes the expansion. */
    void turnSpriteDmaOff();

    //! Turn on sprite dma accesses if drawing conditions are met
    /*! Sprite dma is turned on either in cycle 55 or cycle 56. Dma is turned on iff it's currently turned 
        off and the sprite y positon equals the lower 8 bits of yCounter. */
    void turnSpriteDmaOn();

    //! Toggle expansion flipflop for vertically stretched sprites
    /*! In cycle 56, register D017 is read and the flipflop gets inverted for all sprites with vertical
        stretching enabled. When the flipflop goes down, advanceMCBase() will have no effect in the
        next rasterline. This causes each sprite line to be drawn twice. */
    void toggleExpansionFlipflop();
    
	//! Get sprite depth
	/*! The value is written to the z buffer to resolve overlapping pixels */
	inline uint8_t spriteDepth(uint8_t nr) {
        return spriteIsDrawnInBackground(nr) ? (SPRITE_LAYER_BG_DEPTH | nr) : (SPRITE_LAYER_FG_DEPTH | nr); }
	
public: 
	
	//! Returns color code of multicolor sprites (extra color 1)
    inline uint8_t spriteExtraColor1() { return sp.spriteExtraColor1; }
	
	//! Returns color code of multicolor sprites (extra color 2)
	inline uint8_t spriteExtraColor2() { return sp.spriteExtraColor2; }
	
	//! Get sprite color 
	inline uint8_t spriteColor(uint8_t nr) { assert(nr < 8); return sp.spriteColor[nr]; }

	//! Set sprite color
	inline void setSpriteColor(uint8_t nr, uint8_t color) { assert(nr < 8); sp.spriteColor[nr] = color; }
		
	//! Get X coordinate of sprite 
    inline uint16_t getSpriteX(uint8_t nr) { assert(nr < 8); return p.spriteX[nr]; }

	//! Set X coordinate of sprite
	inline void setSpriteX(uint8_t nr, uint16_t x) {
        if (x < 512) {
            p.spriteX[nr] = x;
            iomem[2*nr] = x & 0xFF;
            if (x & 0x100) SET_BIT(iomem[0x10],nr); else CLR_BIT(iomem[0x10],nr);
        }
    }
    
	//! Get Y coordinate of sprite
	inline uint8_t getSpriteY(uint8_t nr) { assert(nr < 8); return iomem[1+2*nr]; }

	//! Set Y coordinate of sprite
    inline void setSpriteY(uint8_t nr, uint8_t y) { iomem[1+2*nr] = y; }
	
    //! Compare Y coordinate of all sprites with 8 bit value
    inline uint8_t compareSpriteY(uint8_t y) { return
        ((iomem[1] == y) << 0) | ((iomem[3] == y) << 1) | ((iomem[5] == y) << 2) | ((iomem[7] == y) << 3) |
        ((iomem[9] == y) << 4) | ((iomem[11] == y) << 5) | ((iomem[13] == y) << 6) | ((iomem[15] == y) << 7);
    }
    
	//! Returns true, if sprite is enabled (drawn on the screen)
    inline bool spriteIsEnabled(uint8_t nr) { return GET_BIT(iomem[0x15], nr); }

	//! Enable or disable sprite
    inline void setSpriteEnabled(uint8_t nr, bool b) { WRITE_BIT(iomem[0x15], nr, b); }

	//! Enable or disable sprite
    inline void toggleSpriteEnabled(uint8_t nr) { TOGGLE_BIT(iomem[0x15], nr); }
	
	//! Returns true, iff an interrupt will be triggered when a sprite/background collision occurs
    inline bool spriteBackgroundInterruptEnabled() { return GET_BIT(iomem[0x1A], 1); }

	//! Returns true, iff an interrupt will be triggered when a sprite/sprite collision occurs
    inline bool spriteSpriteInterruptEnabled() { return GET_BIT(iomem[0x1A], 2); }

	//! Returns true, iff a rasterline interrupt has occurred
    inline bool rasterInterruptOccurred() { return GET_BIT(iomem[0x19], 0); }

	//! Returns true, iff a sprite/background interrupt has occurred
    inline bool spriteBackgroundInterruptOccurred() { return GET_BIT(iomem[0x19], 1); }

	//! Returns true, iff a sprite/sprite interrupt has occurred
    inline bool spriteSpriteInterruptOccurred() { return GET_BIT(iomem[0x19], 1); }

	//! Returns true, iff sprites are drawn behind the scenary
	inline bool spriteIsDrawnInBackground(unsigned nr) { assert(nr < 8); return GET_BIT(iomem[0x1B], nr); }

	//! Determine whether a sprite is drawn before or behind the scenary
    inline void setSpriteInBackground(unsigned nr, bool b) { assert(nr < 8); WRITE_BIT(iomem[0x1B], nr, b); }

	//! Determine whether a sprite is drawn before or behind the scenary
	inline void spriteToggleBackgroundPriorityFlag(unsigned nr) { assert(nr < 8); TOGGLE_BIT(iomem[0x1B], nr); }
	
	//! Returns true, iff sprite is a multicolor sprite
    inline bool spriteIsMulticolor(unsigned nr) { assert(nr < 8); return GET_BIT(iomem[0x1C], nr); }

	//! Set single color or multi color mode for sprite
    inline void setSpriteMulticolor(unsigned nr, bool b) { assert(nr < 8); WRITE_BIT(iomem[0x1C], nr, b); }

	//! Switch between single color or multi color mode
	inline void toggleMulticolorFlag(unsigned nr) { assert(nr < 8); TOGGLE_BIT(iomem[0x1C], nr); }
		
	//! Returns true, if the sprite is vertically stretched
    inline bool spriteHeightIsDoubled(unsigned nr) { assert(nr < 8); return GET_BIT(iomem[0x17], nr); }

	//! Stretch or shrink sprite vertically
    inline void setSpriteStretchY(unsigned nr, bool b) { assert(nr < 8); WRITE_BIT(iomem[0x17], nr, b); }

	//! Stretch or shrink sprite vertically
	inline void spriteToggleStretchYFlag(unsigned nr) { assert(nr < 8); TOGGLE_BIT(iomem[0x17], nr); }

	//! Returns true, if the sprite is horizontally stretched 
	inline bool spriteWidthIsDoubled(unsigned nr) { assert(nr < 8); return GET_BIT(p.spriteXexpand, nr); }

	//! Stretch or shrink sprite horizontally
    inline void setSpriteStretchX(unsigned nr, bool b) { assert(nr < 8); WRITE_BIT(p.spriteXexpand, nr, b); }

	//! Stretch or shrink sprite horizontally
	inline void spriteToggleStretchXFlag(unsigned nr) { assert(nr < 8); TOGGLE_BIT(p.spriteXexpand, nr); }

	//! Returns true, iff sprite collides with another sprite
    inline bool spriteCollidesWithSprite(unsigned nr) { assert(nr < 8); return GET_BIT(iomem[0x1E], nr); }

	//! Returns true, iff sprite collides with background
	inline bool spriteCollidesWithBackground(unsigned nr) { assert(nr < 8); return GET_BIT(iomem[0x1F], nr); }

	
	// -----------------------------------------------------------------------------------------------
	//                                    Execution functions
	// -----------------------------------------------------------------------------------------------

public:
	
	//! Prepare for new frame
	/*! This function is called prior to cycle 1 of rasterline 0 */
	void beginFrame();
	
	//! Prepare for new rasterline
	/*! This function is called prior to cycle 1 at the beginning of each rasterline */
	void beginRasterline(uint16_t rasterline);

	//! Finish rasterline
	/*! This function is called after the last cycle of each rasterline. */
	void endRasterline();
	
	//! Finish frame
	/*! This function is called after the last cycle of the last rasterline */
	void endFrame();
	
    //! Push portions of the VIC state into the pixel engine
    /*! Pushs everything that needs to be recorded one cycle prior to drawing */
    inline void preparePixelEngine() { pixelEngine.pipe = p; };
    
	//! VIC execution functions
	void cycle1();  void cycle2();  void cycle3();  void cycle4();
    void cycle5();  void cycle6();  void cycle7();  void cycle8();
    void cycle9();  void cycle10(); void cycle11(); void cycle12();
    void cycle13(); void cycle14(); void cycle15(); void cycle16();
    void cycle17(); void cycle18();

    void cycle19to54();

    void cycle55(); void cycle56(); void cycle57(); void cycle58();
    void cycle59(); void cycle60(); void cycle61(); void cycle62();
    void cycle63(); void cycle64(); void cycle65();
	
	//! Debug entry point for each rasterline cycle

private:
    void debug_cycle(unsigned cycle);

	// -----------------------------------------------------------------------------------------------
	//                                              Debugging
	// -----------------------------------------------------------------------------------------------

	
public: 
	
	//! Return true iff IRQ lines are colorized
	bool showIrqLines() { return markIRQLines; }

	//! Show or hide IRQ lines
	void setShowIrqLines(bool show) { markIRQLines = show; }

	//! Return true iff DMA lines are colorized
	bool showDmaLines() { return markDMALines; }
	
	//! Show or hide DMA lines
	void setShowDmaLines(bool show) { markDMALines = show; }

	//! Return true iff sprites are hidden
	bool hideSprites() { return !drawSprites; }

	//! Hide or show sprites
	void setHideSprites(bool hide) { drawSprites = !hide; }
	
	//! Return true iff sprite-sprite collision detection is enabled
	bool getSpriteSpriteCollisionFlag() { return spriteSpriteCollisionEnabled; }

	//! Enable or disable sprite-sprite collision detection
    void setSpriteSpriteCollisionFlag(bool b) { spriteSpriteCollisionEnabled = b; };

	//! Enable or disable sprite-sprite collision detection
    void toggleSpriteSpriteCollisionFlag() { spriteSpriteCollisionEnabled = !spriteSpriteCollisionEnabled; }
	
	//! Return true iff sprite-background collision detection is enabled
	bool getSpriteBackgroundCollisionFlag() { return spriteBackgroundCollisionEnabled; }

	//! Enable or disable sprite-background collision detection
    void setSpriteBackgroundCollisionFlag(bool b) { spriteBackgroundCollisionEnabled = b; }

	//! Enable or disable sprite-background collision detection
    void toggleSpriteBackgroundCollisionFlag() { spriteBackgroundCollisionEnabled = !spriteBackgroundCollisionEnabled; }
};

#endif

