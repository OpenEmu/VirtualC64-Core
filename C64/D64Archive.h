/*!
 * @header      D64Archive.h
 * @author      Dirk W. Hoffmann, www.dirkwhoffmann.de
 * @copyright   2008 - 2016 Dirk W. Hoffmann
 * @brief       Declares D64Archive class
 */
/* This program is free software; you can redistribute it and/or modify
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

#ifndef _D64ARCHIVE_INC
#define _D64ARCHIVE_INC

#include "Archive.h"

// Forward declarations
class VC1541;

// D64 files come in six different sizes
#define D64_683_SECTORS 174848
#define D64_683_SECTORS_ECC 175531
#define D64_768_SECTORS 196608
#define D64_768_SECTORS_ECC 197376
#define D64_802_SECTORS 205312
#define D64_802_SECTORS_ECC 206114


/*! @class   D64Archive
 *  @brief   An archive of type D64. 
 */
class D64Archive : public Archive {

private: 

	/*! @brief   The raw data of this archive.
     */
	uint8_t data[D64_802_SECTORS_ECC];
	
	/*! @brief   Error information stored in the D64 archive.
     */
	uint8_t errors[802];
	
	/*! @brief   The number of tracks stored in this archive.
        @details Possible values are 35, 40, and 42.
     */
	unsigned numTracks; 
	
	/*! @brief   File pointer
        @details An offset into the data array. 
     */
	int fp;

public:

    //
    //! @functiongroup Creating and destructing D64 archives
    //

	D64Archive();
	~D64Archive();
    
    /*! @brief   Returns true iff the specified file is a D64 file.
     */
    static bool isD64File(const char *filename);

    /*! @brief   Creates a D64 archive from a D64 file located on disk.
     */
    static D64Archive *archiveFromD64File(const char *filename);

	/*! @brief   Create a D64 archive from a file located on disk.
     *  @details If the provided filename points to a D64 archive, archiveFromD64File is invoked. 
     *           Otherwise, the format is converted automatically. 
     */
     static D64Archive *archiveFromArbitraryFile(const char *filename);

    /*! @brief   Creates a D64 archive from another D64 archive.
     *  @result  A one to one copy of the source archive.
     *  @seealso archiveFromArchive
     */
    static D64Archive *archiveFromD64Archive(D64Archive *archive);

    /*! @brief   Creates a D64 archive from an arbitrary archive.
     *  @result  If the provided archive is a D64 archive, archiveFromD64Archive is invoked.
     *           Otherwise, the format is converted automatically. 
     */
    static D64Archive *archiveFromArchive(Archive *archive);

    /*! @brief   Creates a D64 archive from a VC1541 drive.
     *  @param   drive A VC1541 drive with a disk inserted.
     *  @result  A D64 archive containing the same files as the currently inserted disk;
     *           NULL if no disk is inserted. */
     static D64Archive *archiveFromDrive(VC1541 *drive);

    
	//
    // Virtual functions from Container class
    //
    
    void dealloc() { };
    
    const char *getName();
    ContainerType getType() { return D64_CONTAINER; }
    const char *getTypeAsString() { return "D64"; }
	
    bool fileIsValid(const char *filename);
    bool readFromBuffer(const uint8_t *buffer, unsigned length);
    unsigned writeToBuffer(uint8_t *buffer);
    
    //
	// Virtual functions from Archive class
	//
    
    int getNumberOfItems();
    
	const char *getNameOfItem(int n);
	const char *getTypeOfItem(int n);
    int getSizeOfItemInBlocks(int n);
	uint16_t getDestinationAddrOfItem(int n);
    
	void selectItem(int n);
	int getByte();

    
    //
    //! @functiongroup Accessing archive attributes
    //
    
    //! Returns true iff item is a visible directory entry
    /*! Some files, e.g., deleted ones, are still present on the directory sector, but
        don't show up when loading the directory via LOAD "$",8.
        If the extension parameter is provides, an extension string is returned (e.g. "PRG").
        Invisible files will be returned with extension "" */
    bool itemIsVisible(uint8_t typeChar, const char **extension = NULL);
    
    //! @brief Returns the logical name of the archive in PET format
    const char *getNameAsPETString();
    
    //! @brief Returns the name of an item in PET format
    const char *getNameOfItemAsPETString(int n);
    
    //! @brief Class function that returns the total number of sectors in a specific track
    static unsigned numberOfSectors(unsigned trackNr);

	//! @brief Returns the number of tracks stored in this image
	unsigned numberOfTracks();
		
	//! @brief Returns the low byte of the disk ID
	uint8_t diskIdLow() { return data[offset(18, 0) + 0xA2]; }

	//! @brief Returns the high byte of the disk ID
	uint8_t diskIdHi() { return data[offset(18, 0) + 0xA3]; }

 
    //
    //! @functiongroup Accessing tracks and sectors
    //
    
public:

    //! Returns a pointer to the raw sector data
    uint8_t *findSector(unsigned track, unsigned sector);

private:
        
    //! Translates a track and sector number into an offset
    int offset(int track, int sector);

    //! @brief Returns true iff offset points to the last byte of a sector
    bool isLastByteOfSector(int offset) { return ((offset+1) % 256) == 0; }
    
    //! Returns the next logical track number following this sector
    /*! The track number is stored in the first byte of the current track */
    inline int nextTrack(int offset) { return data[offset & (~0xFF)]; }
    
    //! Returns the next logical sector number following this sector
    /*! The track number is stored in the second byte of the current track */
    inline int nextSector(int offset) { return data[(offset & (~0xFF)) + 1]; }
    
    //! @brief Return the next physical track and sector
    bool nextTrackAndSector(uint8_t track, uint8_t sector, uint8_t *nextTrack, uint8_t *nextSector, bool skipDirectory = false);
    
    /*! @brief   Jump to the beginning of the next sector
     *  @details pos is set to the beginning of the next sector.
     *  @result  True if the jump to the next sector was successful; false if the current sector points to an 
     *           invalid valid track/sector combination. In the failure case, pos remains untouched.
     */
    bool jumpToNextSector(int *pos);

    /*! @brief   Writes a byte to the specified track and sector
     *  @details If the sector overflows, the values of track and sector are overwritten with the next free sector
     *  @result  true if the byte was written successfully; false if there is no free space left on disk.
     */
    bool writeByteToSector(uint8_t byte, uint8_t *track, uint8_t *sector);

    
    //
    //! @functiongroup Accessing file and directory items
    //

private:
    
    /*! @brief   Marks a single sector as "used"
     */
    void markSectorAsUsed(uint8_t track, uint8_t sector);

    /*! @brief   Writes the Block Availability Map (BAM)
     *  @details On a C64 diskette, the BAM is located ion track 18, sector 0.
     *  @param   name Name of the disk
     */
    void writeBAM(const char *name);

    /*! @brief   Gathers data about all directory items
     *  @details This function scans all directory items and stores the relative start address of the first
     *           sector into the provided offsets array. Furthermore, the total number of files is written
     *           into variable noOfFiles.
     *  @param   offsets Pointer to an array of type unsigned[MAX_FILES_ON_DISK]
     *  @param   noOfFiles Pointer to a variable of type unsigned
     *  @param   skipInvisibleFiles If set to true, only those files are considered that would show
     *           up when loading the directory via LOAD "$",8. Otherwise, all files are considered, i.e. those
     *           that are marked as deleted.
     */
    void scanDirectory(unsigned *offsets, unsigned *noOfFiles, bool skipInvisibleFiles = true);
    
    /*! @brief   Looks up a directory item by number.
     *  @details This function searches the directory for the requested item. 
     *  @param   itemBumber Number of the item. The first item has number 0.
     *  @param   skipInvisibleFiles If set to true, only those files are considered that would show
     *           up when loading the directory via LOAD "$",8. Otherwise, all files are considered, i.e. those
     *           that are marked as deleted.
     *  @returns Offset to the first data sector of the requested file. If the file is not found, -1 is returned.
     */
    int findDirectoryEntry(int itemNumber, bool skipInvisibleFiles = true);
    
    //! Returns the track number of the first file block
    /*! Example usage: firstTrackOfFile(findDirectoryEntry(42)) */
    inline uint8_t firstTrackOfFile(unsigned dirEntry) { return data[dirEntry + 1]; }

    //! Returns the sector number of the first file block
    /*! Example usage: firstSectorOfFile(findDirectoryEntry(42)) */
    inline uint8_t firstSectorOfFile(unsigned dirEntry) { return data[dirEntry + 2]; }
    
    //! @brief Returns true iff offset points to the last byte of a file
    bool isEndOfFile(int offset) { return nextTrack(offset) == 0x00 && nextSector(offset) == offset % 256; }

    /*! @brief Writes a directory item
        @discussion This function is used to convert other archive formats into the D64 format. */
    bool writeDirectoryEntry(unsigned nr, const char *name, uint8_t startTrack, uint8_t startSector, unsigned filesize);
    

    //
    //! @functiongroup Debugging
    //
    
private:
    
	//! @brief Dumps the contents of a sector to stderr
	void dumpSector(int track, int sector);
};
#endif
