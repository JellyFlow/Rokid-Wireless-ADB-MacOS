import Foundation
import Network

enum LocalNetworkPermissionService {
    private static let queue = DispatchQueue(label: "com.rokid.wireless-projection.native.v2.local-network")
    private static let lock = NSLock()
    private static var browser: NWBrowser?

    static func request() {
        lock.lock()
        guard browser == nil else {
            lock.unlock()
            return
        }

        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(
            for: .bonjour(type: "_rokidmirror._tcp", domain: nil),
            using: parameters
        )
        self.browser = browser
        lock.unlock()

        browser.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 3) {
            browser.cancel()
            lock.lock()
            if self.browser === browser { self.browser = nil }
            lock.unlock()
        }
    }
}
