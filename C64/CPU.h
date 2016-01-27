/*!
 * @header      CPU.h
 * @author      Dirk W. Hoffmann, www.dirkwhoffmann.de
 * @copyright   2006 - 2016 Dirk W. Hoffmann
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

#ifndef _CPU_INC
#define _CPU_INC

#include "Memory.h"

/*! @class  The virtual 6510 processor
 */
class CPU : public VirtualComponent {

public:
    //! @brief    Processor models
    enum ChipModel {
        MOS6510 = 0,
        MOS6502 = 1
    };

	//! @brief    Addressing modes
	enum AddressingMode { 
		ADDR_IMPLIED,
		ADDR_ACCUMULATOR,
		ADDR_IMMEDIATE,
		ADDR_ZERO_PAGE,
		ADDR_ZERO_PAGE_X,
		ADDR_ZERO_PAGE_Y,
		ADDR_ABSOLUTE,
		ADDR_ABSOLUTE_X,
		ADDR_ABSOLUTE_Y,
		ADDR_INDIRECT_X,
		ADDR_INDIRECT_Y,
		ADDR_RELATIVE,
		ADDR_DIRECT,
		ADDR_INDIRECT
	};
	
	/*! @brief    Error states of the virtual CPU
	 *  @details  CPU_OK indicates normal operation. When a (soft or hard) breakpoint is reached, 
     *            the CPU enters the CPU_BREAKPOINT_REACHED state. CPU_ILLEGAL_INSTRUCTION is 
     *            entered when an opcode is not understood by the CPU. Once the CPU enters a 
     *            different state than CPU_OK, the execution thread is terminated.
     */
	enum ErrorState {
		OK = 0,
		SOFT_BREAKPOINT_REACHED,
		HARD_BREAKPOINT_REACHED,
		ILLEGAL_INSTRUCTION
	};

	/*! @brief    Breakpoint type
	 *  @details  Each memory call is marked with a breakpoint tag. Originally, each cell is 
     *            tagged with NO_BREAKPOINT which has no effect. CPU execution will stop if the 
     *            memory cell is tagged with one of the following breakpoint types:
     *
     *            HARD_BREAKPOINT: execution is halted
     *            SOFT_BREAKPOINT: execution is halted and the tag is deleted
     */
	enum Breakpoint {
		NO_BREAKPOINT   = 0x00,
		HARD_BREAKPOINT = 0x01,
		SOFT_BREAKPOINT = 0x02
	};

	//! @brief    Clock frequency of the original C64 (NTSC version) in Hz
	static const uint32_t CLOCK_FREQUENCY_NTSC = 1022727;
	
	//! @brief    Clock frequency of the original C64 (PAL version) in Hz
	static const uint32_t CLOCK_FREQUENCY_PAL = 985249;
	
	//! @brief    Bit position of the Negative flag
	static const uint8_t N_FLAG = 0x80;
    
	//! @brief    Bit position of the Overflow flag
	static const uint8_t V_FLAG = 0x40;
    
	//! @brief    Bit position of the Break flag
	static const uint8_t B_FLAG = 0x10;
    
	//! @brief    Bit position of the Decimal flag
	static const uint8_t D_FLAG = 0x08;
    
	//! @brief    Bit position of the Interrupt flag
	static const uint8_t I_FLAG = 0x04;
    
	//! @brief    Bit position of the Zero flag
	static const uint8_t Z_FLAG = 0x02;
    
	//! @brief    Bit position of the Carry flag
	static const uint8_t C_FLAG = 0x01;
	
public:

	//! @brief    Reference to the connected virtual memory
	Memory *mem;

    /*! @brief    Selected chip model
     *  @abstract Right now, this atrribute is only used to distinguish the C64 CPU (MOS6510) from the
     *            VC1541 CPU (MOS6502). Hardware differences between the two processors are not emulated.
     */
    ChipModel chipModel;

private:
    
	// @brief    Accumulator
	uint8_t A;
    
	// @brief    X register
	uint8_t X;
    
	// @brief    Y register
	uint8_t Y;
    
	//! @brief    Program counter
	uint16_t PC;
    
	//! @brief    Memory location of the currently executed command
	uint16_t PC_at_cycle_0;
    
	// @brief    Stack pointer
	uint8_t SP;
    
	/*! @brief    Negative flag
	 *  @details  The negative flag is set when the most significant bit (sign bit) equals 1. 
     */
	uint8_t  N;
    
	/*! @brief    Overflow flag
	 *  @details  The overflow flag is set iff an arithmetic operation causes a \a signed overflow. 
     */
	uint8_t  V;
    
	/*! @brief    Break flag
	 *  @details  Is set to signal external interrupt. 
     */
	uint8_t  B;
    
	/*! @brief    Decimal flag
	 *  @details  If set, the CPU operates in BCD mode. (BCD mode is not supported yet). 
     */
	uint8_t  D;
    
	/*! @brief    Interrupt flag
	 *  @details  If set, all interrupts are blocked. (No interrupt request will be answered). 
     */
	uint8_t  I;
    
	/*! @brief    Zero flag
	 *  @details  The zero flag is set iff the result of an arithmetic operation is zero. 
     */
	uint8_t  Z;
    
	/*! @brief    Carry flag
	 *  @details  The carry flag is set iff an arithmetic operation causes an \a unsigned overflow. 
     */
	uint8_t  C;
	
	//! @brief    Opcode of the currently executed command
	uint8_t opcode;
    
	//! @brief    Internal address register (low byte)
	uint8_t addr_lo;
    
	//! @brief    Internal address register (high byte)
	uint8_t addr_hi;
    
	//! @brief    Pointer for indirect addressing modes
	uint8_t ptr;
    
	//! @brief    Temporary storage for program counter (low byte)
	uint8_t pc_lo;
    
	//! @brief    Temporary storage for program counter (high byte)
	uint8_t pc_hi;
    
	/*! @brief    Address overflow indicater
	 *  @details  Used to indicate whether the page boundary has been crossed 
     */
	bool overflow;
    
	//! @brief    Internal data register
	uint8_t data;
			
	//! @brief    Processor port register
	uint8_t port;
    
	//! @brief    Processor port data direction register
	uint8_t port_direction;

    //! @brief    Experimental
	uint8_t external_port_bits;
	
	/*! @brief    RDY line (ready line)
	 *  @details  If this line is LOW, the CPU freezes on the next read access.
     *            RDY is pulled down by VIC to perform longer lasting read operations.
     */
	bool rdyLine;
	
	/*! @brief    IRQ line (maskable interrupts)
	 *  @details  The CPU checks the IRQ line before the next instruction is executed.
     *            If the Interrupt flag is cleared and at least one bit is set, the CPU performs 
     *            an interrupt. The IRQ line of the real CPU is driven by multiple sources 
     *            (CIA, VIC). Each source is represented by a separate bit.
     * @see       CPU::I CPU::I_FLAG
     */
	uint8_t irqLine;
	
	/*! @brief    NMI line (non maskable interrupts)
     *  @details  The CPU checks the IRQ line before the next instruction is executed.
     *            If at least one bit is set, the CPU performs an interrupt, regardless of the 
     *            value of the I flag. The IRQ line of the real CPU is driven by multiple sources 
     *            (CIA, VIC). Each source is represented by a separate bit.
     */
	uint8_t nmiLine; 
	
	/*! @brief    Indicates the occurance of an interrupt triggering edge on the NMI line
	 *  @details  The variable is set to 1, when the value of variable nmiLine is changed from 0 to 
     *            another value. The variable is used to determine when an NMI interrupt needs 
     *            to be triggered. 
     */
	bool nmiEdge;
	
    /*! @brief    Indicates if the CPU has to check for pending interrupts in its fetch phase
     *  @details  This variable has beed introduced for speedup. At all times, it is equivalent
     *            to "(irqLine || nmiEdge)".
     */
    bool interruptsPending;
    
	/*! @brief    Indicates when the next IRQ can occurr. 
     *  @details  This variable is set when a negative edge occurs on the irq line and stores the
     *            next cycle in which an IRQ can occur. The value is needed to determine the exact 
     *            time to trigger the interrupt.
     */
	uint64_t nextPossibleIrqCycle;
	
    /*! @brief    Indicates when the next NMI can occurr.
     *  @details  This variable is set when a negative edge occurs on the nmi line and stores the
     *            next cycle in which an NMI can occur. The value is needed to determine the exact 
     *            time to trigger the interrupt.
     */
	uint64_t nextPossibleNmiCycle;
		
	//! @brief    Current error state
	ErrorState errorState;
    
	/*! @brief    Next function to be executed
	 *  @details  Each function performs the actions of a single cycle 
     */
	void (CPU::*next)(void);
	 
	//! @brief    Callback function array pointing to the execution function of each instruction
	void (CPU::*actionFunc[256])(void);
	
	//! @brief    Breakpoint tag for each memory cell
	uint8_t breakpoint[65536];
	
	/*! @brief    Records all subroutine calls
	 *  @details  Whenever a JSR instruction is executed, the address of the instruction is recorded 
     *            in the callstack.
     */
	uint16_t callStack[256];
		
	//! @brief    Location of the next free cell of the callstack.
	uint8_t callStackPointer;

	//! @brief    Value of the I flag before it got changed with the SEI command.
	uint8_t oldI;
			
#include "Instructions.h"
		
public:

	//! @brief    Constructor
	CPU();
	
	//! @brief    Destructor
	~CPU();

	//! @brief    Restores the initial state.
	void reset();

    //! @brief    Returns the size of the internal state.
    uint32_t stateSize();

	//! @brief    Reads the internal state from a buffer.
	void loadFromBuffer(uint8_t **buffer);
	
	//! @brief    Writes the internal state into a buffer.
	void saveToBuffer(uint8_t **buffer);	
	
	//! @brief    Prints debugging information.
	void dumpState();	

    //! @brief    Returns true iff this object is the C64 CPU (for debugging, only).
    bool isC64CPU() { return strcmp(getDescription(), "CPU") == 0; /* VC1541 CPU is calles "1541CPU" */ }

    
    //
    //! @functiongroup Managing the processor port
    //

	//! @brief    Returns the value of processor port.
	inline uint8_t getPort() { return port; }
    
	//! @brief    Sets the value of the processor port register.
	void setPort(uint8_t value);
    
	//! @brief    Returns the value of processor port register.
	inline uint8_t getPortDirection() { return port_direction; }
    
	//! @brief    Experimental.
	inline uint8_t getExternalPortBits() { return external_port_bits; }
    
	//! @brief    Sets the value of the processor port data direction register.
	void setPortDirection(uint8_t value);
    
	//! @brief    Returns the physical value of the port lines.
	uint8_t getPortLines() { return (port | ~port_direction); }
	
    
    //
    //! @functiongroup Handling registers and flags
    //

	//! @brief    Returns the contents of the accumulator.
	inline uint8_t getA() { return A; };
    
	//! @brief    Returns current value of the X register.
	inline uint8_t getX() { return X; };
    
	//! @brief    Returns current value of the Y register.
	inline uint8_t getY() { return Y; };
    
	//! @brief    Returns current value of the program counter.
	inline uint16_t getPC() { return PC; };
    
	//! @brief    Returns "freezed" program counter.
	inline uint16_t getPC_at_cycle_0() { return PC_at_cycle_0; };
    
	//! @brief    Returns current value of the program counter.
	inline uint8_t getSP() { return SP; };
	
	//! @brief    Returns current value of the memory cell addressed by the program counter.
	inline uint8_t peekPC() { return mem->peek(PC); }

	//! @brief    Returns 1, if Negative flag is set, 0 otherwise.
	inline uint8_t getN() { return (N ? N_FLAG : 0); }
    
	//! @brief    Returns 1, if Overflow flag is set, 0 otherwise.
	inline uint8_t getV() { return (V ? V_FLAG : 0); }
    
	//! @brief    Returns 1, if Break flag is set, 0 otherwise.
	inline uint8_t getB() { return (B ? B_FLAG : 0); }
    
	//! @brief    Returns 1, if Decimal flag is set, 0 otherwise.
	inline uint8_t getD() { return (D ? D_FLAG : 0); }
    
	//! @brief    Returns 1, if Interrupt flag is set, 0 otherwise.
	inline uint8_t getI() { return (I ? I_FLAG : 0); }
    
	//! @brief    Returns 1, if Zero flag is set, 0 otherwise.
	inline uint8_t getZ() { return (Z ? Z_FLAG : 0); }
    
	//! @brief    Returns 1, if Carry flag is set, 0 otherwise.
	inline uint8_t getC() { return (C ? C_FLAG : 0); }
    
	/*! @brief    Returns the contents of the status register
	 *  @details  Each bit in the status register corresponds to the value of a single flag, 
     *            except bit 5 which is always set. 
     */
	inline uint8_t getP() { return getN() | getV() | 32 | getB() | getD() | getI() | getZ() | getC(); }
    
	/*! @brief    Returns the status register without the B flag
	 *  @details  The bit position of the B flag is always 0. This function is needed for proper 
     *            interrupt handling. When an IRQ or NMI is triggered internally, the status 
     *            register is pushed on the stack with the B-flag cleared. 
     */
	inline uint8_t getPWithClearedB() { return getN() | getV() | 32 | getD() | getI() | getZ() | getC(); }
	
    //! @brief    Returns current opcode.
    inline uint8_t getOpcode() { return opcode; }
    
	//! @brief    Writes value to the accumulator register. Flags remain untouched.
	inline void setA(uint8_t a) { A = a; }
    
	//! @brief    Writes value to the the X register. Flags remain untouched.
	inline void setX(uint8_t x) { X = x; }
    
	//! @brief    Writes value to the the Y register. Flags remain untouched.
	inline void setY(uint8_t y) { Y = y; }
    
	//! @brief    Writes value to the the program counter.
	inline void setPC(uint16_t pc) { PC = pc; }
    
	//! @brief    Writes value to the freezend program counter.
	inline void setPC_at_cycle_0(uint16_t pc) { PC_at_cycle_0 = PC = pc; next = &CPU::fetch;}
    
	//! @brief    Changes low byte of the program counter only.
	inline void setPCL(uint8_t lo) { PC = (PC & 0xff00) | lo; }
    
	//! @brief    Changes high byte of the program counter only.
	inline void setPCH(uint8_t hi) { PC = (PC & 0x00ff) | ((uint16_t)hi << 8); }
    
	/*! @brief    Increments the program counter by the specified amount.
	 *  @details  If no argument is provided, the program counter is incremented by one. 
     */
	inline void incPC(uint8_t offset = 1) { PC += offset; }
    
	//! @brief    Increments low byte of program counter (hi byte remains unchanged).
	inline void incPCL(uint8_t offset = 1) { setPCL(LO_BYTE(PC) + offset); }
    
	//! @brief    Increments high byte of program counter (lo byte remains unchanged).
	inline void incPCH(uint8_t offset = 1) { setPCH(HI_BYTE(PC) + offset); }
	
	//! @brief    Writes value to the stack pointer.
	inline void setSP(uint8_t sp) { SP = sp; }
	
	//! @brief    0: Negative-flag is cleared, any other value: flag is set.
	inline void setN(uint8_t n) { N = n; }
    
	//! @brief    0: Overflow-flag is cleared, any other value: flag is set.
	inline void setV(uint8_t v) { V = v; }
    
	//! @brief    0: Break-flag is cleared, any other value: flag is set.
	inline void setB(uint8_t b) { B = b; }
    
	//! @brief    0: Decimal-flag is cleared, any other value: flag is set.
	inline void setD(uint8_t d) { D = d; }
    
	//! @brief    0: Interrupt-flag is cleared, any other value: flag is set.
	inline void setI(uint8_t i) { I = i; }
    
	//! @brief    0: Zero-flag is cleared, any other value: flag is set.
	inline void setZ(uint8_t z) { Z = z; }
    
	//! @brief    0: Carry-flag is cleared, any other value: flag is set.
	inline void setC(uint8_t c) { C = c; }
    
	//! @brief    Write value to the status register. The value of bit 5 is ignored.
	inline void setP(uint8_t p) 
		{ setN(p & N_FLAG); setV(p & V_FLAG); setB(p & B_FLAG); setD(p & D_FLAG); setI(p & I_FLAG); setZ(p & Z_FLAG); setC(p & C_FLAG); }
	inline void setPWithoutB(uint8_t p) 
		{ setN(p & N_FLAG); setV(p & V_FLAG); setD(p & D_FLAG); setI(p & I_FLAG); setZ(p & Z_FLAG); setC(p & C_FLAG); }
			
	//! @brief    Loads the accumulator. The Z- and N-flag may change.
	inline void loadA(uint8_t a) { A = a; N = a & 128; Z = (a == 0); }
    
	//! @brief    Loads the X register. The Z- and N-flag may change.
	inline void loadX(uint8_t x) { X = x; N = x & 128; Z = (x == 0); }
    
	//! @brief    Loads the Y register. The Z- and N-flag may change.
	inline void loadY(uint8_t y) { Y = y; N = y & 128; Z = (y == 0); }
    
	//! @brief    Loads the stack register. The Z- and N-flag may change.
	inline void loadSP(uint8_t s) { SP = s; N = s & 128; Z = (s == 0); }
    
	//! @brief    Loads a value into memory. The Z- and N-flag may change.
	inline void loadM(uint16_t addr, uint8_t s) { mem->poke(addr, s); N = s & 128; Z = (s == 0); }

    
    //
    //! @functiongroup Handling interrupts
    //
    
    /*! @brief    Returns true iff IRQs are blocked
     *  @details  IRQs are blocked by setting the I flag to 1. The I flag is set with the SEI command
     *            and cleared with the CLI command. Note that the timing is important here! When an
     *            interrupt occures while SEI or CLI is executed, the previous value of I determines
     *            whether an interrupt is triggered or not. To handle timing correctly, the previous
     *            value of I is stored in variable oldI whenever SEI or CLI is executed.
     */
    bool IRQsAreBlocked();

	//! @brief    Sets a bit of the IRQ line.
	void setIRQLine(uint8_t bit);
	
	//! @brief    Clears a bit of the IRQ line.
    inline void clearIRQLine(uint8_t bit) { irqLine &= ~bit; interruptsPending = irqLine || nmiEdge; }
		
	//! @brief    Returns bit of IRQ line.
	inline uint8_t getIRQLine(uint8_t bit) { return irqLine & bit; }
	
	//! @brief    Checks if IRQ line has been activated for at least 2 cycles.
	bool IRQLineRaisedLongEnough();
	
	//! @brief    Sets bit of NMI line.
	void setNMILine(uint8_t bit);

    //! @brief    Indicates a negative edge on the NMI line.
    void setNMIEdge();

    //! @brief    Removes negative edge indicator for the NMI line.
    void clearNMIEdge();

	//! @brief    Clears bit of NMI line.
	inline void clearNMILine(uint8_t bit) { nmiLine &= ~bit; }
	
	//! @brief    Checks if NMI line has been activated for at least 2 cycles.
	bool NMILineRaisedLongEnough();
	
	//! @brief    Sets CIA bit of IRQ line.
	inline void setIRQLineCIA() { setIRQLine(0x01); }
    
	//! @brief    Sets VIC bit of IRQ line.
	inline void setIRQLineVIC() { setIRQLine(0x02); }
    
    //! @brief    Sets VIA bit of IRQ line (1541 drive).
    inline void setIRQLineVIA() { setIRQLine(0x10); }
    
	//! @brief    Sets ATN bit of IRQ line (1541 drive).
	inline void setIRQLineATN() { setIRQLine(0x40); }
    
	//! @brief    Clears CIA bit of IRQ line.
	inline void clearIRQLineCIA() { clearIRQLine(0x01); }
    
	//! @brief    Clears VIC bit of IRQ line.
	inline void clearIRQLineVIC() { clearIRQLine(0x02); }
    
    //! @brief    Clears VIA 1 bit of IRQ line (1541 drive).
    inline void clearIRQLineVIA() { clearIRQLine(0x10); }
    
	//! @brief    Clears ATN bit of IRQ line (1541 drive).
	inline void clearIRQLineATN() { clearIRQLine(0x40); }
    
	//! @brief    Sets CIA bit of NMI line.
	inline void setNMILineCIA() { setNMILine(0x01); }
    
	//! @brief    Clears CIA bit of NMI line.
	inline void clearNMILineCIA() { clearNMILine(0x01); }
    
	//! @brief    Sets reset bit of NMI line.
	inline void setNMILineReset() { setNMILine(0x08); }
    
	//! @brief    Clears reset bit of NMI line.
	inline void clearNMILineReset() { clearNMILine(0x08); }
    
	//! @brief    Sets the RDY line.
	inline void setRDY(bool value) { rdyLine = value; }
		
    
    //
    //! @functiongroup Examining the currently executed instruction
    //
    
	//! @brief    Returns the three letter mnemonic for a given opcode.
	const char *getMnemonic(uint8_t opcode);
    
	//! @brief    Returns the three letter mnemonic of the next instruction to execute.
	const char *getMnemonic() { return getMnemonic(mem->peek(PC)); }
    
	//! @brief    Returns the adressing mode for a given opcode.
	AddressingMode getAddressingMode(uint8_t opcode);
    
	//! @brief    Returns the adressing mode of the next instruction to execute.
	AddressingMode getAddressingMode() { return getAddressingMode(mem->peek(PC)); }
    
	/*! @brief    Returns the length in bytes of the instruction with the specified opcode.
	 *  @result   Integer value between 1 and 3.
     */
	int getLengthOfInstruction(uint8_t opcode);
    
	/*! @brief    Returns the length in bytes of the instruction with the specified address.
     *  @result   Integer value between 1 and 3.
     */
	inline int getLengthOfInstructionAtAddress(uint16_t addr) { return getLengthOfInstruction(mem->peek(addr)); }
    
	/*! @brief    Returns the length in bytes of the next instruction to execute.
     *  @result   Integer value between 1 and 3.
     */
	inline int getLengthOfCurrentInstruction() { return getLengthOfInstructionAtAddress(PC_at_cycle_0); }
    
	/*! @brief    Returns the address of the instruction following the current instruction.
     *  @result   Integer value between 1 and 3.
     */
    inline uint16_t getAddressOfNextInstruction() { return PC_at_cycle_0 + getLengthOfCurrentInstruction(); }
    
	//! @brief    Disassembles the current instruction.
	char *disassemble();
				
	//! @brief    Returns true, iff the next cycle is the first cycle of a command.
	inline bool atBeginningOfNewCommand() { return next == &CPU::fetch; }
	
    
    //
    //! @functiongroup Executing the device
    //
    
	/*! @brief    Executes the device for one cycle.
	 *  @details  This is the normal operation mode. Interrupt requests are handled. 
     */
	inline bool executeOneCycle() { (*this.*next)(); return errorState == CPU::OK; }

	//! @brief    Returns the current error state.
    inline ErrorState getErrorState() { return errorState; }
    
	//! @brief    Sets the error state.
    void setErrorState(ErrorState state);
    
	//! @brief    Sets the error state back to normal.
    void clearErrorState() { setErrorState(OK); }
    
    
    //
    //! @functiongroup Handling breakpoints
    //
    
	//! @brief    Returns breakpoint tag for the specified address.
	inline uint8_t getBreakpointTag(uint16_t addr) { return breakpoint[addr]; }
	
	//! @brief    Returns the breakpoint tag for the specified address.
	uint8_t getBreakpoint(uint16_t addr) { return breakpoint[addr]; }

	//! @brief    Sets a breakpoint tag at the specified address.
	void setBreakpoint(uint16_t addr, uint8_t tag) { breakpoint[addr] = tag; }
	
	//! @brief    Sets a hard breakpoint at the specified address.
    void setHardBreakpoint(uint16_t addr) { breakpoint[addr] |= HARD_BREAKPOINT; }
	
	//! @brief    Deletes a hard breakpoint at the specified address.
	void deleteHardBreakpoint(uint16_t addr) { breakpoint[addr] &= (255-HARD_BREAKPOINT); }
	
	//! @brief    Sets or deletes a hard breakpoint at the specified address.
	void toggleHardBreakpoint(uint16_t addr) { breakpoint[addr] ^= HARD_BREAKPOINT; }
    
	//! @brief    Sets a soft breakpoint at the specified address.
	void setSoftBreakpoint(uint16_t addr) { breakpoint[addr] |= SOFT_BREAKPOINT; }
    
	//! @brief    Deletes a soft breakpoint at the specified address.
	void deleteSoftBreakpoint(uint16_t addr) { breakpoint[addr] &= (255-SOFT_BREAKPOINT); }
    
	//! @brief    Sets or deletes a hard breakpoint at the specified address.
	void toggleSoftBreakpoint(uint16_t addr) { breakpoint[addr] ^= SOFT_BREAKPOINT; }

    
    //
    //! @functiongroup Querying the callstack
    //
    
	//! @brief    Reads entry from callstack.
	int getTopOfCallStack() { return (callStackPointer > 0) ? callStack[callStackPointer-1] : -1; }

};

#endif
