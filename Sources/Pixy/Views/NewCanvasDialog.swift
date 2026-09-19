import SwiftUI

public struct NewCanvasDialog: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var canvasWidth: Int
    @Binding var canvasHeight: Int
    @Binding var canvasTitle: String
    
    let onConfirm: (String, Int, Int) -> Void
    
    @State private var inputWidth: String = "32"
    @State private var inputHeight: String = "32"
    @State private var inputTitle: String = "Untitled"
    @State private var errorMessage: String? = nil
    
    public init(canvasWidth: Binding<Int>, canvasHeight: Binding<Int>, canvasTitle: Binding<String>, onConfirm: @escaping (String, Int, Int) -> Void) {
        self._canvasWidth = canvasWidth
        self._canvasHeight = canvasHeight
        self._canvasTitle = canvasTitle
        self.onConfirm = onConfirm
        self._inputWidth = State(initialValue: "\(canvasWidth.wrappedValue)")
        self._inputHeight = State(initialValue: "\(canvasHeight.wrappedValue)")
        self._inputTitle = State(initialValue: canvasTitle.wrappedValue)
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Create New Canvas")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Title:")
                        .frame(width: 60, alignment: .trailing)
                    TextField("Title", text: $inputTitle)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("Width:")
                        .frame(width: 60, alignment: .trailing)
                    TextField("Width (1-200)", text: $inputWidth)
                        .textFieldStyle(.roundedBorder)
                    Text("px")
                }
                
                HStack {
                    Text("Height:")
                        .frame(width: 60, alignment: .trailing)
                    TextField("Height (1-200)", text: $inputHeight)
                        .textFieldStyle(.roundedBorder)
                    Text("px")
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                HStack(spacing: 12) {
                    Text("Presets:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("16x16") { setPreset(16, 16) }
                        .buttonStyle(.borderedProminent)
                        .tint(.secondary.opacity(0.3))
                    Button("32x32") { setPreset(32, 32) }
                        .buttonStyle(.borderedProminent)
                        .tint(.secondary.opacity(0.3))
                    Button("64x64") { setPreset(64, 64) }
                        .buttonStyle(.borderedProminent)
                        .tint(.secondary.opacity(0.3))
                    Button("128x128") { setPreset(128, 128) }
                        .buttonStyle(.borderedProminent)
                        .tint(.secondary.opacity(0.3))
                }
            }
            .padding(.horizontal)
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Create") {
                    validateAndCreate()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 320)
    }
    
    private func setPreset(_ w: Int, _ h: Int) {
        inputWidth = "\(w)"
        inputHeight = "\(h)"
    }
    
    private func validateAndCreate() {
        guard let w = Int(inputWidth), w >= 1 && w <= 200 else {
            errorMessage = "Width must be between 1 and 200 pixels."
            return
        }
        guard let h = Int(inputHeight), h >= 1 && h <= 200 else {
            errorMessage = "Height must be between 1 and 200 pixels."
            return
        }
        
        let title = inputTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : inputTitle
        onConfirm(title, w, h)
        dismiss()
    }
}
