import SwiftUI
import UIKit

/// The Saudi riyal sign (U+20C1), drawn from the official artwork because most fonts don't have it yet.
/// SAMA's rule: the sign goes to the left of the number, with a space between them.
enum RiyalSign {
    private enum Step {
        case move(CGFloat, CGFloat)
        case line(CGFloat, CGFloat)
        /// End point, then the two control points.
        case curve(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
        case close
    }

    private static let artSize = CGSize(width: 1124.14, height: 1256.39)
    static let aspect = artSize.width / artSize.height

    private static let steps: [Step] = [
        .move(699.62, 1113.02),
        .curve(661.22, 1256.39, 679.56, 1157.5, 666.3, 1205.77),
        .line(1085.73, 1166.15),
        .curve(1124.13, 1022.78, 1105.79, 1121.68, 1119.04, 1073.4),
        .line(699.62, 1113.02),
        .close,
        .move(1085.73, 895.8),
        .curve(1124.13, 752.43, 1105.79, 851.33, 1119.05, 803.05),
        .line(793.45, 822.76),
        .line(793.45, 687.56),
        .line(1085.72, 625.45),
        .curve(1124.12, 482.08, 1105.78, 580.98, 1119.04, 532.7),
        .line(793.44, 552.35),
        .line(793.44, 66.13),
        .curve(661.19, 177.12, 742.77, 94.58, 697.77, 132.45),
        .line(661.19, 580.47),
        .line(528.94, 608.58),
        .line(528.94, 0),
        .curve(396.69, 110.99, 478.27, 28.44, 433.27, 66.32),
        .line(396.69, 636.68),
        .line(100.78, 699.56),
        .curve(62.36, 842.93, 80.72, 744.03, 67.45, 792.31),
        .line(396.69, 771.88),
        .line(396.69, 942.14),
        .line(38.39, 1018.28),
        .curve(0, 1161.65, 18.33, 1062.75, 5.07, 1111.03),
        .line(375.03, 1081.95),
        .curve(448.86, 1032.71, 405.56, 1075.6, 431.8, 1057.55),
        .line(517.64, 930.72),
        .curve(528.94, 893.75, 524.78, 920.17, 528.94, 907.45),
        .line(528.94, 743.77),
        .line(661.19, 715.66),
        .line(661.19, 986.06),
        .line(1085.72, 895.78),
        .close,
    ]

    static func path(in rect: CGRect) -> Path {
        let sx = rect.width / artSize.width
        let sy = rect.height / artSize.height
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var path = Path()
        for step in steps {
            switch step {
            case let .move(x, y):
                path.move(to: point(x, y))
            case let .line(x, y):
                path.addLine(to: point(x, y))
            case let .curve(x, y, c1x, c1y, c2x, c2y):
                path.addCurve(to: point(x, y), control1: point(c1x, c1y), control2: point(c2x, c2y))
            case .close:
                path.closeSubpath()
            }
        }
        return path
    }

    private static var cache: [CGFloat: UIImage] = [:]

    /// A template image of the sign, so it takes the color of the text around it.
    static func image(height: CGFloat) -> Image {
        let key = (height * 2).rounded() / 2
        if let cached = cache[key] {
            return Image(uiImage: cached).renderingMode(.template)
        }
        let size = CGSize(width: (key * aspect).rounded(.up), height: key)
        let drawn = UIGraphicsImageRenderer(size: size).image { context in
            context.cgContext.addPath(path(in: CGRect(origin: .zero, size: size)).cgPath)
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fillPath()
        }
        .withRenderingMode(.alwaysTemplate)
        cache[key] = drawn
        return Image(uiImage: drawn).renderingMode(.template)
    }
}

/// The sign as a standalone view, sized like a capital letter of the text beside it.
struct RiyalShape: Shape {
    func path(in rect: CGRect) -> Path {
        let height = min(rect.height, rect.width / RiyalSign.aspect)
        let width = height * RiyalSign.aspect
        return RiyalSign.path(in: CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height))
    }
}

struct RiyalMark: View {
    var height: CGFloat
    var color: Color = Theme.secondary

    var body: some View {
        RiyalShape()
            .fill(color)
            .frame(width: height * RiyalSign.aspect, height: height)
            .accessibilityLabel("ريال")
    }
}

/// Text in which "¤" stands for the riyal sign, drawn at the right height for `size`.
func riyalText(_ string: String, size: CGFloat) -> Text {
    let parts = string.components(separatedBy: "¤")
    var text = Text(verbatim: parts[0])
    for part in parts.dropFirst() {
        text = text + Text(RiyalSign.image(height: (size * 0.68).rounded())) + Text(verbatim: part)
    }
    return text
}
