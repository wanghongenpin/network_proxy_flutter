let kProxyServiceVPNStatusNotification = "kProxyServiceVPNStatusNotification"

import Foundation
import NetworkExtension

enum VPNStatus {
    case off
    case connecting
    case on
    case disconnecting
}


class VpnManager{
    var activeVPN: NETunnelProviderManager?;
    
    public var proxyHost: String = "127.0.0.01"
    public var proxyPort: Int = 9099

    static let shared = VpnManager()
    var observerAdded: Bool = false


    fileprivate(set) var vpnStatus = VPNStatus.off {
        didSet {
            NotificationCenter.default.post(name: Notification.Name(rawValue: kProxyServiceVPNStatusNotification), object: nil)
        }
    }

    init() {
        loadProviderManager{
            guard let manager = $0 else{return}
            self.updateVPNStatus(manager)
        }
        addVPNStatusObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func addVPNStatusObserver() {
        guard !observerAdded else{
            return
        }
        loadProviderManager { [unowned self] (manager) -> Void in
            if let manager = manager {
                self.observerAdded = true
                NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: manager.connection, queue: OperationQueue.main, using: { [unowned self] (notification) -> Void in
                    self.updateVPNStatus(manager)
                    })
            }
        }
    }


    func updateVPNStatus(_ manager: NEVPNManager) {
        switch manager.connection.status {
        case .connected:
            self.vpnStatus = .on
        case .connecting, .reasserting:
            self.vpnStatus = .connecting
        case .disconnecting:
            self.vpnStatus = .disconnecting
        case .disconnected, .invalid:
            self.vpnStatus = .off
        @unknown default: break

        }
    }
}

// load VPN Profiles
extension VpnManager{


    fileprivate func createProviderManager() -> NETunnelProviderManager {
        let manager = NETunnelProviderManager()
        let conf = NETunnelProviderProtocol()
        conf.serverAddress = "ProxyPin"
        manager.protocolConfiguration = conf
        manager.localizedDescription = "ProxyPin"
        return manager
    }

    func loadAndCreatePrividerManager(_ complete: @escaping (NETunnelProviderManager?) -> Void ){
        NETunnelProviderManager.loadAllFromPreferences{ [self] (managers, error) in
            guard let managers = managers else{return}
            let manager: NETunnelProviderManager
            if managers.count > 0 {
                manager = managers[0]
            }else{
                manager = self.createProviderManager()
            }
   
            var conf = [String:AnyObject]()
            conf["proxyHost"] = self.proxyHost as AnyObject
            conf["proxyPort"] = self.proxyPort as AnyObject
            
            let orignConf = manager.protocolConfiguration as! NETunnelProviderProtocol
 
            orignConf.providerConfiguration = conf
            manager.protocolConfiguration = orignConf
            
            print(orignConf)
            manager.isEnabled = true
            manager.saveToPreferences{
                if ($0 != nil){
//                    complete(nil);
//                    return;
                }
                manager.loadFromPreferences{
                    if $0 != nil{
                        print("loadFromPreferences",$0.debugDescription)
                        complete(nil);return;
                    }
                    self.addVPNStatusObserver()
                    complete(manager)
                }
            }

        }
    }

    func loadProviderManager(_ complete: @escaping (NETunnelProviderManager?) -> Void){
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) in
            if let managers = managers {
                if managers.count > 0 {
                    let manager = managers[0]
                    complete(manager)
                    return
                }
            }
            complete(nil)
        }
    }

}

// Actions
extension VpnManager{
    
    func connect(host: String?, port: Int?){
        self.proxyHost = host ?? self.proxyHost
        self.proxyPort = port ?? self.proxyPort
        
        self.loadAndCreatePrividerManager { (manager) in
            guard let manager = manager else{return}
            do{
                self.activeVPN = manager
                try manager.connection.startVPNTunnel()
            }catch let err{
                print("connect: ", err)
            }
        }
    }

    func disconnect() {
        if (activeVPN != nil) {
            print("stopVPNTunnel activeVPN")
            activeVPN?.connection.stopVPNTunnel()
            activeVPN = nil
            return
        }
        
        loadProviderManager{
            $0?.connection.stopVPNTunnel()
        }
    }
    
    func isRunning() -> Bool {
        return vpnStatus == VPNStatus.on
    }

}
