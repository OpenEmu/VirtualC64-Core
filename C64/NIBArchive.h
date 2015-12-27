/*
 * Author: Dirk W. Hoffmann, www.dirkwhoffmann.de
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

#ifndef _NIBARCHIVE_INC
#define _NIBARCHIVE_INC

#include "Archive.h"

#define MIN_TRACK_LENGTH 6016
#define MAX_TRACK_LENGTH 7928

/*! @class NIBArchive
 *  @brief The NIBArchive class declares the programmatic interface for a file in NIB format.
 */
class NIBArchive : public Archive {

private:	

    /*! @brief      Raw data of this archive */
    uint8_t *data;

    /*! @brief      Size of NIB file */
    int size;

    /*! @brief      Decoded track data */
    uint8_t halftrack[85][8 * MAX_TRACK_LENGTH];

    /*! @brief      Decoded track length in bits
     *  @discussion Equals 0 if halftrack is not contained in archive */
    int length[85];
    
    /*! @brief Selected halftrack to read from. */
	int selectedtrack;

    /*! @brief File pointer
     @discussion An offset into the halftrack array. */
    int fp;

public:

    //
    //! @functiongroup Creating and destructing NIB archives
    //
    
    //! @brief Standard constructor.
    NIBArchive();
    
    //! @brief Standard destructor.
    ~NIBArchive();
		
    //! @brief Returns true iff the specified file is a NIB file
    static bool isNIBFile(const char *filename);

    //! @brief Creates a NIB archive from a NIB file located on disk.
    static NIBArchive *archiveFromNIBFile(const char *filename);
    
    /*! @brief Creates a NIB archive from a virtual 5,25 floppy disk. */
    // static NIBArchive *archiveFromDisk(Disk525 *disk);

    /*! @brief      Scans all tracks in archive
     *  @returns    true, if the scan was successful, false, if archive data is corrupt 
     *  @seealso    scanTrack */
    bool scan();

    /*! @brief      Scans a single track in archive
     *  @discussion For eack track, the number of bits is determined and stored in array numBits.
     *              Furthermore, the total number of tracks is stored in variable numTracks.
     *  @param      ht       Halftrack number
     *  @param      bits     The raw bit stream
     *  @param      start    Offset the the first bit of the loop
     *  @param      end      Offset the last bit belonging to the loop + 1
     *  @param      gap      Offset to the gap position
     *  @returns    true, if the scan was successful, false, if archive data is corrupt */
    bool scanTrack(unsigned ht, uint8_t *bits, int *start, int *end, int *gap);
    
    /*! @brief      Looks for a loop in the provided bit stream
     *  @discussion A NIB file consists of 0x2000 bytes a nibbled data. As the nibbler cannot determine
     *              when the drive head has completed a full rotation, the bit stream data overlaps.
     *              This method searches for the overlap. If the repeating code sequence has been found,
     *              the start and the end position are stored in startBit and endBit, respectively.
     *  @param      bits     The raw bit stream. 
     *  @param      length   Length of the provided bit stream
     *  @param      start    Offset the the first bit of the loop
     *  @param      end      Offset the last bit belonging to the loop + 1
     *  @return     true if the repetition has been found. */
    bool scanForLoop(uint8_t *bits, int length, int *start, int *end);

    /*! @brief      Looks for the longest area between two SYNC marks
     *  @discussion The computed offset is used to properly align the tracks next to each other.
     *  @param      bits     The raw bit stream as stored in the NIB file. 
     *  @param      length   Length of the provided bit stream
     *  @param      gap      Offset to the gap position
     *  @return     true if a gap has been found, false otherwise. */
    bool scanForGap(uint8_t *bits, int length, int *gap);

    
    //
    // Virtual functions from Container class
    //
    
    void dealloc();
    
    const char *getName();
    ContainerType getType() { return NIB_CONTAINER; }
    const char *getTypeAsString() { return "NIB"; }
    
    bool fileIsValid(const char *filename);
    bool readFromBuffer(const uint8_t *buffer, unsigned length);
    unsigned writeToBuffer(uint8_t *buffer);
    
    //
    // Virtual functions from Archive class
    //
    
    int getNumberOfItems();
    // int getStartOfItem(int n);
    int getSizeOfItem(int n);
    
    const char *getNameOfItem(int n);
    const char *getTypeOfItem(int n);
    uint16_t getDestinationAddrOfItem(int n) { return 0; }
    
    void selectItem(int n);
    int getByte();
};


#endif

