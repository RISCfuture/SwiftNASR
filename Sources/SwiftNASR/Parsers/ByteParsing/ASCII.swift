/// Named ASCII byte constants for use in byte-level parsing.
///
/// Using named constants instead of inline literals improves readability and reduces errors.
@usableFromInline
enum ASCII {
  // Control characters
  @usableFromInline static let nul: UInt8 = 0x00
  @usableFromInline static let tab: UInt8 = 0x09
  @usableFromInline static let lineFeed: UInt8 = 0x0A
  @usableFromInline static let carriageReturn: UInt8 = 0x0D

  // Whitespace
  @usableFromInline static let space: UInt8 = 0x20

  // Punctuation and symbols
  @usableFromInline static let exclamation: UInt8 = 0x21
  @usableFromInline static let quote: UInt8 = 0x22
  @usableFromInline static let hash: UInt8 = 0x23
  @usableFromInline static let dollar: UInt8 = 0x24
  @usableFromInline static let percent: UInt8 = 0x25
  @usableFromInline static let ampersand: UInt8 = 0x26
  @usableFromInline static let apostrophe: UInt8 = 0x27
  @usableFromInline static let leftParen: UInt8 = 0x28
  @usableFromInline static let rightParen: UInt8 = 0x29
  @usableFromInline static let asterisk: UInt8 = 0x2A
  @usableFromInline static let plus: UInt8 = 0x2B
  @usableFromInline static let comma: UInt8 = 0x2C
  @usableFromInline static let minus: UInt8 = 0x2D
  @usableFromInline static let period: UInt8 = 0x2E
  @usableFromInline static let slash: UInt8 = 0x2F

  // Digits
  @usableFromInline static let zero: UInt8 = 0x30
  @usableFromInline static let one: UInt8 = 0x31
  @usableFromInline static let two: UInt8 = 0x32
  @usableFromInline static let three: UInt8 = 0x33
  @usableFromInline static let four: UInt8 = 0x34
  @usableFromInline static let five: UInt8 = 0x35
  @usableFromInline static let six: UInt8 = 0x36
  @usableFromInline static let seven: UInt8 = 0x37
  @usableFromInline static let eight: UInt8 = 0x38
  @usableFromInline static let nine: UInt8 = 0x39

  // Punctuation
  @usableFromInline static let colon: UInt8 = 0x3A
  @usableFromInline static let semicolon: UInt8 = 0x3B
  @usableFromInline static let lessThan: UInt8 = 0x3C
  @usableFromInline static let equals: UInt8 = 0x3D
  @usableFromInline static let greaterThan: UInt8 = 0x3E
  @usableFromInline static let question: UInt8 = 0x3F
  @usableFromInline static let at: UInt8 = 0x40

  // Uppercase letters
  @usableFromInline static let A: UInt8 = 0x41
  @usableFromInline static let B: UInt8 = 0x42
  @usableFromInline static let C: UInt8 = 0x43
  @usableFromInline static let D: UInt8 = 0x44
  @usableFromInline static let E: UInt8 = 0x45
  @usableFromInline static let F: UInt8 = 0x46
  @usableFromInline static let G: UInt8 = 0x47
  @usableFromInline static let H: UInt8 = 0x48
  @usableFromInline static let I: UInt8 = 0x49
  @usableFromInline static let J: UInt8 = 0x4A
  @usableFromInline static let K: UInt8 = 0x4B
  @usableFromInline static let L: UInt8 = 0x4C
  @usableFromInline static let M: UInt8 = 0x4D
  @usableFromInline static let N: UInt8 = 0x4E
  @usableFromInline static let O: UInt8 = 0x4F
  @usableFromInline static let P: UInt8 = 0x50
  @usableFromInline static let Q: UInt8 = 0x51
  @usableFromInline static let R: UInt8 = 0x52
  @usableFromInline static let S: UInt8 = 0x53
  @usableFromInline static let T: UInt8 = 0x54
  @usableFromInline static let U: UInt8 = 0x55
  @usableFromInline static let V: UInt8 = 0x56
  @usableFromInline static let W: UInt8 = 0x57
  @usableFromInline static let X: UInt8 = 0x58
  @usableFromInline static let Y: UInt8 = 0x59
  @usableFromInline static let Z: UInt8 = 0x5A

  // Brackets
  @usableFromInline static let leftBracket: UInt8 = 0x5B
  @usableFromInline static let backslash: UInt8 = 0x5C
  @usableFromInline static let rightBracket: UInt8 = 0x5D
  @usableFromInline static let caret: UInt8 = 0x5E
  @usableFromInline static let underscore: UInt8 = 0x5F
  @usableFromInline static let backtick: UInt8 = 0x60

  // Lowercase letters
  @usableFromInline static let a: UInt8 = 0x61
  @usableFromInline static let b: UInt8 = 0x62
  @usableFromInline static let c: UInt8 = 0x63
  @usableFromInline static let d: UInt8 = 0x64
  @usableFromInline static let e: UInt8 = 0x65
  @usableFromInline static let f: UInt8 = 0x66
  @usableFromInline static let g: UInt8 = 0x67
  @usableFromInline static let h: UInt8 = 0x68
  @usableFromInline static let i: UInt8 = 0x69
  @usableFromInline static let j: UInt8 = 0x6A
  @usableFromInline static let k: UInt8 = 0x6B
  @usableFromInline static let l: UInt8 = 0x6C
  @usableFromInline static let m: UInt8 = 0x6D
  @usableFromInline static let n: UInt8 = 0x6E
  @usableFromInline static let o: UInt8 = 0x6F
  @usableFromInline static let p: UInt8 = 0x70
  @usableFromInline static let q: UInt8 = 0x71
  @usableFromInline static let r: UInt8 = 0x72
  @usableFromInline static let s: UInt8 = 0x73
  @usableFromInline static let t: UInt8 = 0x74
  @usableFromInline static let u: UInt8 = 0x75
  @usableFromInline static let v: UInt8 = 0x76
  @usableFromInline static let w: UInt8 = 0x77
  @usableFromInline static let x: UInt8 = 0x78
  @usableFromInline static let y: UInt8 = 0x79
  @usableFromInline static let z: UInt8 = 0x7A

  // Braces
  @usableFromInline static let leftBrace: UInt8 = 0x7B
  @usableFromInline static let pipe: UInt8 = 0x7C
  @usableFromInline static let rightBrace: UInt8 = 0x7D
  @usableFromInline static let tilde: UInt8 = 0x7E

  /// Returns true if the byte is an ASCII digit (0-9).
  @inlinable
  static func isDigit(_ byte: UInt8) -> Bool {
    byte >= zero && byte <= nine
  }

  /// Returns true if the byte is an ASCII uppercase letter (A-Z).
  @inlinable
  static func isUppercase(_ byte: UInt8) -> Bool {
    byte >= A && byte <= Z
  }

  /// Returns true if the byte is an ASCII lowercase letter (a-z).
  @inlinable
  static func isLowercase(_ byte: UInt8) -> Bool {
    byte >= a && byte <= z
  }

  /// Returns true if the byte is an ASCII letter (A-Z or a-z).
  @inlinable
  static func isLetter(_ byte: UInt8) -> Bool {
    isUppercase(byte) || isLowercase(byte)
  }

  /// Returns true if the byte is ASCII whitespace (space or tab).
  @inlinable
  static func isWhitespace(_ byte: UInt8) -> Bool {
    byte == space || byte == tab
  }
}
