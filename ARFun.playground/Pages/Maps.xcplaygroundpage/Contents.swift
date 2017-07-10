import PlaygroundSupport
import UIKit
import MapKit

class Mapper: NSObject{
    let mapView = MKMapView()
    let debugView = ARDebugView()
    ///0: no locations, 1: start location marked, 2: destination marked
    var mapState = 0 
    var start: CLLocationCoordinate2D? = nil
    var destination: CLLocationCoordinate2D? = nil
    
    
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
            case 0:
                start = tapLocation
                mapState = 1
            case 1:
                destination = tapLocation
                mapState = 2
            case 2:
                guard let start = start, let destination = destination else {
                    return
                }
                let (distanceSouth, distanceEast) = distances(start: start, destination: destination)
                debugView.log("S: \(distanceSouth) E: \(distanceEast)")
            mapState = 0 //TODO: show AR? 
            default :
                mapState = 0
            }
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

let mapper = Mapper()

PlaygroundPage.current.needsIndefiniteExecution = true 



