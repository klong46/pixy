import SwiftUI
import AppKit

public enum ExportFormat: String, CaseIterable, Identifiable {
    case png = "PNG Image (.png)"
    case jpg = "JPG Image (.jpg)"
    case json = "JSON Data (.json)"
    
    public var id: String { rawValue }
}

public struct MainView: View {
    @StateObject private var canvas = CanvasModel()
    @StateObject private var palette = PaletteModel()
    
    @State private var isNewCanvasSheetPresented = false
    @State private var isOpenCanvasSheetPresented = false
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 0) {
            // Left UI Panel (Tools & Palette)
            SidebarView(
                canvas: canvas,
                palette: palette
            )
            
            Divider()
            
            // Central Canvas Area
            CanvasView(
                canvas: canvas,
                palette: palette,
                onEditEnded: {
                    autoSaveCurrentState()
                }
            )
        }
        .frame(minWidth: 850, minHeight: 600)
        .toolbar {
            // Left Canvas Settings Actions (New, Open, Export) - Save is automated
            ToolbarItemGroup(placement: .navigation) {
                Button(action: {
                    isNewCanvasSheetPresented = true
                }) {
                    Label("New", systemImage: "plus.app")
                }
                .labelStyle(.titleAndIcon)
                .help("Create a new canvas")
                
                Button(action: {
                    isOpenCanvasSheetPresented = true
                }) {
                    Label("Open", systemImage: "folder")
                }
                .labelStyle(.titleAndIcon)
                .help("Open a saved canvas")
                
                Menu {
                    Button("PNG Image (.png)") { performExportCanvas(format: .png) }
                    Button("JPG Image (.jpg)") { performExportCanvas(format: .jpg) }
                    Button("JSON Data (.json)") { performExportCanvas(format: .json) }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .labelStyle(.titleAndIcon)
                .help("Export canvas as PNG, JPG, or JSON")
            }
            
            // Title in the Center of the Mac Window Toolbar
            ToolbarItem(placement: .principal) {
                Text(canvas.title)
                    .font(.headline)
            }
        }
        .onAppear {
            restoreLastSessionOrDefaults()
        }
        // Auto-save whenever palette changes
        .onChange(of: palette.colors) { _ in
            autoSaveCurrentState()
        }
        // Keyboard shortcuts for Undo, Redo, and Tool hotkeys (Q, W, E)
        .background(
            KeyShortcutHandlerView(
                onUndo: {
                    canvas.undo()
                    autoSaveCurrentState()
                },
                onRedo: {
                    canvas.redo()
                    autoSaveCurrentState()
                },
                onSelectTool: { tool in canvas.currentTool = tool }
            )
        )
        // Dialog sheets
        .sheet(isPresented: $isNewCanvasSheetPresented) {
            NewCanvasDialog(
                canvasWidth: .constant(32),
                canvasHeight: .constant(32),
                canvasTitle: .constant("Untitled"),
                onConfirm: { title, width, height in
                    canvas.reset(width: width, height: height, title: title)
                    autoSaveCurrentState()
                }
            )
        }
        .sheet(isPresented: $isOpenCanvasSheetPresented) {
            OpenCanvasDialog(
                onSelectCanvas: { savedCanvas in
                    canvas.reset(width: savedCanvas.width, height: savedCanvas.height, title: savedCanvas.title)
                    canvas.id = savedCanvas.id
                    canvas.grid = savedCanvas.grid
                    palette.setColorsFromHexStrings(savedCanvas.palette)
                    autoSaveCurrentState()
                },
                onDeleteCanvas: { id in
                    StorageManager.shared.deleteSavedCanvas(id: id)
                }
            )
        }
    }
    
    // MARK: - Auto-Save & Actions
    
    private func autoSaveCurrentState() {
        try? StorageManager.shared.saveCanvas(canvas: canvas, palette: palette)
    }
    
    private func restoreLastSessionOrDefaults() {
        if let session = StorageManager.shared.loadLastSession() {
            canvas.reset(width: session.width, height: session.height, title: session.title)
            canvas.id = session.id
            canvas.grid = session.grid
            palette.setColorsFromHexStrings(session.palette)
        }
    }
    
    private func performExportCanvas(format: ExportFormat) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "\(canvas.title.lowercased().replacingOccurrences(of: " ", with: "_"))"
        
        switch format {
        case .png:
            savePanel.allowedContentTypes = [.png]
        case .jpg:
            savePanel.allowedContentTypes = [.jpeg]
        case .json:
            savePanel.allowedContentTypes = [.json]
        }
        
        savePanel.begin { result in
            guard result == .OK, let targetURL = savePanel.url else { return }
            
            var exportData: Data? = nil
            switch format {
            case .png:
                exportData = StorageManager.shared.exportPNG(canvas: canvas)
            case .jpg:
                exportData = StorageManager.shared.exportJPG(canvas: canvas)
            case .json:
                exportData = StorageManager.shared.exportJSON(canvas: canvas)
            }
            
            if let data = exportData {
                try? data.write(to: targetURL)
            }
        }
    }
}

// Invisible NSView subclass to capture ⌘Z (Undo), ⌘Y / ⌘⇧Z (Redo), and tool hotkeys Q (Draw), W (Line), E (Fill)
struct KeyShortcutHandlerView: NSViewRepresentable {
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onSelectTool: (ToolType) -> Void
    
    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.onUndo = onUndo
        view.onRedo = onRedo
        view.onSelectTool = onSelectTool
        return view
    }
    
    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.onUndo = onUndo
        nsView.onRedo = onRedo
        nsView.onSelectTool = onSelectTool
    }
    
    class KeyView: NSView {
        var onUndo: (() -> Void)?
        var onRedo: (() -> Void)?
        var onSelectTool: ((ToolType) -> Void)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }
        
        override func keyDown(with event: NSEvent) {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let characters = event.charactersIgnoringModifiers?.lowercased() ?? ""
            
            if flags.contains(.command) {
                if characters == "z" {
                    if flags.contains(.shift) {
                        onRedo?()
                    } else {
                        onUndo?()
                    }
                    return
                } else if characters == "y" {
                    onRedo?()
                    return
                }
            } else if flags.isEmpty || flags == .capsLock {
                // Hotkeys without modifier key: Q, W, E
                switch characters {
                case "q":
                    onSelectTool?(.draw)
                    return
                case "w":
                    onSelectTool?(.line)
                    return
                case "e":
                    onSelectTool?(.fill)
                    return
                default:
                    break
                }
            }
            super.keyDown(with: event)
        }
    }
}
