import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
    
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        
        AppLifecycleChannel.registerChannel(flutterViewController: flutterViewController)
        
        RegisterGeneratedPlugins(registry: flutterViewController)
        
        super.awakeFromNib()
    }
}
