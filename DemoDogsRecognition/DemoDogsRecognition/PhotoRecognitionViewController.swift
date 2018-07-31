//
//  PhotoRecognitionViewController.swift
//  DemoDogsRecognition
//
//  Created by Stanislav Sidelnikov on 7/27/18.
//  Copyright © 2018 Yandex LLC. All rights reserved.
//

import UIKit
import CoreML
import Vision

final class PhotoRecognitionViewController: UIViewController, StockViewsView {
    @IBOutlet var debugTextView: UITextView!
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var resultLabel: UILabel!
    @IBOutlet var exampleImageView: UIImageView!

    override func viewDidLoad() {
        guard let model = try? VNCoreMLModel(for: dogs_breeds().model) else {
            fatalError("can't load Places ML model")
        }
        self.model = model
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.isNavigationBarHidden = false
    }

    @IBAction func pickPhotoTapped(_ sender: Any) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let availableModes: [UIImagePickerControllerSourceType: String] = [
            .camera: "Take a Photo",
            .savedPhotosAlbum: "Pick from Gallery"
        ]
        for (mode, title) in availableModes {
            guard UIImagePickerController.isSourceTypeAvailable(mode) else {
                continue
            }
            let actionMode = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.pickImage(from: mode)
            }
            sheet.addAction(actionMode)
        }
        let actionCancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in }
        sheet.addAction(actionCancel)
        present(sheet, animated: true, completion: nil)
    }

    // MARK: Private
    private var model: VNCoreMLModel!
    private let dispatchQueueML = DispatchQueue(label: "ru.yandex.dispatchqueueml.photo") // A Serial Queue

    private func pickImage(from source: UIImagePickerControllerSourceType) {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = source
        present(imagePickerController, animated: true, completion: nil)
    }

    private func update(image: UIImage) {
        imageView.image = image
        exampleImageView.image = nil
        if let ciImage = CIImage(image: image) {
            detectDog(image: ciImage)
        } else {
            debugTextView.text = ""
            resultLabel.text = "<Incorrect photo format>"
            print("Cannot get CIImage from the image")
        }
    }

    private func detectDog(image: CIImage) {
        resultLabel.text = "detecting scene..."

        // Load the ML model through its generated class
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            let result = self?.updateViews(withRequest: request, error: error)
            if let result = result {
                DispatchQueue.main.async {
                    self?.exampleImageView.image = UIImage(named: result)
                }
            }
        }

        let handler = VNImageRequestHandler(ciImage: image)
        dispatchQueueML.async {
            do {
                try handler.perform([request])
            } catch {
                print(error)
            }
        }
    }
}

extension PhotoRecognitionViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion: nil)
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            update(image: image)
        }
    }
}
