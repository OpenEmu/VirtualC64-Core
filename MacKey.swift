//
// This file is part of VirtualC64 - A cycle accurate Commodore 64 emulator
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
//

import Foundation
import Carbon.HIToolbox

/// The C64Key structure represents a physical keys on the C64 keyboard.
/// The key is specified by its row and coloumn position in the C64 keyboard matrix.
struct MacKey: Codable {

    /// Unique identifier for a key on the Mac keyboard
    var keyCode: UInt16 = 0

    /// Keycode in hex format as a string
    var keyCodeStr: String { return String(format: "%02X", keyCode) }

    /// Textual description of this key
    var description: String?

    init(keyCode: UInt16, characters: String? = nil) {
        self.keyCode = keyCode
        self.description = characters
    }

    init(keyCode: Int, characters: String? = nil) {
        self.init(keyCode: UInt16(keyCode), characters: characters)
    }

//    init(with event: NSEvent) {
//
//        keyCode = event.keyCode
//
//        let stdSymbols: [Int: String] = [
//            kVK_Return: "\u{21a9}",
//            kVK_Tab: "\u{21e5}",
//            kVK_Space: "\u{23b5}",
//            kVK_Delete: "\u{232b}",
//            kVK_Escape: "\u{238b}",
//            kVK_Shift: "\u{21e7}",
//            kVK_Option: "\u{2325}",
//            kVK_Control: "\u{2303}",
//            kVK_F1: "F1",
//            kVK_F2: "F2",
//            kVK_F3: "F3",
//            kVK_F4: "F4",
//            kVK_F5: "F5",
//            kVK_F6: "F6",
//            kVK_F7: "F7",
//            kVK_F8: "F8",
//            kVK_LeftArrow: "\u{2190}",
//            kVK_RightArrow: "\u{2192}",
//            kVK_DownArrow: "\u{2193}",
//            kVK_UpArrow: "\u{2191}"
//        ]
//
//        description = stdSymbols[Int(keyCode)] ?? event.charactersIgnoringModifiers
//    }
}

extension MacKey: Equatable {
    static func == (lhs: MacKey, rhs: MacKey) -> Bool {
        return lhs.keyCode == rhs.keyCode
    }
}

extension MacKey: Hashable {
    func hash(into hasher: inout Hasher) {
        return hasher.combine(self.keyCode)
    }
}

extension MacKey {

    // Layout independend keys. Keycodes are the same on all Mac keyboards
    static let ret          = MacKey(keyCode: kVK_Return, characters: "\u{21a9}")
    static let tab          = MacKey(keyCode: kVK_Tab, characters: "\u{21e5}")
    static let space        = MacKey(keyCode: kVK_Space, characters: "\u{23b5}")
    static let delete       = MacKey(keyCode: kVK_Delete, characters: "\u{232b}")
    static let escape       = MacKey(keyCode: kVK_Escape, characters: "\u{238b}")
    static let leftShift    = MacKey(keyCode: kVK_Shift, characters: "\u{21e7}")
    static let rightShift   = MacKey(keyCode: kVK_RightShift, characters: "\u{21e7}")
    static let option       = MacKey(keyCode: kVK_Option, characters: "\u{2325}")
    static let control      = MacKey(keyCode: kVK_Control, characters: "\u{2303}")
    static let home         = MacKey(keyCode: kVK_Home, characters: "\u{21f1}")
    static let clear        = MacKey(keyCode: kVK_ANSI_KeypadClear, characters: "\u{2327}")

    static let F1 = MacKey(keyCode: kVK_F1, characters: "F1")
    static let F2 = MacKey(keyCode: kVK_F2, characters: "F2")
    static let F3 = MacKey(keyCode: kVK_F3, characters: "F3")
    static let F4 = MacKey(keyCode: kVK_F4, characters: "F4")
    static let F5 = MacKey(keyCode: kVK_F5, characters: "F5")
    static let F6 = MacKey(keyCode: kVK_F6, characters: "F6")
    static let F7 = MacKey(keyCode: kVK_F7, characters: "F7")
    static let F8 = MacKey(keyCode: kVK_F8, characters: "F8")

    static let curLeft  = MacKey(keyCode: kVK_LeftArrow, characters: "\u{2190}")
    static let curRight = MacKey(keyCode: kVK_RightArrow, characters: "\u{2192}")
    static let curDown  = MacKey(keyCode: kVK_DownArrow, characters: "\u{2193}")
    static let curUp    = MacKey(keyCode: kVK_UpArrow, characters: "\u{2191}")

    // Layout dependend keys. Keycodes refer to the keys on a standard ANSI US keyboard
    struct Ansi {
        static let grave = MacKey(keyCode: kVK_ANSI_Grave, characters: "")
        static let digit0 = MacKey(keyCode: kVK_ANSI_0, characters: "0")
        static let digit1 = MacKey(keyCode: kVK_ANSI_1, characters: "1")
        static let digit2 = MacKey(keyCode: kVK_ANSI_2, characters: "2")
        static let digit3 = MacKey(keyCode: kVK_ANSI_3, characters: "3")
        static let digit4 = MacKey(keyCode: kVK_ANSI_4, characters: "4")
        static let digit5 = MacKey(keyCode: kVK_ANSI_5, characters: "5")
        static let digit6 = MacKey(keyCode: kVK_ANSI_6, characters: "6")
        static let digit7 = MacKey(keyCode: kVK_ANSI_7, characters: "7")
        static let digit8 = MacKey(keyCode: kVK_ANSI_8, characters: "8")
        static let digit9 = MacKey(keyCode: kVK_ANSI_9, characters: "9")
        static let minus = MacKey(keyCode: kVK_ANSI_Minus, characters: "")
        static let equal = MacKey(keyCode: kVK_ANSI_Equal, characters: "")

        static let A = MacKey(keyCode: kVK_ANSI_A, characters: "A")
        static let a = MacKey(keyCode: kVK_ANSI_A, characters: "a")
        static let B = MacKey(keyCode: kVK_ANSI_B, characters: "B")
        static let C = MacKey(keyCode: kVK_ANSI_C, characters: "C")
        static let c = MacKey(keyCode: kVK_ANSI_C, characters: "c")
        static let D = MacKey(keyCode: kVK_ANSI_D, characters: "D")
        static let d = MacKey(keyCode: kVK_ANSI_D, characters: "d")
        static let E = MacKey(keyCode: kVK_ANSI_E, characters: "E")
        static let e = MacKey(keyCode: kVK_ANSI_E, characters: "e")
        static let F = MacKey(keyCode: kVK_ANSI_F, characters: "F")
        static let G = MacKey(keyCode: kVK_ANSI_G, characters: "G")
        static let H = MacKey(keyCode: kVK_ANSI_H, characters: "H")
        static let I = MacKey(keyCode: kVK_ANSI_I, characters: "I")
        static let J = MacKey(keyCode: kVK_ANSI_J, characters: "J")
        static let K = MacKey(keyCode: kVK_ANSI_K, characters: "K")
        static let L = MacKey(keyCode: kVK_ANSI_L, characters: "L")
        static let M = MacKey(keyCode: kVK_ANSI_M, characters: "M")
        static let N = MacKey(keyCode: kVK_ANSI_N, characters: "N")
        static let O = MacKey(keyCode: kVK_ANSI_O, characters: "O")
        static let P = MacKey(keyCode: kVK_ANSI_P, characters: "P")
        static let Q = MacKey(keyCode: kVK_ANSI_Q, characters: "Q")
        static let R = MacKey(keyCode: kVK_ANSI_R, characters: "R")
        static let S = MacKey(keyCode: kVK_ANSI_S, characters: "S")
        static let s = MacKey(keyCode: kVK_ANSI_S, characters: "s")
        static let T = MacKey(keyCode: kVK_ANSI_T, characters: "T")
        static let U = MacKey(keyCode: kVK_ANSI_U, characters: "U")
        static let V = MacKey(keyCode: kVK_ANSI_V, characters: "V")
        static let W = MacKey(keyCode: kVK_ANSI_W, characters: "W")
        static let w = MacKey(keyCode: kVK_ANSI_W, characters: "w")
        static let X = MacKey(keyCode: kVK_ANSI_X, characters: "X")
        static let x = MacKey(keyCode: kVK_ANSI_X, characters: "x")
        static let Y = MacKey(keyCode: kVK_ANSI_Y, characters: "Y")
        static let y = MacKey(keyCode: kVK_ANSI_Y, characters: "y")
        static let Z = MacKey(keyCode: kVK_ANSI_Z, characters: "Z")

        static let leftBracket  = MacKey(keyCode: kVK_ANSI_LeftBracket, characters: "[")
        static let rightBracket = MacKey(keyCode: kVK_ANSI_RightBracket, characters: "]")

        static let comma     = MacKey(keyCode: kVK_ANSI_Comma, characters: ",")
        static let period    = MacKey(keyCode: kVK_ANSI_Period, characters: ".")
        static let slash     = MacKey(keyCode: kVK_ANSI_Slash, characters: "/")
        static let backSlash = MacKey(keyCode: kVK_ANSI_Backslash, characters: "\\")
        static let semicolon = MacKey(keyCode: kVK_ANSI_Semicolon, characters: ";")
        static let quote     = MacKey(keyCode: kVK_ANSI_Quote, characters: "'")
    }

    // Layout dependend keys. Keycodes refer to the keys on a standard ANSI US keyboard
    struct Iso {
        static let hat = MacKey(keyCode: 0x0A, characters: "")
    }
}
