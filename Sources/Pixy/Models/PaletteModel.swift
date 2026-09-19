import Foundation
import SwiftUI

public struct PaletteColor: Identifiable, Equatable, Codable {
    public var id = UUID()
    public var hex: String
    
    public init(id: UUID = UUID(), hex: String) {
        self.id = id
        self.hex = hex
    }
}

public class PaletteModel: ObservableObject {
    @Published public var colors: [PaletteColor] = []
    @Published public var selectedIndex: Int = 0
    
    public static let maxColors = 10
    
    public init(initialColors: [String]? = nil) {
        if let initial = initialColors, !initial.isEmpty {
            self.colors = initial.prefix(Self.maxColors).map { PaletteColor(hex: $0) }
        } else {
            // Default starter palette (8 classic pixel art colors)
            let defaults = [
                "#000000FF", // Black
                "#FFFFFFFF", // White
                "#FF3B30FF", // Red
                "#34C759FF", // Green
                "#007AFFFF", // Blue
                "#FFCC00FF", // Yellow
                "#FF9500FF", // Orange
                "#AF52DEFF"  // Purple
            ]
            self.colors = defaults.map { PaletteColor(hex: $0) }
        }
        if selectedIndex >= colors.count {
            selectedIndex = 0
        }
    }
    
    public var selectedHex: String {
        guard selectedIndex >= 0 && selectedIndex < colors.count else {
            return "#000000FF"
        }
        return colors[selectedIndex].hex
    }
    
    public var canAddColor: Bool {
        colors.count < Self.maxColors
    }
    
    public func addColor(hex: String) {
        guard canAddColor else { return }
        colors.append(PaletteColor(hex: hex))
        selectedIndex = colors.count - 1
    }
    
    public func updateColor(at index: Int, hex: String) {
        guard index >= 0 && index < colors.count else { return }
        colors[index].hex = hex
    }
    
    public func removeColor(at index: Int) {
        guard index >= 0 && index < colors.count else { return }
        colors.remove(at: index)
        if selectedIndex >= colors.count {
            selectedIndex = max(0, colors.count - 1)
        }
    }
    
    // Hex Color Helper utilities
    public static func colorToHex(_ color: Color) -> String {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        let r = Int(round(nsColor.redComponent * 255))
        let g = Int(round(nsColor.greenComponent * 255))
        let b = Int(round(nsColor.blueComponent * 255))
        let a = Int(round(nsColor.alphaComponent * 255))
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }
    
    public static func hexToColor(_ hex: String) -> Color {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgbValue)
        
        var r: Double = 0
        var g: Double = 0
        var b: Double = 0
        var a: Double = 1.0
        
        if cleanHex.count == 6 {
            r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
            g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
            b = Double(rgbValue & 0x0000FF) / 255.0
        } else if cleanHex.count == 8 {
            r = Double((rgbValue & 0xFF000000) >> 24) / 255.0
            g = Double((rgbValue & 0x00FF0000) >> 16) / 255.0
            b = Double((rgbValue & 0x0000FF00) >> 8) / 255.0
            a = Double(rgbValue & 0x000000FF) / 255.0
        }
        
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
