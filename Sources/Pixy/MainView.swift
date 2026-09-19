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
    @State private var isUnsavedPromptPresented = false
    @State private var pendingAction: PendingAction? = nil
    
    @State private var savedCanvasesList: [SavedCanvasData] = []
    
    private enum PendingAction {
        case createNew(title: String, width: Int, height: Int)
        case loadSaved(SavedCanvasData)
    }
    
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
            CanvasView(canvas: canvas, palette: palette)
        }
        .frame(minWidth: 850, minHeight: 600)
        .toolbar {
            // 1. Left Canvas Settings Actions (New, Open, Save, Export) with labels displayed always
            ToolbarItemGroup(placement: .navigation) {
                Button(action: {
                    checkUnsavedAndProceed(action: .createNew(title: "Untitled", width: 32, height: 32))
                }) {
                    Label("New", systemImage: "plus.app")
                }
                .labelStyle(.titleAndIcon)
                .help("Create a new canvas")
                
                Button(action: {
                    savedCanvasesList = StorageManager.shared.listSavedCanvases()
                    isOpenCanvasSheetPresented = true
                }) {
                    Label("Open", systemImage: "folder")
                }
                .labelStyle(.titleAndIcon)
                .help("Open a saved canvas")
                
                Button(action: performSaveCanvas) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .labelStyle(.titleAndIcon)
                .help("Save canvas in app")
                
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
            
            // 2. Title & Unsaved Status Badge in the Center of the Mac Window Toolbar
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text(canvas.title)
                        .font(.headline)
                    if canvas.isModified {
                        Text("• Unsaved")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .onAppear {
            restoreLastSessionOrDefaults()
        }
        // Keyboard shortcuts for Undo, Redo, and Tool hotkeys (Q, W, E)
        .background(
            KeyShortcutHandlerView(
                onUndo: { canvas.undo() },
                onRedo: { canvas.redo() },
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
                    StorageManager.shared.saveLastSession(canvas: canvas, palette: palette)
                }
            )
        }
        .sheet(isPresented: $isOpenCanvasSheetPresented) {
            OpenCanvasDialog(
                savedCanvases: savedCanvasesList,
                onSelectCanvas: { savedCanvas in
                    checkUnsavedAndProceed(action: .loadSaved(savedCanvas))
                },
                onDeleteCanvas: { id in
                    StorageManager.shared.deleteSavedCanvas(id: id)
                    savedCanvasesList = StorageManager.shared.listSavedCanvases()
                }
            )
        }
        // Unsaved changes alert modal
        .alert("Unsaved Changes", isPresented: $isUnsavedPromptPresented) {
            Button("Save and Continue") {
                performSaveCanvas()
                executePendingAction()
            }
            Button("Don't Save", role: .destructive) {
                executePendingAction()
            }
            Button("Cancel", role: .cancel) {
                pendingAction = nil
            }
        } message: {
            Text("Do you want to save the changes to \"\(canvas.title)\" before switching?")
        }
    }
    
    // MARK: - Actions & Guards
    
    private func restoreLastSessionOrDefaults() {
        if let session = StorageManager.shared.loadLastSession() {
            canvas.reset(width: session.width, height: session.height, title: session.title)
            canvas.id = session.id
            canvas.grid = session.grid
            if !session.palette.isEmpty {
                palette.colors = session.palette.map { PaletteColor(hex: $0) }
            }
            canvas.isModified = false
        }
    }
    
    private func checkUnsavedAndProceed(action: PendingAction) {
        if canvas.isModified {
            pendingAction = action
            isUnsavedPromptPresented = true
        } else {
            pendingAction = action
            executePendingAction()
        }
    }
    
    private func executePendingAction() {
        guard let action = pendingAction else { return }
        switch action {
        case .createNew:
            isNewCanvasSheetPresented = true
        case .loadSaved(let data):
            canvas.reset(width: data.width, height: data.height, title: data.title)
            canvas.id = data.id
            canvas.grid = data.grid
            if !data.palette.isEmpty {
                palette.colors = data.palette.map { PaletteColor(hex: $0) }
            }
            canvas.isModified = false
            StorageManager.shared.saveLastSession(canvas: canvas, palette: palette)
        }
        pendingAction = nil
    }
    
    private func performSaveCanvas() {
        do {
            try StorageManager.shared.saveCanvas(canvas: canvas, palette: palette)
        } catch {
            print("Failed to save canvas: \(error)")
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
