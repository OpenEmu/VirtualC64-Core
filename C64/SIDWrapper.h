/*
 * (C) 2011 Dirk W. Hoffmann, All rights reserved.
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

#ifndef _SIDWRAPPER_INC
#define _SIDWRAPPER_INC

#include "VirtualComponent.h"
#include "OldSID.h"
#include "ReSID.h"

class SIDWrapper : public VirtualComponent {

    
public:	
	//! Start address of the SID I/O space.
	static const uint16_t SID_START_ADDR = 0xD400;
    
	//! End address of the SID I/O space.
	static const uint16_t SID_END_ADDR = 0xD7FF;

private:

    //! Old SID implementation
    OldSID *oldsid;

public:
    //! Implementation based on the ReSID library
    ReSID *resid;
   
private:
    //! SID selector
    bool useReSID;
    
    //! Remembers latest written value
    uint8_t latchedDataBus;
    
public:
    //! Returns true if the \a addr is located in the I/O range of the SID chip.
	static inline bool isSidAddr(uint16_t addr) 
	{ return (SID_START_ADDR <= addr && addr <= SID_END_ADDR); }
	
	//! Constructor.
	SIDWrapper();
	
	//! Destructor.
	~SIDWrapper();
			
	//! Dump internal state to console
	void dumpState();
	
    
    // -----------------------------------------------------------------------------------------------
	//                                         Configuring
	// -----------------------------------------------------------------------------------------------

    //! Configure the SID chip for being used in PAL machines
    void setPAL();
    
    //! Configure the SID chip for being used in NTSC machines
    void setNTSC();
    
    //! Returns true, iff ReSID libray shall be used.
    inline bool getReSID() { return useReSID; }
    
    //! Enable or disable ReSID library.
    void setReSID(bool enable);
    
    //! Get chip model
    inline chip_model getChipModel() { return resid->getChipModel(); }
    
    //! Set chip model (ReSID only)
    void setChipModel(chip_model value);
    
    //! Returns true iff audio filters are enabled.
    // inline bool getAudioFilter() { return resid->getAudioFilter(); }
    inline bool getAudioFilter() { return resid->getExternalAudioFilter(); }
    
    //! Enable or disable filters of SID.
    void setAudioFilter(bool enable);
    
    //! Get sampling method
    inline sampling_method getSamplingMethod() { return resid->getSamplingMethod(); }
    
    //! Set sampling method (ReSID only)
    void setSamplingMethod(sampling_method value);

    //! Return samplerate.
	inline uint32_t getSampleRate() { return resid->getSampleRate(); }
    
	//! Sets samplerate of SID and it's 3 voices.
	void setSampleRate(uint32_t sr);
    
    //! Get clock frequency
    inline uint32_t getClockFrequency();
    
	//! Set clock frequency
	void setClockFrequency(uint32_t frequency);	

    /*! @brief Sets the current volume
     */
    void setVolume(int32_t v) { resid->setVolume(v); }

    /*! @brief Sets the target volume
     */
    void setTargetVolume(int32_t volume) { resid->setTargetVolume(volume); }
    
    /*! @brief   Triggers volume ramp up phase
     *  @details Configures volume and targetVolume to simulate a smooth audio fade in
     */
    void rampUp() { resid->rampUp(); }
    void rampUpFromZero() { resid->rampUpFromZero(); }

    /*! @brief   Triggers volume ramp down phase
     *  @details Configures volume and targetVolume to simulate a quick audio fade out
     */
    void rampDown() { resid->rampDown(); }

    /*! @brief Clears ringbuffer
     */
    void clearRingbuffer() { resid->clearRingbuffer(); }


    // -----------------------------------------------------------------------------------------------
	//                                           Execution
	// -----------------------------------------------------------------------------------------------

private:
    
    //! Current clock cycle since power up
    uint64_t cycles;

public:
    
    /*!
     @abstract   Executes SID until a certain cycle is reached
     @param      cycle The target cycle
     */
    void executeUntil(uint64_t targetCycle);

    /*!
     @abstract   Executes SID for a certain number of cycles
     @param      cycles Number of cycles to execute
     */
	void execute(uint64_t numCycles);

    //! Notifies the SID chip that the emulator has started
    void run();
	
	//! Notifies the SID chip that the emulator has started
	void halt();

    
	// -----------------------------------------------------------------------------------------------
	//                                       Getter and setter
	// -----------------------------------------------------------------------------------------------
    
	//! Special peek function for the I/O memory range.
	uint8_t peek(uint16_t addr);
	
	//! Special poke function for the I/O memory range.
	void poke(uint16_t addr, uint8_t value);
	
    //! Get next sample from \a ringBuffer.
	float readData();
};

#endif
