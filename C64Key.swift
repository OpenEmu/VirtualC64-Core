//
// This file is part of VirtualC64 - A cycle accurate Commodore 64 emulator
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
//

// swiftlint:disable comma

import Foundation

/// The C64Key structure represents a physical keys on the C64 keyboard.
/// Each of the 66 keys is specified uniquely by it's number ranging from
/// 0 to 64. When a key is pressed, a row bit and a column bit is set in the
/// keyboard matrix that can be read by the CIA chip. Note that the CapsLock
/// and the Restore key behave differently. Caps lock is a switch that holds
/// down the left shift key until it is released and restore has no key matrix
/// representation at all. Instead, it is directly connected to the NMI line.

struct C64Key: Codable {
    
    // A number that identifies this key uniquely
    var nr = -1
    
    // Row index
    var row = -1
    
    // Column index
    var col = -1
    
    // Flags for key modifiers
    let DEFAULT = 0
    let SHIFT = 1
    let COMMODORE = 2
    let LOWER = 4
    
    init(_ nr: Int) {
        
        precondition(nr >= 0 && nr <= 65)
        
        let rowcol = [
            // First physical key row
            (7, 1), (7, 0), (7, 3), (1, 0), (1, 3), (2, 0), (2, 3), (3, 0),
            (3, 3), (4, 0), (4, 3), (5, 0), (5, 3), (6, 0), (6, 3), (0, 0),
            (0, 4) /* f1 */,
            
            // Second physical key row
            (7, 2), (7, 6), (1, 1), (1, 6), (2, 1), (2, 6), (3, 1), (3, 6),
            (4, 1), (4, 6), (5, 1), (5, 6), (6, 1), (6, 6), (9, 9), (0, 5) /* f3 */,

            // Third physical key row
            (7, 7), (9, 9), (1, 2), (1, 5), (2, 2), (2, 5), (3, 2), (3, 5),
            (4, 2), (4, 5), (5, 2), (5, 5), (6, 2), (6, 5), (0, 1), (0, 6) /* f5 */,
            
            // Fourth physical key row
            (7, 5), (1, 7), (1, 4), (2, 7), (2, 4), (3, 7), (3, 4), (4, 7),
            (4, 4), (5, 7), (5, 4), (6, 7), (6, 4), (0, 7), (0, 2), (0, 3) /* f7 */,
            
            // Fifth physical key row
            (7, 4) /* space */
        ]
        
        precondition(rowcol.count == 66)
        
        self.nr = nr
        if nr != 31 /* RESTORE */ && nr != 34 /* SHIFT LOCK */ {
            self.row = rowcol[nr].0
            self.col = rowcol[nr].1
        } else {
            precondition(rowcol[nr].0 == 9 && rowcol[nr].1 == 9)
        }
    }
    
    init(_ rowcol: (Int, Int) ) {
        
        precondition(rowcol.0 >= 0 && rowcol.0 < 8)
        precondition(rowcol.1 >= 0 && rowcol.1 < 8)
        
        let nr = [ 15, 47, 63, 64, 16, 32, 48, 62,
                   3, 19, 35, 4, 51, 36, 20, 50,
                   5, 21, 37, 6, 53, 38, 22, 52,
                   7, 23, 39, 8, 55, 40, 24, 54,
                   9, 25, 41, 10, 57, 42, 26, 56,
                   11, 27, 43, 12, 59, 44, 28, 58,
                   13, 29, 45, 14, 61, 46, 30, 60,
                   1, 0, 17, 2, 65, 49, 18, 33
        ]
        
        precondition(nr.count == 64)
        
        self.row = rowcol.0
        self.col = rowcol.1
        self.nr = nr[8 * row + col]
    }
}

extension C64Key: Equatable {
    static func == (lhs: C64Key, rhs: C64Key) -> Bool {
        return lhs.nr == rhs.nr
    }
}

extension C64Key: Hashable {
    
    func hash(into hasher: inout Hasher) {
        
        return hasher.combine(nr)
    }
}

extension C64Key {
    
    // First row
    static let delete       = C64Key(15)
    static let ret          = C64Key(47)
    static let curLeftRight = C64Key(63)
    static let F7F8         = C64Key(64)
    static let F1F2         = C64Key(16)
    static let F3F4         = C64Key(32)
    static let F5F6         = C64Key(48)
    static let curUpDown    = C64Key(62)
    
    // Second row
    static let digit3       = C64Key(3)
    static let W            = C64Key(19)
    static let A            = C64Key(35)
    static let digit4       = C64Key(4)
    static let Z            = C64Key(51)
    static let S            = C64Key(36)
    static let E            = C64Key(20)
    static let shift        = C64Key(50)
    
    // Third row
    static let digit5       = C64Key(5)
    static let R            = C64Key(21)
    static let D            = C64Key(37)
    static let digit6       = C64Key(6)
    static let C            = C64Key(53)
    static let F            = C64Key(38)
    static let T            = C64Key(22)
    static let X            = C64Key(52)
    
    // Fourth row
    static let digit7       = C64Key(7)
    static let Y            = C64Key(23)
    static let G            = C64Key(39)
    static let digit8       = C64Key(8)
    static let B            = C64Key(55)
    static let H            = C64Key(40)
    static let U            = C64Key(24)
    static let V            = C64Key(54)
    
    // Fifth row
    static let digit9       = C64Key(9)
    static let I            = C64Key(25)
    static let J            = C64Key(41)
    static let digit0       = C64Key(10)
    static let M            = C64Key(57)
    static let K            = C64Key(42)
    static let O            = C64Key(26)
    static let N            = C64Key(56)
    
    // Sixth row
    static let plus         = C64Key(11)
    static let P            = C64Key(27)
    static let L            = C64Key(43)
    static let minus        = C64Key(12)
    static let period       = C64Key(59)
    static let colon        = C64Key(44)
    static let at           = C64Key(28)
    static let comma        = C64Key(58)
    
    // Seventh row
    static let pound        = C64Key(13)
    static let asterisk     = C64Key(29)
    static let semicolon    = C64Key(45)
    static let home         = C64Key(14)
    static let rightShift   = C64Key(61)
    static let equal        = C64Key(46)
    static let upArrow      = C64Key(30)
    static let slash        = C64Key(60)

    // Eights row
    static let digit1       = C64Key(1)
    static let leftArrow    = C64Key(0)
    static let control      = C64Key(17)
    static let digit2       = C64Key(2)
    static let space        = C64Key(65)
    static let commodore    = C64Key(49)
    static let Q            = C64Key(18)
    static let runStop      = C64Key(33)
    
    // Restore key
    static let restore      = C64Key(31)

    // Translates a character to a list of corresponding C64 keys
    // This function is used for symbolically mapping Mac keys to C64 keys
    static func translate(char: String?) -> [C64Key] {
        
        if char == nil { return [] }
        
        switch char! {
            
        // First row of C64 keyboard
        case "ü": return [C64Key.leftArrow]
        case "1": return [C64Key.digit1]
        case "!": return [C64Key.digit1, C64Key.shift]
        case "2": return [C64Key.digit2]
        case "\"": return [C64Key.digit2, C64Key.shift]
        case "3": return [C64Key.digit3]
        case "#": return [C64Key.digit3, C64Key.shift]
        case "4": return [C64Key.digit4]
        case "$": return [C64Key.digit4, C64Key.shift]
        case "5": return [C64Key.digit5]
        case "%": return [C64Key.digit5, C64Key.shift]
        case "6": return [C64Key.digit6]
        case "&": return [C64Key.digit6, C64Key.shift]
        case "7": return [C64Key.digit7]
        case "'": return [C64Key.digit7, C64Key.shift]
        case "8": return [C64Key.digit8]
        case "(": return [C64Key.digit8, C64Key.shift]
        case "9": return [C64Key.digit9]
        case ")": return [C64Key.digit9, C64Key.shift]
        case "0": return [C64Key.digit0]
        case "+": return [C64Key.plus]
        case "-": return [C64Key.minus]
        case "§": return [C64Key.pound]
            
        // Second row of C64 keyboard
        case "q": return [C64Key.Q]
        case "Q": return [C64Key.Q, C64Key.shift]
        case "w": return [C64Key.W]
        case "W": return [C64Key.W, C64Key.shift]
        case "e": return [C64Key.E]
        case "E": return [C64Key.E, C64Key.shift]
        case "r": return [C64Key.R]
        case "R": return [C64Key.R, C64Key.shift]
        case "t": return [C64Key.T]
        case "T": return [C64Key.T, C64Key.shift]
        case "y": return [C64Key.Y]
        case "Y": return [C64Key.Y, C64Key.shift]
        case "u": return [C64Key.U]
        case "U": return [C64Key.U, C64Key.shift]
        case "i": return [C64Key.I]
        case "I": return [C64Key.I, C64Key.shift]
        case "o": return [C64Key.O]
        case "O": return [C64Key.O, C64Key.shift]
        case "p": return [C64Key.P]
        case "P": return [C64Key.P, C64Key.shift]
        case "@": return [C64Key.at]
        case "ö": return [C64Key.at]
        case "*": return [C64Key.asterisk]
        case "ä": return [C64Key.upArrow]
            
        // Third row of C64 keyboard
        case "a": return [C64Key.A]
        case "A": return [C64Key.A, C64Key.shift]
        case "s": return [C64Key.S]
        case "S": return [C64Key.S, C64Key.shift]
        case "d": return [C64Key.D]
        case "D": return [C64Key.D, C64Key.shift]
        case "f": return [C64Key.F]
        case "F": return [C64Key.F, C64Key.shift]
        case "g": return [C64Key.G]
        case "G": return [C64Key.G, C64Key.shift]
        case "h": return [C64Key.H]
        case "H": return [C64Key.H, C64Key.shift]
        case "j": return [C64Key.J]
        case "J": return [C64Key.J, C64Key.shift]
        case "k": return [C64Key.K]
        case "K": return [C64Key.K, C64Key.shift]
        case "l": return [C64Key.L]
        case "L": return [C64Key.L, C64Key.shift]
        case ":": return [C64Key.colon]
        case "[": return [C64Key.colon, C64Key.shift]
        case ";": return [C64Key.semicolon]
        case "]": return [C64Key.semicolon, C64Key.shift]
        case "=": return [C64Key.equal]
        case "\n": return [C64Key.ret]

        // Fourth row of C64 keyboard
        case "z": return [C64Key.Z]
        case "Z": return [C64Key.Z, C64Key.shift]
        case "x": return [C64Key.X]
        case "X": return [C64Key.X, C64Key.shift]
        case "c": return [C64Key.C]
        case "C": return [C64Key.C, C64Key.shift]
        case "v": return [C64Key.V]
        case "V": return [C64Key.V, C64Key.shift]
        case "b": return [C64Key.B]
        case "B": return [C64Key.B, C64Key.shift]
        case "n": return [C64Key.N]
        case "N": return [C64Key.N, C64Key.shift]
        case "m": return [C64Key.M]
        case "M": return [C64Key.M, C64Key.shift]
        case ",": return [C64Key.comma]
        case "<": return [C64Key.comma, C64Key.shift]
        case ".": return [C64Key.period]
        case ">": return [C64Key.period, C64Key.shift]
        case "/": return [C64Key.slash]
        case "?": return [C64Key.slash, C64Key.shift]
           
        // Fifth row of C64 keyboard
        case " ": return [C64Key.space]
            
        default: return []
        }
    }
}
