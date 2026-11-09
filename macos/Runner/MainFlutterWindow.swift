import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSPanel {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    WindowManagerPlugin.RegisterGeneratedPlugins = RegisterGeneratedPlugins

    // Safety net: paint the native window dark immediately so it can never
    // show a white/gray flash if window_manager configuration is delayed or
    // fails. Matches DesignTokens.bgDeep (0xFF070912).
    self.backgroundColor = NSColor(
      red: CGFloat(7) / 255,
      green: CGFloat(9) / 255,
      blue: CGFloat(18) / 255,
      alpha: 1.0
    )

    super.awakeFromNib()
  }

  // Ensure the window starts hidden before Flutter renders.
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}