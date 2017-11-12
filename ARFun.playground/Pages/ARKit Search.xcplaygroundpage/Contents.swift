/*
 * Copyright 2017 John M. P. Knox
 * Licensed under the MIT License - see license file
 */
import UIKit
import ARKit
import Vision
import PlaygroundSupport

/**
 * A Simple starting point for AR experimentation in Swift Playgrounds 2
 */
class ARFun: NSObject, ARSCNViewDelegate, ARSessionDelegate {
    var nodeDict = [UUID:SCNNode]()
    //mark: ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        if let node = nodeDict[anchor.identifier] {
            return node
        }
        return nil
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async { [weak self] in
            self?.debugView.log("updated node")
        }
    }
    
    //=======================
    //mark: ARSessionDelegate
    ///holds the image we're trying to match
    var matchImage: CVPixelBuffer?
    var captureNext = false
    func session(_ session: ARSession, didUpdate frame: ARFrame){
        if captureNext {
            matchImage = frame.capturedImage
            captureNext = false
        } else if let referenceImage = matchImage {
            let imageRequest = VNTranslationalImageRegistrationRequest(targetedCVPixelBuffer: referenceImage)
            let requestHandler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage)
            try? requestHandler.perform([imageRequest])
            if let results = imageRequest.results?.first as? VNImageTranslationAlignmentObservation {
                let originalRect = CGRect(x: 0, y:0, width: 1, height: 1)
                guard let viewSize = view?.bounds.size else {
                    return
                }
                let displayTransform = frame.displayTransform(for: UIInterfaceOrientation.landscapeLeft, viewportSize: viewSize) //TODO: programatically get orientation
                let ndRect = originalRect.applying(displayTransform)
                let displayRect = CGRect(x:ndRect.origin.x * viewSize.width, y: ndRect.origin.y * viewSize.height, width: ndRect.size.width * viewSize.width, height: ndRect.size.height * viewSize.height) //perhaps another transform instead of this mess
                DispatchQueue.main.async{
                    
                    if results.confidence < 1 {
                        self.debugView.clearWithLog("LOW")
                    } else if fabs(results.alignmentTransform.ty) >= CGFloat(CVPixelBufferGetWidth(frame.capturedImage)){
                        self.debugView.clearWithLog("NO MATCH: too much Y")
                    } else if results.alignmentTransform.ty <= 0 {
                        self.debugView.clearWithLog("NO MATCH: too little Y")
                    } else if results.alignmentTransform.tx >= CGFloat(CVPixelBufferGetHeight(frame.capturedImage)) {
                        self.debugView.clearWithLog("NO MATCH: too much X")
                    }  else if results.alignmentTransform.tx <= 0 {
                        self.debugView.clearWithLog("NO MATCH: too little X")
                    } else {
                        self.debugView.clearWithLog("match: \(results.alignmentTransform)")
                        self.rectView.frame = displayRect
                        self.debugView.log("rect is: \(String(describing: self.view?.bounds.size))")
                        self.debugView.log("transform is: \(displayTransform)")
                    }
                }
            }
        }
    }
    
    let arSessionConfig = ARWorldTrackingConfiguration()
    
    let debugView = ARDebugView()
    let captureButton = UIButton(type: UIButtonType.system)
    let rectView = UIView()
    
    var view:ARSCNView? = nil
    let scene = SCNScene()
    let useScenekit = true
    
    override init(){
        super.init()
        let frame = CGRect(x: 0.0, y: 0, width: 100, height: 100)
        let arView = ARSCNView(frame: frame)
        //configure the ARSCNView
        arView.debugOptions = [
            ARSCNDebugOptions.showWorldOrigin,
            ARSCNDebugOptions.showFeaturePoints, 
//              SCNDebugOptions.showLightInfluences, 
//              SCNDebugOptions.showWireframe
        ]
        arView.showsStatistics = true
        arView.automaticallyUpdatesLighting = true
        
        //views
        debugView.translatesAutoresizingMaskIntoConstraints = false
        //add the debug view 
        arView.addSubview(debugView)
        arView.leadingAnchor.constraint(equalTo: debugView.leadingAnchor).isActive = true
        arView.topAnchor.constraint(equalTo: debugView.topAnchor)
        //configure the capture button
        captureButton.setTitle("Capture", for: .normal)
        captureButton.backgroundColor = UIColor.gray
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(captureButton)
        arView.topAnchor.constraint(equalTo: captureButton.topAnchor).isActive = true
        arView.trailingAnchor.constraint(equalTo: captureButton.trailingAnchor).isActive = true
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside )
        //configure the rectView
        arView.addSubview(rectView)
        rectView.layer.borderWidth = 2
        rectView.layer.borderColor = UIColor.red.cgColor
        rectView.frame = CGRect(x: 0, y:100, width:30, height: 30)
        
        
        view = arView
        arView.scene = scene
        
        //setup session config
        if !ARWorldTrackingConfiguration.isSupported { return }
        arSessionConfig.planeDetection = .horizontal
        arSessionConfig.worldAlignment = .gravityAndHeading //y-axis points UP, x points E (longitude), z points S (latitude)
        arSessionConfig.isLightEstimationEnabled = true
        arView.session.delegate = self
        arView.session.run(arSessionConfig, options: [.resetTracking, .removeExistingAnchors])
        arView.delegate = self
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewTapped(gestureRecognizer:)))
        view?.addGestureRecognizer(gestureRecognizer)
    }
    
    @objc func captureButtonTapped() {
        captureNext = true
    }
    
    let shouldAddAnchorsForNodes = true
    func addNode(node: SCNNode, worldTransform: matrix_float4x4) {
        let anchor = ARAnchor(transform: worldTransform)
        let position = vectorFrom(transform: worldTransform)
        node.position = position
        node.rotation = SCNVector4(x: 1, y: 1, z: 0, w: 0)
        nodeDict[anchor.identifier] = node
        if shouldAddAnchorsForNodes {
            view?.session.add(anchor: anchor)
        } else {
            scene.rootNode.addChildNode(node)
        }
    }
    
    func debug(sceneNode : SCNNode, prefix: String = "" ){
        debugView.log(prefix + (sceneNode.name ?? ""))
        for child in sceneNode.childNodes{
            debug(sceneNode: child, prefix: prefix + "-")
        }
    }
    
    func debug(scene: SCNScene, prefix: String = ""){
        debug(sceneNode: scene.rootNode)
    }
    
    ///returns a new node with a scene, if one can be found for the scene file specified
    func nodeFromScene(named fileName: String, inDirectory directoryName: String)-> SCNNode? {
        let scene = SCNScene(named: fileName, inDirectory: directoryName)
        
        guard let theScene = scene else {
            debugView.log("no scene \(fileName) in \(directoryName)")
            return nil
        }
        
        //debug(scene: theScene)
        
        let node = SCNNode()
        
        for child in theScene.rootNode.childNodes {
            debugView.log("examining \(String(describing: child.name))")
            child.geometry?.firstMaterial?.lightingModel = .physicallyBased
            child.movabilityHint = .movable
            node.addChildNode(child)
        }
        return node
    }
    
    ///adds a new torus to the scene's root node
    func addTorus(worldTransform: matrix_float4x4 = matrix_identity_float4x4) {
        let torus = SCNTorus(ringRadius: 0.1, pipeRadius: 0.02)
        torus.firstMaterial?.diffuse.contents = UIColor(red: 0.4, green: 0, blue: 0, alpha: 1)
        torus.firstMaterial?.specular.contents = UIColor.white
        let torusNode = SCNNode(geometry:torus)
        let spin = CABasicAnimation(keyPath: "rotation.w")
        spin.toValue = 2 * Double.pi
        spin.duration = 3
        spin.repeatCount = HUGE
        torusNode.addAnimation(spin, forKey: "spin around")
        addNode(node: torusNode, worldTransform: worldTransform)
    }
    
    func makeLight()->SCNLight{
        let light = SCNLight()
        light.intensity = 1
        light.type = .omni
        light.color = UIColor.yellow
        light.attenuationStartDistance = 0.01
        light.attenuationEndDistance = 1
        return light 
    }
    
    func makeLightNode()->SCNNode{
        let light = makeLight()
        let node = SCNNode()
        var transform = matrix_identity_float4x4
        transform.columns.3.y = 0.2
        node.simdTransform = transform
        node.light = light
//          node.position = SCNVector3(0.0, 0.2, 0.0)
        node.simdTransform = transform
        return node
    }
    
    func addCandle(worldTransform: matrix_float4x4 = matrix_identity_float4x4) {
        guard let candleNode = nodeFromScene(named: "candle.scn", inDirectory: "Models.scnassets/candle") else {
            return
        }
        
        candleNode.addChildNode(makeLightNode())
        
        addNode(node: candleNode, worldTransform: worldTransform)
    }
    
    ///add a node where the scene was tapped
    @objc func viewTapped(gestureRecognizer: UITapGestureRecognizer){
        switch gestureRecognizer.state {
        default:
            print("got tap: \(gestureRecognizer.location(in: view))")
            let hitTypes:ARHitTestResult.ResultType = [
                ARHitTestResult.ResultType.existingPlaneUsingExtent,
//                  ARHitTestResult.ResultType.estimatedHorizontalPlane,
//                  ARHitTestResult.ResultType.featurePoint
            ]
            if let hitTransform = view?.hitTest(gestureRecognizer.location(in: view), types: hitTypes).first?.worldTransform {
                addCandle(worldTransform: hitTransform) //TODO: use the anchor provided, if any?
            } else {
                //add an item at 0,0,0 -- 
                //addCandle()
                debugView.log("no hit for tap")
            }
        }
    }
    
    ///convert a transform matrix_float4x4 to a SCNVector3
    func vectorFrom(transform: matrix_float4x4) -> SCNVector3 {
        return SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
}

///vector addition and subtraction
extension SCNVector3 {
    static func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
    }
    
    static func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
    }
}

let arFun = ARFun()
PlaygroundPage.current.liveView = arFun.view
PlaygroundPage.current.needsIndefiniteExecution = true


