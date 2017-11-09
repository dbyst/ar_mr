//
//  ViewController.swift
//  CoreML in ARKit
//
//  Created by Hanley Weng on 14/7/17.
//  Copyright © 2017 CompanyName. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

import Vision

enum PredefinedObjects: String {
    case sombrero = "sombrero"
    case maraca = "maraca"
    case glasses = "stethoscope"
    
}

class ViewController: UIViewController, ARSCNViewDelegate {

    // SCENE
    @IBOutlet var sceneView: ARSCNView!
    var latestPrediction: String = "..."
    let bubbleDepth : Float = 0.01 // the 'depth' of 3D text
    var bubbleNodeParent: SCNNode?

    var bigRoomEvents:[Event] = []
    var smallRoomEvents:[Event] = []
    var busRoomEvents:[Event] = []
    // COREML
    var visionRequests = [VNRequest]()
    let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml") // A Serial Queue
    var didRecognizePredefinedObject = false
    
    @IBOutlet weak var debugTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        //google callendar
      
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
//        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Enable Default Lighting - makes the 3D text a bit poppier.
        sceneView.autoenablesDefaultLighting = true
        
        let today = Date()
        let calendar: Calendar = Calendar.current
        let components = (calendar as NSCalendar).components([.year, .month, .day], from: today)
        let startDate = calendar.date(from: components)!
        
        let endDate = Date(timeIntervalSince1970: startDate.timeIntervalSince1970 + 60*60*24)
        GoogleCalendarManager.shared.start(viewController: self,finishLoginCallback: {
            GoogleCalendarManager.shared.executeRequest(startDate: startDate, endDate: endDate, room: .big) { (evensts) in
                self.bigRoomEvents = evensts.map({ Event(event: $0) })
            }
            
            GoogleCalendarManager.shared.executeRequest(startDate: startDate, endDate: endDate, room: .small) { (evensts) in
                self.smallRoomEvents = evensts.map({ Event(event: $0) })
            }
            
            GoogleCalendarManager.shared.executeRequest(startDate: startDate, endDate: endDate, room: .bus) { (evensts) in
                self.busRoomEvents = evensts.map({ Event(event: $0) })
            }
        })
        
        
     
        
   
        // Set up Vision Model
        guard let selectedModel = try? VNCoreMLModel(for: Inceptionv3().model) else { // (Optional) This can be replaced with other models on https://developer.apple.com/machine-learning/
            fatalError("Could not load model. Ensure model has been drag and dropped (copied) to XCode Project from https://developer.apple.com/machine-learning/ . Also ensure the model is part of a target (see: https://stackoverflow.com/questions/45884085/model-is-not-part-of-any-target-add-the-model-to-a-target-to-enable-generation ")
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
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        // Enable plane detection
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            // Do any desired updates to SceneKit here.
        }
    }
    
    // MARK: - Status Bar: Hide
    override var prefersStatusBarHidden : Bool {
        return true
    }

    // MARK: - CoreML Vision Handling
    
    func loopCoreMLUpdate() {
        if didRecognizePredefinedObject {
            return
        }
        
        // Continuously run CoreML whenever it's ready. (Preventing 'hiccups' in Frame Rate)
        dispatchQueueML.async {
            // 1. Run Update.
            self.updateCoreML()
            
            // 2. Loop this function.
            self.loopCoreMLUpdate()
        }
        
    }
    
    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        if didRecognizePredefinedObject {
            return
        }
        
        // Catch Errors
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else {
            print("No results")
            return
        }
        
        // Get Classifications
        let classifications = observations[0...1] // top 2 results
            .flatMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:"- %.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        
        DispatchQueue.main.async {
            // Print Classifications
            print(classifications)
            print("--")
            
            // Display Debug Text on screen
            var debugText:String = ""
            debugText += classifications
            self.debugTextView.text = debugText
            
            // Store the latest prediction
            var objectName:String = "…"
            objectName = classifications.components(separatedBy: "-")[0]
            objectName = objectName.components(separatedBy: ",")[0]
            self.latestPrediction = objectName
            self.defineActionForObject(objectName.trimmingCharacters(in: .whitespaces))
        }
    }
    
    func defineActionForObject(_ objectName: String) {
        guard let predefinedObject = PredefinedObjects(rawValue: objectName), !didRecognizePredefinedObject else {
            return
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        
        let date = Date()
        print("It's \(objectName)")
        switch predefinedObject {
        case .sombrero:
            let currentEvents = bigRoomEvents.filter {
                $0.isBusy == true
            }
            if let currentEvent = currentEvents.first {
                let text = "\(dateFormatter.string(from: currentEvent.startDate)) : \(dateFormatter.string(from: currentEvent.endDate)) - busy"
                drawBubbleWithText(text, isBusy: true)
            } else {
               drawBubbleWithText("Available Now", isBusy: false)
            }
        case .maraca:
            let currentEvents = smallRoomEvents.filter {
                $0.isBusy == false
            }
            if let currentEvent = currentEvents.first {
                let text = "\(dateFormatter.string(from: currentEvent.startDate)) : \(dateFormatter.string(from: currentEvent.endDate)) - busy"
                drawBubbleWithText(text, isBusy: true)
            } else {
                drawBubbleWithText("Available Now", isBusy: false)
            }
        case .glasses:
            let currentEvents = busRoomEvents.filter {
                $0.isBusy == false
            }
            if let currentEvent = currentEvents.first {
                let text = "\(dateFormatter.string(from: currentEvent.startDate)) : \(dateFormatter.string(from: currentEvent.endDate)) - busy"
                drawBubbleWithText(text, isBusy: true)
            } else {
                drawBubbleWithText("Available Now", isBusy: false)
            }
        default:
            return
        }

        didRecognizePredefinedObject = true
    }
    
    
    func drawBubbleWithText(_ text: String, isBusy: Bool) {
        let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
        
        let arHitTestResults : [ARHitTestResult] = sceneView.hitTest(screenCentre, types: [.featurePoint]) // Alternatively, we could use '.existingPlaneUsingExtent' for more grounded hit-test-points.
        
        if let closestResult = arHitTestResults.first {
            // Get Coordinates of HitTest
            let transform : matrix_float4x4 = closestResult.worldTransform
            let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            // Create 3D Text
            let node : SCNNode = createNewBubbleParentNode(text, isBusy: isBusy)
            sceneView.scene.rootNode.addChildNode(node)
            node.position = worldCoord
        }
    }
    
    func createNewBubbleParentNode(_ text : String, isBusy: Bool) -> SCNNode {
        // Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.
        
        // TEXT BILLBOARD CONSTRAINT
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        // BUBBLE-TEXT
        let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
        var font = UIFont(name: "Futura", size: 0.4)
        font = font?.withTraits(traits: .traitBold)
        bubble.font = font
        bubble.alignmentMode = kCAAlignmentCenter
        bubble.firstMaterial?.diffuse.contents = isBusy ? UIColor.red : UIColor.green
        bubble.firstMaterial?.specular.contents = UIColor.white
        bubble.firstMaterial?.isDoubleSided = true
        // bubble.flatness // setting this too low can cause crashes.
        bubble.chamferRadius = CGFloat(bubbleDepth)
        
        // BUBBLE NODE
        let (minBound, maxBound) = bubble.boundingBox
        let bubbleNode = SCNNode(geometry: bubble)
        // Centre Node - to Centre-Bottom point
        bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
        // Reduce default text size
        bubbleNode.scale = SCNVector3Make(0.1, 0.1, 0.1)
        
        // CENTRE POINT NODE
        let sphere = SCNSphere(radius: 0.01)
        sphere.firstMaterial?.diffuse.contents = UIColor.white
        let sphereNode = SCNNode(geometry: sphere)
        
        // BUBBLE PARENT NODE
        bubbleNodeParent = SCNNode()
        bubbleNodeParent?.addChildNode(bubbleNode)
        bubbleNodeParent?.addChildNode(sphereNode)
        bubbleNodeParent?.constraints = [billboardConstraint]
        
        return bubbleNodeParent!
    }
    @IBAction func scanAgain(_ sender: Any) {
        bubbleNodeParent?.enumerateChildNodes({ (node, _) in
            node.removeFromParentNode()
        })

        didRecognizePredefinedObject = false
        loopCoreMLUpdate()
    }
    
    func updateCoreML() {
        ///////////////////////////
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        // Note: Not entirely sure if the ciImage is being interpreted as RGB, but for now it works with the Inception model.
        // Note2: Also uncertain if the pixelBuffer should be rotated before handing off to Vision (VNImageRequestHandler) - regardless, for now, it still works well with the Inception model.
        
        ///////////////////////////
        // Prepare CoreML/Vision Request
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        ///////////////////////////
        // Run Image Request
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }
}

extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits:UIFontDescriptorSymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}
