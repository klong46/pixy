import Foundation
import SwiftUI
import AppKit

public enum ToolType: String, CaseIterable, Identifiable {
    case draw = "Draw"
    case line = "Line"
    case fill = "Fill"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .draw: return "pencil"
        case .line: return "line.diagonal"
        case .fill: return "paintbucket"
        }
    }
}

public class CanvasModel: ObservableObject {
    @Published public var id: UUID
    @Published public var title: String
    @Published public var width: Int
    @Published public var height: Int
    // grid[y][x] where y is row (0..<height) and x is column (0..<width)
    // hex color string format e.g. "#RRGGBBAA" or "" for empty/transparent
    @Published public var grid: [[String]]
    @Published public var isModified: Bool = false
    
    @Published public var currentTool: ToolType = .draw
    
    // Undo / Redo history stacks
    private var history: [[[String]]] = []
    private var redoStack: [[[String]]] = []
    private let maxHistory: Int = 50
    
    public init(id: UUID = UUID(), title: String = "Untitled", width: Int = 32, height: Int = 32, grid: [[String]]? = nil) {
        let clampedW = min(max(width, 1), 200)
        let clampedH = min(max(height, 1), 200)
        
        self.id = id
        self.title = title
        self.width = clampedW
        self.height = clampedH
        
        if let grid = grid, grid.count == clampedH && grid.first?.count == clampedW {
            self.grid = grid
        } else {
            self.grid = Array(repeating: Array(repeating: "", count: clampedW), count: clampedH)
        }
    }
    
    public func recordStateForUndo() {
        history.append(grid)
        if history.count > maxHistory {
            history.removeFirst()
        }
        redoStack.removeAll()
        isModified = true
    }
    
    public var canUndo: Bool {
        !history.isEmpty
    }
    
    public var canRedo: Bool {
        !redoStack.isEmpty
    }
    
    public func undo() {
        guard let previousState = history.popLast() else { return }
        redoStack.append(grid)
        grid = previousState
        isModified = true
    }
    
    public func redo() {
        guard let nextState = redoStack.popLast() else { return }
        history.append(grid)
        grid = nextState
        isModified = true
    }
    
    public func resize(newWidth: Int, newHeight: Int) {
        let clampedW = min(max(newWidth, 1), 200)
        let clampedH = min(max(newHeight, 1), 200)
        
        recordStateForUndo()
        
        var newGrid = Array(repeating: Array(repeating: "", count: clampedW), count: clampedH)
        for y in 0..<min(height, clampedH) {
            for x in 0..<min(width, clampedW) {
                newGrid[y][x] = grid[y][x]
            }
        }
        
        self.width = clampedW
        self.height = clampedH
        self.grid = newGrid
    }
    
    // Set single pixel
    public func setPixel(x: Int, y: Int, colorHex: String) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        if grid[y][x] != colorHex {
            grid[y][x] = colorHex
            isModified = true
        }
    }
    
    // Draw line using Bresenham's algorithm
    public func drawLine(from p1: (x: Int, y: Int), to p2: (x: Int, y: Int), colorHex: String) {
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
            if x0 >= 0 && x0 < width && y0 >= 0 && y0 < height {
                grid[y0][x0] = colorHex
            }
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
        isModified = true
    }
    
    // Flood fill algorithm
    public func floodFill(startX: Int, startY: Int, colorHex: String) {
        guard startX >= 0, startX < width, startY >= 0, startY < height else { return }
        let targetColor = grid[startY][startX]
        if targetColor == colorHex { return }
        
        recordStateForUndo()
        
        var queue: [(x: Int, y: Int)] = [(startX, startY)]
        grid[startY][startX] = colorHex
        
        let directions = [(1,0), (-1,0), (0,1), (0,-1)]
        
        while !queue.isEmpty {
            let (cx, cy) = queue.removeFirst()
            
            for (dx, dy) in directions {
                let nx = cx + dx
                let ny = cy + dy
                
                if nx >= 0 && nx < width && ny >= 0 && ny < height {
                    if grid[ny][nx] == targetColor {
                        grid[ny][nx] = colorHex
                        queue.append((nx, ny))
                    }
                }
            }
        }
        isModified = true
    }
    
    public func reset(width: Int, height: Int, title: String) {
        let clampedW = min(max(width, 1), 200)
        let clampedH = min(max(height, 1), 200)
        
        self.id = UUID()
        self.title = title
        self.width = clampedW
        self.height = clampedH
        self.grid = Array(repeating: Array(repeating: "", count: clampedW), count: clampedH)
        self.history.removeAll()
        self.redoStack.removeAll()
        self.isModified = false
    }
}
