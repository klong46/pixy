import SwiftUI
import AppKit

public struct SidebarView: View {
    @ObservedObject var canvas: CanvasModel
    @ObservedObject var palette: PaletteModel
    
    let onNewCanvas: () -> Void
    let onOpenCanvas: () -> Void
    let onSaveCanvas: () -> Void
    let onExportCanvas: (ExportFormat) -> Void
    
    public enum ExportFormat: String, CaseIterable, Identifiable {
        case png = "PNG Image (.png)"
        case jpg = "JPG Image (.jpg)"
        case json = "JSON File (.json)"
        
        public var id: String { rawValue }
    }
    
    @State private var colorToEditIndex: Int? = nil
    @State private var newColorPicker: Color = .black
    @State private var editColorPicker: Color = .black
    @State private var isEditingColorPresented: Bool = false
    
    public init(
        canvas: CanvasModel,
        palette: PaletteModel,
        onNewCanvas: @escaping () -> Void,
        onOpenCanvas: @escaping () -> Void,
        onSaveCanvas: @escaping () -> Void,
        onExportCanvas: @escaping (ExportFormat) -> Void
    ) {
        self.canvas = canvas
        self.palette = palette
        self.onNewCanvas = onNewCanvas
        self.onOpenCanvas = onOpenCanvas
        self.onSaveCanvas = onSaveCanvas
        self.onExportCanvas = onExportCanvas
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // App Title & Header
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
            
            // 1. App Settings Section (Top of UI Panel)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("App Settings")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    if canvas.isModified {
                        Text("Unsaved")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                VStack(spacing: 6) {
                    Button(action: onSaveCanvas) {
                        Label("Save Canvas", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: onOpenCanvas) {
                        Label("Open Canvas...", systemImage: "folder")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    
                    Menu {
                        Button("PNG Image (.png)") { onExportCanvas(.png) }
                        Button("JPG Image (.jpg)") { onExportCanvas(.jpg) }
                        Button("JSON Data (.json)") { onExportCanvas(.json) }
                    } label: {
                        Label("Export Canvas", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .menuStyle(.borderedButton)
                    
                    Button(action: onNewCanvas) {
                        Label("New Canvas...", systemImage: "plus.app")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 12)
            
            Divider()
            
            // 2. Tools Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Tools")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                VStack(spacing: 4) {
                    ForEach(ToolType.allCases) { tool in
                        Button(action: {
                            canvas.currentTool = tool
                        }) {
                            HStack {
                                Image(systemName: tool.iconName)
                                    .frame(width: 20)
                                Text(tool.rawValue)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(canvas.currentTool == tool ? Color.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(canvas.currentTool == tool ? .accentColor : .primary)
                    }
                }
            }
            .padding(.horizontal, 12)
            
            Divider()
            
            // 3. Color Palette Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Color Palette")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(palette.colors.count)/\(PaletteModel.maxColors)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Palette Grid (Up to 10 colors)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 8)], spacing: 8) {
                    ForEach(Array(palette.colors.enumerated()), id: \.element.id) { index, colorItem in
                        let color = PaletteModel.hexToColor(colorItem.hex)
                        let isSelected = palette.selectedIndex == index
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(color)
                                .frame(width: 36, height: 36)
                                .shadow(radius: 1)
                            
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
                        .contextMenu {
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
                
                // Add Color Section
                if palette.canAddColor {
                    HStack {
                        ColorPicker("", selection: $newColorPicker, supportsOpacity: true)
                            .labelsHidden()
                            .frame(width: 28, height: 28)
                        
                        Button(action: {
                            let hex = PaletteModel.colorToHex(newColorPicker)
                            palette.addColor(hex: hex)
                        }) {
                            Label("Add Color", systemImage: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
            
            // Bottom Info: Keyboard Shortcuts helper
            VStack(alignment: .leading, spacing: 2) {
                Text("Undo: ⌘Z  |  Redo: ⌘Y / ⌘⇧Z")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 220)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $isEditingColorPresented) {
            VStack(spacing: 16) {
                Text("Change Color")
                    .font(.headline)
                
                ColorPicker("Select Color:", selection: $editColorPicker, supportsOpacity: true)
                    .labelsHidden()
                    .scaleEffect(1.2)
                    .padding()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isEditingColorPresented = false
                    }
                    
                    Button("Save") {
                        if let index = colorToEditIndex {
                            let hex = PaletteModel.colorToHex(editColorPicker)
                            palette.updateColor(at: index, hex: hex)
                        }
                        isEditingColorPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 240, height: 160)
        }
    }
}
