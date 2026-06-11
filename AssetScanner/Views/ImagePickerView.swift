import SwiftUI
import PhotosUI

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let onSelect: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(image: $image, onSelect: onSelect) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        @Binding var image: UIImage?
        let onSelect: (UIImage) -> Void

        init(image: Binding<UIImage?>, onSelect: @escaping (UIImage) -> Void) {
            _image = image
            self.onSelect = onSelect
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { return }
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                if let img = object as? UIImage {
                    DispatchQueue.main.async {
                        self.image = img
                        self.onSelect(img)
                    }
                }
            }
        }
    }
}
