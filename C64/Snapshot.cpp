/*
 * (C) 2009 Dirk W. Hoffmann. All rights reserved.
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

#include "Snapshot.h"

Snapshot::Snapshot()
{
    header.magic[0] = 'V';
    header.magic[1] = 'C';
    header.magic[2] = '6';
    header.magic[3] = '4';
    header.major = V_MAJOR;
    header.minor = V_MINOR;
    header.subminor = V_SUBMINOR;
    header.size = 0;
    timestamp = (time_t)0;
    state = NULL;
}

Snapshot::~Snapshot()
{
    dealloc();
}

void
Snapshot::dealloc()
{
    if (state != NULL) {
        free(state);
        header.size = 0;
    }
}

bool
Snapshot::alloc(unsigned size)
{
    dealloc();
    
    if ((state = (uint8_t *)malloc(size)) == NULL)
        return false;
    
    header.size = size;
    return true;
}

Snapshot *
Snapshot::snapshotFromFile(const char *filename)
{
	Snapshot *snapshot;
	
	snapshot = new Snapshot();	
	if (!snapshot->readFromFile(filename)) {
		delete snapshot;
		snapshot = NULL;
	}
	return snapshot;
}

Snapshot *
Snapshot::snapshotFromBuffer(const uint8_t *buffer, unsigned size)
{
	Snapshot *snapshot;
	
	snapshot = new Snapshot();	
	if (!snapshot->readFromBuffer(buffer, size)) {
		delete snapshot;
		snapshot = NULL;
	}
	return snapshot;	
}

ContainerType
Snapshot::getType()
{
    return V64_CONTAINER;
}

const char *
Snapshot::getTypeAsString() 
{
	return "V64";
}

bool
Snapshot::isSnapshot(const char *filename)
{
    int magic_bytes[] = { 'V', 'C', '6', '4', EOF };
    
    assert(filename != NULL);
    
    if (!checkFileHeader(filename, magic_bytes))
        return false;
    
    return true;
}

bool
Snapshot::isSnapshot(const char *filename, int major, int minor, int subminor)
{
    int magic_bytes[] = { 'V', 'C', '6', '4', major, minor, subminor, EOF };
    
    assert(filename != NULL);
    
    if (!checkFileHeader(filename, magic_bytes))
        return false;
    
    return true;
}

bool 
Snapshot::fileIsValid(const char *filename)
{
    return Snapshot::isSnapshot(filename, V_MAJOR, V_MINOR, V_SUBMINOR);
}

bool 
Snapshot::readFromBuffer(const uint8_t *buffer, unsigned length)
{
    assert(buffer != NULL);
    assert(length > sizeof(header));

    // Allocate memory
    alloc(length - sizeof(header));
    
    // Copy header
    memcpy((uint8_t *)&header, buffer, sizeof(header));
    assert(header.size == length - sizeof(header));
    
    // Copy state data
    memcpy(state, buffer + sizeof(header), length - sizeof(header));
    
	return true;
}

unsigned
Snapshot::writeToBuffer(uint8_t *buffer)
{
    assert(state != NULL);
    
    // Copy header
    if (buffer)
        memcpy(buffer, (uint8_t *)&header, sizeof(header));

    // Copy state data
    if (buffer)
        memcpy(buffer + sizeof(header), state, header.size);

    return sizeof(header) + header.size;
}

void
Snapshot::takeScreenshot(uint32_t *buf, bool pal)
{
    unsigned x_start, y_start;
       
    if (pal) {
        x_start = PAL_LEFT_BORDER_WIDTH - 36;
        y_start = PAL_UPPER_BORDER_HEIGHT - 34;
        header.screenshot.width = 36 + PAL_CANVAS_WIDTH + 36;
        header.screenshot.height = 34 + PAL_CANVAS_HEIGHT + 34;
    } else {
        x_start = NTSC_LEFT_BORDER_WIDTH - 42;
        y_start = NTSC_UPPER_BORDER_HEIGHT - 9;
        header.screenshot.width = 36 + PAL_CANVAS_WIDTH + 36;
        header.screenshot.height = 9 + PAL_CANVAS_HEIGHT + 9;
    }
    
    uint32_t *target = header.screenshot.screen;
    buf += x_start + y_start * NTSC_PIXELS;
    for (unsigned i = 0; i < header.screenshot.height; i++) {
        memcpy(target, buf, header.screenshot.width * 4);
        target += header.screenshot.width;
        buf += NTSC_PIXELS;
    }
}
