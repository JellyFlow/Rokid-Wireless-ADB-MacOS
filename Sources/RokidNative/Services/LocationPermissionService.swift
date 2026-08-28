import CoreLocation
import Foundation

@MainActor
final class LocationPermissionService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationPermissionService()

    private let manager = CLLocationManager()

    private override init() {
        super.init()
        manager.delegate = self
    }

    func request() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }
}
