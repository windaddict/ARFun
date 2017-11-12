/*
 * Copyright 2017 John M. P. Knox
 * Licensed under the MIT License - see license file
 */
import UIKit
import ARKit
import PlaygroundSupport
import MapKit

/**
 * A starting point for placing AR content at real world coordinates in Swift Playgrounds 2
 * Note since location services don't work in Playgrounds, the user has to manually pick
 * their starting location and the AR location on a map before starting. If the compass isn't 
 * calibrated, the AR content won't place accurately.
 */
class WaypointNavigator: NSObject{
    let mapView = MKMapView()
    let debugView = ARDebugView()
    ///0: no locations, 1: start location marked, 2: destination marked
    var mapState = 0 
    var start: CLLocationCoordinate2D? = nil
    var destination: CLLocationCoordinate2D? = nil
    var arDisplay: WayPointDisplay?
    
    override init(){
        super.init()
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewTapped(gestureRecognizer:)))
        mapView.addGestureRecognizer(tapGestureRecognizer)
        
        debugView.translatesAutoresizingMaskIntoConstraints = false
        //add the debug view 
        mapView.addSubview(debugView)
        mapView.leadingAnchor.constraint(equalTo: debugView.leadingAnchor)
        mapView.topAnchor.constraint(equalTo: debugView.topAnchor)
        PlaygroundPage.current.liveView = mapView
    }
    
    @objc func viewTapped(gestureRecognizer: UITapGestureRecognizer){
        let tapPoint = gestureRecognizer.location(in: mapView)
        let tapLocation = mapView.convert(tapPoint, toCoordinateFrom: mapView)
        debugView.log("tapped: \(tapLocation)")
        
        switch mapState{ 
        case 0: //wait for the user to tap their starting location
            start = tapLocation
            mapState = 1
        case 1: //wait for the user to tap their destination
            destination = tapLocation
            mapState = 2
        case 2: //calculate the distances between the start and destination, show the ar display
            guard let start = start, let destination = destination else {
                debugView.log("Error: either start or destination didn't exist")
                return
            }
            let (distanceSouth, distanceEast) = distances(start: start, destination: destination)
            let display = WayPointDisplay()
            arDisplay = display
            PlaygroundPage.current.liveView = display.view
            display.distanceSouth = distanceSouth
            display.distanceEast = distanceEast
            mapState = 0 //return to initial state
            
        default :
            mapState = 0
            debugView.log("Error: hit default case")
        }
    }
    
    ///an approximation that returns the number of meters south and east the destination is from the start
    func distances(start: CLLocationCoordinate2D, destination: CLLocationCoordinate2D)->(Double, Double){
        //east / longitude
        let lonStart = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let lonDest = CLLocation(latitude: start.latitude, longitude: destination.longitude)
        var distanceEast = lonStart.distance(from: lonDest)
        let directionMultiplier = destination.longitude >= start.longitude ? 1.0 : -1.0
        distanceEast = distanceEast * directionMultiplier
        
        //south / latitude
        let latDest = CLLocation(latitude: destination.latitude, longitude: start.longitude)
        var distanceSouth = lonStart.distance(from: latDest)
        let latMultiplier = destination.latitude >= start.latitude ? -1.0 : 1.0
        distanceSouth = latMultiplier * distanceSouth
        return (distanceSouth, distanceEast)
        
    }
}

class WayPointDisplay: NSObject, ARSCNViewDelegate {
    ///the distance south of the world origin to place the waypoint
    var distanceSouth: Double = 0.0
    ///the distance east of the world origin to place the waypoint
    var distanceEast: Double = 0.0
    ///maps ARAnchors to SCNNodes
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
    
    let arSessionConfig = ARWorldTrackingConfiguration()
    let debugView = ARDebugView()
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
        debugView.translatesAutoresizingMaskIntoConstraints = false
        //add the debug view 
        arView.addSubview(debugView)
        arView.leadingAnchor.constraint(equalTo: debugView.leadingAnchor)
        arView.topAnchor.constraint(equalTo: debugView.topAnchor)
        
        view = arView
        arView.scene = scene
        
        //setup session config
        if !ARWorldTrackingConfiguration.isSupported { return }
        arSessionConfig.planeDetection = .horizontal
        arSessionConfig.worldAlignment = .gravityAndHeading //y-axis points UP, x points E (longitude), z points S (latitude)
        arSessionConfig.isLightEstimationEnabled = true
        arView.session.run(arSessionConfig, options: [.resetTracking, .removeExistingAnchors])
        arView.delegate = self
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewTapped(gestureRecognizer:)))
        view?.addGestureRecognizer(gestureRecognizer)
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
    
    ///adds a 200M high cylinder at worldTransform
    func addAntenna(worldTransform: matrix_float4x4 = matrix_identity_float4x4) {
        let height = 200 as Float
        let cylinder = SCNCylinder(radius: 0.5, height: CGFloat(height))
        
        cylinder.firstMaterial?.diffuse.contents = UIColor(red: 0.4, green: 0, blue: 0, alpha: 1)
        cylinder.firstMaterial?.specular.contents = UIColor.white
        
        //raise the cylinder so the base is positioned at the worldTransform
        var transform = matrix_identity_float4x4
        transform.columns.3.y = height / 2
        let finalTransform = matrix_multiply(worldTransform, transform)
        
        let cylinderNode = SCNNode(geometry:cylinder)
        addNode(node: cylinderNode, worldTransform: finalTransform)
    }
    
    ///when the user taps, add a waypoint antenna at distanceEast, distanceSouth from the origin
    @objc func viewTapped(gestureRecognizer: UITapGestureRecognizer){
        debugView.log("DE: \(distanceEast) DS: \(distanceSouth)")
        var transform = matrix_identity_float4x4
        transform.columns.3.x = Float(distanceEast)
        transform.columns.3.z = Float(distanceSouth)
        addAntenna(worldTransform: transform)
    }
    
    ///convert a transform matrix_float4x4 to a SCNVector3
    func vectorFrom(transform: matrix_float4x4) -> SCNVector3 {
        return SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
}

let mapper = WaypointNavigator()
PlaygroundPage.current.needsIndefiniteExecution = true



