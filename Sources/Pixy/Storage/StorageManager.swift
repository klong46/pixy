import Foundation
import SwiftUI
import AppKit

public struct SavedCanvasData: Codable, Identifiable {
    public var id: UUID
    public var title: String
    public var width: Int
    public var height: Int
    public var grid: [[String]]
    public var palette: [String]
    public var updatedAt: Date
    
    public init(id: UUID, title: String, width: Int, height: Int, grid: [[String]], palette: [String], updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.width = width
        self.height = height
        self.grid = grid
        self.palette = palette
        self.updatedAt = updatedAt
    }
}

public struct JSONExportFormat: Codable {
    public var width: Int
    public var height: Int
    public var palette: [String: String] // maps number index (e.g. "0", "1") to hex string
    public var grid: [[Int]]            // 2D matrix mapping each cell to a palette number index
}

public class StorageManager {
    public static let shared = StorageManager()
    
    private let appSupportURL: URL
    private let canvasesURL: URL
    private let lastSessionURL: URL
    
    private init() {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let baseDir = urls[0].appendingPathComponent("Pixy", isDirectory: true)
        self.appSupportURL = baseDir
        self.canvasesURL = baseDir.appendingPathComponent("Canvases", isDirectory: true)
        self.lastSessionURL = baseDir.appendingPathComponent("last_session.json")
        
        try? fileManager.createDirectory(at: canvasesURL, withIntermediateDirectories: true)
    }
    
    // MARK: - Canvas Persistence (In-App Save/Open)
    
    public func saveCanvas(canvas: CanvasModel, palette: PaletteModel) throws {
        let data = SavedCanvasData(
            id: canvas.id,
            title: canvas.title,
            width: canvas.width,
            height: canvas.height,
            grid: canvas.grid,
            palette: palette.colors.map { $0.hex },
            updatedAt: Date()
        )
        
        let fileURL = canvasesURL.appendingPathComponent("\(canvas.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let encoded = try encoder.encode(data)
        try encoded.write(to: fileURL)
        
        canvas.isModified = false
        saveLastSession(canvas: canvas, palette: palette)
    }
    
    public func listSavedCanvases() -> [SavedCanvasData] {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: canvasesURL, includingPropertiesForKeys: nil) else {
            return []
        }
        
        var results: [SavedCanvasData] = []
        let decoder = JSONDecoder()
        
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let canvasData = try? decoder.decode(SavedCanvasData.self, from: data) {
                results.append(canvasData)
            }
        }
        
        return results.sorted(by: { $0.updatedAt > $1.updatedAt })
    }
    
    public func deleteSavedCanvas(id: UUID) {
        let fileURL = canvasesURL.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    // MARK: - Last Session (Auto-Save on Quit)
    
    public func saveLastSession(canvas: CanvasModel, palette: PaletteModel) {
        let data = SavedCanvasData(
            id: canvas.id,
            title: canvas.title,
            width: canvas.width,
            height: canvas.height,
            grid: canvas.grid,
            palette: palette.colors.map { $0.hex },
            updatedAt: Date()
        )
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(data) {
            try? encoded.write(to: lastSessionURL)
        }
    }
    
    public func loadLastSession() -> SavedCanvasData? {
        guard FileManager.default.fileExists(atPath: lastSessionURL.path) else { return nil }
        let decoder = JSONDecoder()
        if let data = try? Data(contentsOf: lastSessionURL),
           let canvasData = try? decoder.decode(SavedCanvasData.self, from: data) {
            return canvasData
        }
        return nil
    }
    
    // MARK: - Exporting (PNG, JPG, JSON)
    
    public func exportJSON(canvas: CanvasModel) -> Data? {
        // Collect all distinct hex colors present in grid plus palette order
        var colorMap: [String: Int] = [:]
        var paletteDict: [String: String] = [:]
        
        // Number 0 is transparent/empty
        paletteDict["0"] = "#00000000"
        colorMap[""] = 0
        
        var nextIndex = 1
        
        for row in canvas.grid {
            for hex in row {
                if !hex.isEmpty && colorMap[hex] == nil {
                    colorMap[hex] = nextIndex
                    paletteDict["\(nextIndex)"] = hex
                    nextIndex += 1
                }
            }
        }
        
        var gridMatrix: [[Int]] = []
        for row in canvas.grid {
            let rowIndices = row.map { colorMap[$0] ?? 0 }
            gridMatrix.append(rowIndices)
        }
        
        let jsonObject = JSONExportFormat(
            width: canvas.width,
            height: canvas.height,
            palette: paletteDict,
            grid: gridMatrix
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(jsonObject)
    }
    
    public func renderNSImage(canvas: CanvasModel, scale: Int = 16, isOpaque: Bool = false) -> NSImage? {
        let imgWidth = canvas.width * scale
        let imgHeight = canvas.height * scale
        let size = NSSize(width: imgWidth, height: imgHeight)
        
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: imgWidth,
            pixelsHigh: imgHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.current = context
        
        let cgContext = context?.cgContext
        
        if isOpaque {
            cgContext?.setFillColor(NSColor.white.cgColor)
            cgContext?.fill(CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight))
        } else {
            cgContext?.clear(CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight))
        }
        
        for y in 0..<canvas.height {
            for x in 0..<canvas.width {
                let hex = canvas.grid[y][x]
                if !hex.isEmpty {
                    let nsColor = NSColor(PaletteModel.hexToColor(hex))
                    cgContext?.setFillColor(nsColor.cgColor)
                    // CoreGraphics Y-origin is bottom-left, canvas.grid[0] is top row
                    let flippedY = (canvas.height - 1 - y) * scale
                    cgContext?.fill(CGRect(x: x * scale, y: flippedY, width: scale, height: scale))
                }
            }
        }
        
        NSGraphicsContext.restoreGraphicsState()
        
        let image = NSImage(size: size)
        image.addRepresentation(bitmapRep)
        return image
    }
    
    public func exportPNG(canvas: CanvasModel) -> Data? {
        guard let image = renderNSImage(canvas: canvas, scale: 16, isOpaque: false),
              let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmapRep.representation(using: .png, properties: [:])
    }
    
    public func exportJPG(canvas: CanvasModel) -> Data? {
        guard let image = renderNSImage(canvas: canvas, scale: 16, isOpaque: true),
              let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
    }
}
