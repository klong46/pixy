import Foundation
import AppKit

func generateIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    
    let ctx = NSGraphicsContext.current?.cgContext
    let s = CGFloat(size)
    
    // Background: Rounded rectangle with smooth gradient
    let iconRect = CGRect(x: 0, y: 0, width: s, height: s)
    let cornerRadius = s * 0.22
    let path = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)
    
    NSColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0).setFill()
    path.fill()
    
    // Pixel grid motif (4x4 large pixel grid inside icon)
    let gridPadding = s * 0.18
    let gridSize = s - (gridPadding * 2)
    let cellSize = gridSize / 4.0
    
    let colors: [[NSColor]] = [
        [.init(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0), .init(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0), .init(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0), .init(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)],
        [.init(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0), .init(red: 0.35, green: 0.34, blue: 0.84, alpha: 1.0), .init(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0), .init(red: 0.99, green: 0.17, blue: 0.33, alpha: 1.0)],
        [.init(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9), .init(red: 0.8, green: 0.8, blue: 0.8, alpha: 0.9), .init(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.9), .init(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)],
        [.init(red: 0.0, green: 0.75, blue: 0.95, alpha: 1.0), .init(red: 0.15, green: 0.85, blue: 0.6, alpha: 1.0), .init(red: 0.95, green: 0.35, blue: 0.6, alpha: 1.0), .init(red: 0.95, green: 0.7, blue: 0.2, alpha: 1.0)]
    ]
    
    for r in 0..<4 {
        for c in 0..<4 {
            let px = gridPadding + CGFloat(c) * cellSize
            let py = gridPadding + CGFloat(3 - r) * cellSize
            let pxRect = CGRect(x: px + 1, y: py + 1, width: cellSize - 2, height: cellSize - 2)
            
            let color = colors[r][c]
            color.setFill()
            let cellPath = NSBezierPath(roundedRect: pxRect, xRadius: max(1, s * 0.02), yRadius: max(1, s * 0.02))
            cellPath.fill()
        }
    }
    
    image.unlockFocus()
    return image
}

let fileManager = FileManager.default
let iconsetURL = URL(fileURLWithPath: "AppIcon.iconset")
try? fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, size) in sizes {
    let img = generateIcon(size: size)
    if let tiffData = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiffData),
       let pngData = rep.representation(using: .png, properties: [:]) {
        let dest = iconsetURL.appendingPathComponent(filename)
        try? pngData.write(to: dest)
    }
}
print("Iconset images generated!")
