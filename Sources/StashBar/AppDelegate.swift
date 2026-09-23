import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var drawer: DrawerController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugLog("applicationDidFinishLaunching")
        AccessibilityPermission.ensureRequested()
        drawer = DrawerController()
        drawer.start()
        debugLog("drawer started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        drawer.stop()
    }
}
