import SwiftUI
import AppKit

public struct CanvasView: View {
    @ObservedObject var canvas: CanvasModel
    @ObservedObject var palette: PaletteModel
    
    @State private var dragStartPoint: (x: Int, y: Int)? = nil
    @State private var dragCurrentPoint: (x: Int, y: Int)? = nil
    @State private var lastDrawnPoint: (x: Int, y: Int)? = nil
    @State private var zoomScale: CGFloat = 1.0
    @State private var pinchBaseScale: CGFloat = 1.0
    
    public init(canvas: CanvasModel, palette: PaletteModel) {
        self.canvas = canvas
        self.palette = palette
    }
    
    // Calculates base cell size for display based on canvas size
    private var baseCellSize: CGFloat {
        let maxDimension = max(canvas.width, canvas.height)
        if maxDimension <= 16 { return 32 }
        if maxDimension <= 32 { return 20 }
        if maxDimension <= 64 { return 12 }
        if maxDimension <= 100 { return 8 }
        return 5
    }
    
    private var cellSize: CGFloat {
        baseCellSize * zoomScale
    }
    
    private var canvasPixelWidth: CGFloat {
        CGFloat(canvas.width) * cellSize
    }
    
    private var canvasPixelHeight: CGFloat {
        CGFloat(canvas.height) * cellSize
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Canvas Toolbar for Zoom
            HStack {
                Text("\(canvas.width) × \(canvas.height) px")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Button(action: { zoomScale = max(0.25, zoomScale - 0.25) }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(Int(zoomScale * 100))%")
                        .font(.caption)
                        .frame(width: 45)
                    
                    Button(action: { zoomScale = min(5.0, zoomScale + 0.25) }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    
                    Button("Reset Zoom") {
                        zoomScale = 1.0
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Canvas View Area with trackpad pinch gesture
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack {
                    // Transparent checkerboard background
                    CheckerboardView(width: canvas.width, height: canvas.height, cellSize: cellSize)
                    
                    // SwiftUI Canvas for rendering cells & line preview
                    Canvas { context, size in
                        let activeColor = PaletteModel.hexToColor(palette.selectedHex)
                        
                        // 1. Draw base cells
                        for y in 0..<canvas.height {
                            for x in 0..<canvas.width {
                                let hex = canvas.grid[y][x]
                                if !hex.isEmpty {
                                    let color = PaletteModel.hexToColor(hex)
                                    let rect = CGRect(
                                        x: CGFloat(x) * cellSize,
                                        y: CGFloat(y) * cellSize,
                                        width: cellSize,
                                        height: cellSize
                                    )
                                    context.fill(Path(rect), with: .color(color))
                                }
                            }
                        }
                        
                        // 2. Draw Line preview if drawing line
                        if canvas.currentTool == .line,
                           let start = dragStartPoint,
                           let current = dragCurrentPoint {
                            let previewLinePoints = bresenhamPoints(from: start, to: current)
                            for pt in previewLinePoints {
                                if pt.x >= 0 && pt.x < canvas.width && pt.y >= 0 && pt.y < canvas.height {
                                    let rect = CGRect(
                                        x: CGFloat(pt.x) * cellSize,
                                        y: CGFloat(pt.y) * cellSize,
                                        width: cellSize,
                                        height: cellSize
                                    )
                                    context.fill(Path(rect), with: .color(activeColor.opacity(0.8)))
                                }
                            }
                        }
                    }
                    .frame(width: canvasPixelWidth, height: canvasPixelHeight)
                }
                .frame(width: canvasPixelWidth, height: canvasPixelHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleGestureChanged(location: value.location)
                        }
                        .onEnded { value in
                            handleGestureEnded(location: value.location)
                        }
                )
                // Trackpad pinch-to-zoom gesture
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = pinchBaseScale * value
                            zoomScale = min(max(0.25, newScale), 5.0)
                        }
                        .onEnded { value in
                            pinchBaseScale = zoomScale
                        }
                )
                .padding(40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    private func getCellCoordinates(from location: CGPoint) -> (x: Int, y: Int)? {
        let x = Int(floor(location.x / cellSize))
        let y = Int(floor(location.y / cellSize))
        guard x >= 0, x < canvas.width, y >= 0, y < canvas.height else { return nil }
        return (x, y)
    }
    
    private func handleGestureChanged(location: CGPoint) {
        guard let pt = getCellCoordinates(from: location) else { return }
        
        switch canvas.currentTool {
        case .draw:
            if dragStartPoint == nil {
                dragStartPoint = pt
                canvas.recordStateForUndo()
                canvas.setPixel(x: pt.x, y: pt.y, colorHex: palette.selectedHex)
                lastDrawnPoint = pt
            } else if lastDrawnPoint?.x != pt.x || lastDrawnPoint?.y != pt.y {
                if let last = lastDrawnPoint {
                    let pts = bresenhamPoints(from: last, to: pt)
                    for point in pts {
                        canvas.setPixel(x: point.x, y: point.y, colorHex: palette.selectedHex)
                    }
                } else {
                    canvas.setPixel(x: pt.x, y: pt.y, colorHex: palette.selectedHex)
                }
                lastDrawnPoint = pt
            }
            
        case .line:
            if dragStartPoint == nil {
                dragStartPoint = pt
            }
            dragCurrentPoint = pt
            
        case .fill:
            break
        }
    }
    
    private func handleGestureEnded(location: CGPoint) {
        let pt = getCellCoordinates(from: location) ?? dragCurrentPoint ?? dragStartPoint
        
        switch canvas.currentTool {
        case .draw:
            dragStartPoint = nil
            dragCurrentPoint = nil
            lastDrawnPoint = nil
            
        case .line:
            if let start = dragStartPoint, let end = pt {
                canvas.recordStateForUndo()
                canvas.drawLine(from: start, to: end, colorHex: palette.selectedHex)
            }
            dragStartPoint = nil
            dragCurrentPoint = nil
            
        case .fill:
            if let target = pt {
                canvas.floodFill(startX: target.x, startY: target.y, colorHex: palette.selectedHex)
            }
            dragStartPoint = nil
            dragCurrentPoint = nil
        }
    }
    
    private func bresenhamPoints(from p1: (x: Int, y: Int), to p2: (x: Int, y: Int)) -> [(x: Int, y: Int)] {
        var points: [(x: Int, y: Int)] = []
        var x0 = p1.x
        var y0 = p1.y
        let x1 = p2.x
        let y1 = p2.y
        
        let dx = abs(x1 - x0)
        let dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        
        while true {
            points.append((x0, y0))
            if x0 == x1 && y0 == y1 { break }
            let e2 = 2 * err
            if e2 >= dy {
                err += dy
                x0 += sx
            }
            if e2 <= dx {
                err += dx
                y0 += sy
            }
        }
        return points
    }
}

// Background checkerboard pattern to indicate transparent pixels
struct CheckerboardView: View {
    let width: Int
    let height: Int
    let cellSize: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let checkSize = max(cellSize, 4)
            let cols = Int(ceil(size.width / checkSize))
            let rows = Int(ceil(size.height / checkSize))
            
            for r in 0..<rows {
                for c in 0..<cols {
                    let isEven = (r + c) % 2 == 0
                    let color: Color = isEven ? Color(white: 0.9) : Color(white: 0.98)
                    let rect = CGRect(
                        x: CGFloat(c) * checkSize,
                        y: CGFloat(r) * checkSize,
                        width: checkSize,
                        height: checkSize
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: CGFloat(width) * cellSize, height: CGFloat(height) * cellSize)
    }
}
