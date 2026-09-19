import SwiftUI

public struct OpenCanvasDialog: View {
    @Environment(\.dismiss) private var dismiss
    
    let onSelectCanvas: (SavedCanvasData) -> Void
    let onDeleteCanvas: (UUID) -> Void
    
    @State private var savedCanvases: [SavedCanvasData] = []
    @State private var selectedId: UUID? = nil
    
    @State private var canvasToDelete: SavedCanvasData? = nil
    @State private var isDeleteConfirmationPresented: Bool = false
    
    public init(
        onSelectCanvas: @escaping (SavedCanvasData) -> Void,
        onDeleteCanvas: @escaping (UUID) -> Void
    ) {
        self.onSelectCanvas = onSelectCanvas
        self.onDeleteCanvas = onDeleteCanvas
    }
    
    private func refreshList() {
        savedCanvases = StorageManager.shared.listSavedCanvases()
        if selectedId == nil || !savedCanvases.contains(where: { $0.id == selectedId }) {
            selectedId = savedCanvases.first?.id
        }
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            Text("Saved Canvases")
                .font(.headline)
            
            if savedCanvases.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No saved canvases found.")
                        .foregroundColor(.secondary)
                }
                .frame(height: 220)
            } else {
                List(selection: $selectedId) {
                    ForEach(savedCanvases) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .semibold))
                                HStack(spacing: 12) {
                                    Text("\(item.width) × \(item.height) px")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(item.updatedAt, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button(action: {
                                canvasToDelete = item
                                isDeleteConfirmationPresented = true
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                            .help("Delete canvas")
                        }
                        .padding(.vertical, 4)
                        .tag(item.id)
                    }
                }
                .listStyle(.inset)
                .frame(height: 220)
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Open") {
                    if let selectedId = selectedId,
                       let canvas = savedCanvases.first(where: { $0.id == selectedId }) {
                        onSelectCanvas(canvas)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedId == nil || savedCanvases.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 420)
        .onAppear {
            refreshList()
        }
        .alert("Delete Canvas", isPresented: $isDeleteConfirmationPresented, presenting: canvasToDelete) { item in
            Button("Delete", role: .destructive) {
                onDeleteCanvas(item.id)
                refreshList()
            }
            Button("Cancel", role: .cancel) {
                canvasToDelete = nil
            }
        } message: { item in
            Text("Are you sure you want to delete \"\(item.title)\"? This action cannot be undone.")
        }
    }
}
