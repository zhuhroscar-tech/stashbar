import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var drawer: DrawerController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        drawer = DrawerController()
        drawer.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        drawer.stop()
    }
}
