//
//  ViewController.swift
//  DemoDogsRecognition
//
//  Created by Stanislav Sidelnikov on 7/26/18.
//  Copyright © 2018 Yandex LLC. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class StreamRecognitionViewController: UIViewController, ARSCNViewDelegate, StockViewsView {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet var debugTextView: UITextView!
    @IBOutlet var resultLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene

        // --- ML & VISION ---

        // Setup Vision Model
        guard let selectedModel = try? VNCoreMLModel(for: dogs_breeds().model) else {
            fatalError("Could not load model")
        }

        // Set up Vision-CoreML Request
        let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size.
        visionRequests = [classificationRequest]

        // Begin Loop to Update CoreML
        loopCoreMLUpdate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.isNavigationBarHidden = true
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    override var prefersStatusBarHidden : Bool { return true }

    // MARK: - Private
    private func loopCoreMLUpdate() {
        // Continuously run CoreML whenever it's ready. (Preventing 'hiccups' in Frame Rate)
        dispatchQueueML.async {
            // 1. Run Update.
            self.updateCoreML()
            // 2. Loop this function.
            self.loopCoreMLUpdate()
        }
    }

    private func updateCoreML() {
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)

        // Prepare CoreML/Vision Request
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        // Run Vision Image Request
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }

    private func classificationCompleteHandler(request: VNRequest, error: Error?) {
        updateViews(withRequest: request, error: error)
    }

    private let dispatchQueueML = DispatchQueue(label: "ru.yandex.dispatchqueueml") // A Serial Queue
    private var visionRequests = [VNRequest]()
}

protocol StockViewsView {
    var debugTextView: UITextView! { get }
    var resultLabel: UILabel! { get }
}

extension StockViewsView {
    @discardableResult
    func updateViews(withRequest request: VNRequest, error: Error?) -> String? {
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return nil
        }
        guard let observations = request.results else {
            print("No results")
            return nil
        }

        // Get Classifications
        let classifications = observations[0...2] // top 3 results
            .compactMap { $0 as? VNClassificationObservation }
            .map { "\($0.identifier) \(String(format:" : %.2f", $0.confidence))" }
            .joined(separator: "\n")

        // Display Top Symbol
        var resultText = "Unknown"
        let topPrediction = classifications.components(separatedBy: "\n")[0]
        let topPredictionName = topPrediction.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
        // Only display a prediction if confidence is above 1%
        let topPredictionScore:Float? = Float(topPrediction.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces))
        if (topPredictionScore != nil && topPredictionScore! > 0.01) {
            resultText = topPredictionName
        }

        // Render Classifications
        DispatchQueue.main.async {
            // Display Debug Text on screen
            self.debugTextView.text = "TOP 3 PROBABILITIES: \n" + classifications

            self.resultLabel.text = resultText
        }

        return resultText
    }
}
