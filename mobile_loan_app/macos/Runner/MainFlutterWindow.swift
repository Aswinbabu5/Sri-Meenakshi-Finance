import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Define min and max size for desktop computers
    self.minSize = NSSize(width: 960, height: 640)

    if let screen = NSScreen.main {
      let visibleFrame = screen.visibleFrame
      self.maxSize = visibleFrame.size

      let defaultWidth = min(1440, visibleFrame.width * 0.95)
      let defaultHeight = min(920, visibleFrame.height * 0.95)
      let originX = visibleFrame.origin.x + (visibleFrame.width - defaultWidth) / 2
      let originY = visibleFrame.origin.y + (visibleFrame.height - defaultHeight) / 2

      self.setFrame(NSRect(x: originX, y: originY, width: defaultWidth, height: defaultHeight), display: true)
    } else {
      let windowFrame = self.frame
      self.setFrame(windowFrame, display: true)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
