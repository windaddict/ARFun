/*
 * Copyright 2017 John M. P. Knox
 * Licensed under the MIT License - see license file
 */
import UIKit
import ARKit
import PlaygroundSupport

/**
 * A Simple starting point for AR experimentation in Swift Playgrounds 2
 */
class ARFun {
    let arSessionConfig = ARWorldTrackingSessionConfiguration()
    
    var view:ARSCNView? = nil
    let scene = SCNScene()
    let useScenekit = true
    
    init(){
        let frame = CGRect(x: 0.0, y: 0, width: 100, height: 100)
        let arView = ARSCNView(frame: frame)
        view = arView
        arView.scene = scene
        arSessionConfig.planeDetection = .horizontal
        arView.session.run(arSessionConfig, options: [.resetTracking, .removeExistingAnchors])
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewTapped(gestureRecognizer:)))
        view?.addGestureRecognizer(gestureRecognizer)
    }
    
    ///adds a new torus to the scene's root node
    func addTorus(position: SCNVector3 = SCNVector3Zero) {
        let torus = SCNTorus(ringRadius: 0.1, pipeRadius: 0.02)
        torus.firstMaterial?.diffuse.contents = UIColor(colorLiteralRed: 0.6, green: 0, blue: 0, alpha: 1)
        torus.firstMaterial?.specular.contents = UIColor.white
        let torusNode = SCNNode(geometry:torus)
        torusNode.position = position
        torusNode.rotation = SCNVector4(x:1,y:1,z:0, w:0)
        let spin = CABasicAnimation(keyPath: "rotation.w")
        spin.toValue = 2 * Double.pi
        spin.duration = 3
        spin.repeatCount = HUGE
        torusNode.addAnimation(spin, forKey: "spin around")
        
        scene.rootNode.addChildNode(torusNode)
    }
    
    ///add a torus where the scene was tapped
    @objc func viewTapped(gestureRecognizer: UITapGestureRecognizer){
        switch gestureRecognizer.state {
        default:
            print("got tap: \(gestureRecognizer.location(in: view))")
            if let hitTransform = view?.hitTest(gestureRecognizer.location(in: view), types: [ARHitTestResult.ResultType.featurePoint, ARHitTestResult.ResultType.existingPlaneUsingExtent]).first?.worldTransform /*, let cameraTransform = arSession.currentFrame?.camera.transform */{
                //let cameraPos = vectorFrom(transform: cameraTransform)
                
                let pos = vectorFrom(transform: hitTransform)
                //let cameraToPos = pos - cameraPos
                
                addTorus(position: pos)
            } else {
                //add a torus at 0,0,0 -- 
                addTorus()
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
