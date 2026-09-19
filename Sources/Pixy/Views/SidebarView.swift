import SwiftUI
import AppKit

public struct SidebarView: View {
    @ObservedObject var canvas: CanvasModel
    @ObservedObject var palette: PaletteModel
    
    @State private var colorToEditIndex: Int? = nil
    @State private var editColorPicker: Color = .black
    @State private var isEditingColorPresented: Bool = false
    
    @State private var newColorPicker: Color = .red
    @State private var isAddColorPresented: Bool = false
    
    public init(
        canvas: CanvasModel,
        palette: PaletteModel
    ) {
        self.canvas = canvas
        self.palette = palette
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // App Header
            HStack(spacing: 8) {
                Image(systemName: "paintpalette.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Pixy")
                    .font(.title2.bold())
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            Divider()
            
            // 1. Tools Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Tools")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                VStack(spacing: 4) {
                    ForEach(ToolType.allCases) { tool in
                        let isSelected = canvas.currentTool == tool
                        let shortcutKey: String = {
                            switch tool {
                            case .draw: return "Q"
                            case .line: return "W"
                            case .fill: return "E"
                            }
                        }()
                        
                        Button(action: {
                            canvas.currentTool = tool
                        }) {
                            HStack {
                                Image(systemName: tool.iconName)
                                    .frame(width: 20)
                                Text(tool.rawValue)
                                Spacer()
                                Text(shortcutKey)
                                    .font(.caption2.bold())
                                    .foregroundColor(isSelected ? .accentColor : .secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.12))
                                    .cornerRadius(4)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                            .contentShape(Rectangle())
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(isSelected ? .accentColor : .primary)
                    }
                }
            }
            .padding(.horizontal, 12)
            
            Divider()
            
            // 2. Color Palette Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Color Palette")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(palette.userColorCount)/\(PaletteModel.maxUserColors)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Palette Grid (Index 0 is locked Clear tile + User colors + Add Color Square Button)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 8)], spacing: 8) {
                    ForEach(Array(palette.colors.enumerated()), id: \.element.id) { index, colorItem in
                        let isSelected = palette.selectedIndex == index
                        let isClearTile = index == 0
                        
                        ZStack {
                            if isClearTile {
                                // Clear / Erase tile with checkerboard & slash icon
                                MiniCheckerboardView()
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                Image(systemName: "eraser.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            } else {
                                let color = PaletteModel.hexToColor(colorItem.hex)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(color)
                                    .frame(width: 36, height: 36)
                                    .shadow(radius: 1)
                            }
                            
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 36, height: 36)
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color.primary, lineWidth: 1)
                                    .frame(width: 38, height: 38)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            palette.selectedIndex = index
                        }
                        .help(isClearTile ? "Clear / Erase (Transparent)" : "Color swatch")
                        .contextMenu {
                            if !isClearTile {
                                Button {
                                    colorToEditIndex = index
                                    editColorPicker = PaletteModel.hexToColor(colorItem.hex)
                                    isEditingColorPresented = true
                                } label: {
                                    Label("Change Color...", systemImage: "pencil.circle")
                                }
                                
                                Button(role: .destructive) {
                                    palette.removeColor(at: index)
                                } label: {
                                    Label("Delete Color", systemImage: "trash")
                                }
                            }
                        }
                    }
                    
                    // Add Color Button: Square shape (36x36) with + in center
                    if palette.canAddColor {
                        Button(action: {
                            isAddColorPresented = true
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Add new color to palette")
                    }
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
            
            // Bottom Info: Shortcuts helper
            VStack(alignment: .leading, spacing: 4) {
                Text("Tools: Q (Draw) | W (Line) | E (Fill)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Undo: ⌘Z  |  Redo: ⌘Y / ⌘⇧Z")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 200)
        .background(Color(NSColor.windowBackgroundColor))
        // Sheet for editing existing color
        .sheet(isPresented: $isEditingColorPresented, onDismiss: {
            NSColorPanel.shared.orderOut(nil)
        }) {
            VStack(spacing: 16) {
                Text("Change Color")
                    .font(.headline)
                
                ColorPicker("Select Color:", selection: $editColorPicker, supportsOpacity: true)
                    .labelsHidden()
                    .scaleEffect(1.2)
                    .padding()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismissColorPanel()
                        isEditingColorPresented = false
                    }
                    
                    Button("Save") {
                        if let index = colorToEditIndex {
                            let hex = PaletteModel.colorToHex(editColorPicker)
                            palette.updateColor(at: index, hex: hex)
                        }
                        dismissColorPanel()
                        isEditingColorPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 240, height: 160)
        }
        // Sheet for adding new color
        .sheet(isPresented: $isAddColorPresented, onDismiss: {
            NSColorPanel.shared.orderOut(nil)
        }) {
            VStack(spacing: 16) {
                Text("Add Palette Color")
                    .font(.headline)
                
                ColorPicker("Choose Color:", selection: $newColorPicker, supportsOpacity: true)
                    .labelsHidden()
                    .scaleEffect(1.2)
                    .padding()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismissColorPanel()
                        isAddColorPresented = false
                    }
                    
                    Button("Add to Palette") {
                        let hex = PaletteModel.colorToHex(newColorPicker)
                        palette.addColor(hex: hex)
                        dismissColorPanel()
                        isAddColorPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 240, height: 160)
        }
    }
    
    private func dismissColorPanel() {
        NSColorPanel.shared.orderOut(nil)
        NSColorPanel.shared.close()
    }
}

// Mini checkerboard pattern for Clear palette tile
struct MiniCheckerboardView: View {
    var body: some View {
        Canvas { context, size in
            let checkSize: CGFloat = 6.0
            let cols = Int(ceil(size.width / checkSize))
            let rows = Int(ceil(size.height / checkSize))
            
            for r in 0..<rows {
                for c in 0..<cols {
                    let isEven = (r + c) % 2 == 0
                    let color: Color = isEven ? Color(white: 0.82) : Color(white: 0.95)
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
    }
}
