import Foundation
import CoreGraphics

struct TextStyle: Codable, Equatable {
    var fontName: String
    var fontSize: CGFloat
    var textColorHex: String
    var backgroundColorHex: String?
    var outlineColorHex: String?
    var outlineWidth: CGFloat
    var shadowColorHex: String?
    var shadowOffset: CGSize
    var shadowBlur: CGFloat
    var alignment: TextAlignment
    var lineSpacing: CGFloat
    var letterSpacing: CGFloat
    
    static let `default` = TextStyle(
        fontName: "Helvetica-Bold",
        fontSize: 24,
        textColorHex: "#FFFFFF",
        backgroundColorHex: nil,
        outlineColorHex: nil,
        outlineWidth: 0,
        shadowColorHex: nil,
        shadowOffset: .zero,
        shadowBlur: 0,
        alignment: .center,
        lineSpacing: 0,
        letterSpacing: 0
    )
}

enum TextAlignment: String, Codable {
    case left
    case center
    case right
}
