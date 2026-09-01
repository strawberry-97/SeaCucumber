import Foundation
import NetworkExtension
import Network
import Libbox
import os.log

/// 实现 Libbox 需要的平台接口 + 命令服务回调
final class ExtensionPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol, LibboxCommandServerHandlerProtocol {
    private let tunnel: PacketTunnelProvider
    private var networkSettings: NEPacketTunnelNetworkSettings?
    private var nwMonitor: NWPathMonitor?

    init(_ tunnel: PacketTunnelProvider) {
        self.tunnel = tunnel
    }

    func reset() {
        networkSettings = nil
        nwMonitor?.cancel()
        nwMonitor = nil
    }

    // MARK: - TUN

    func openTun(_ options: (any LibboxTunOptionsProtocol)?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        guard let options, let ret0_ else {
            throw NSError(domain: "tunnel", code: 0, userInfo: [NSLocalizedDescriptionKey: "nil options"])
        }

        try runBlocking { [self] in
            let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

            if options.getAutoRoute() {
                settings.mtu = NSNumber(value: options.getMTU())

                // DNS（sing-box 会返回一个用于 DNS 劫持的地址）
                let dnsBox = try options.getDNSServerAddress()
                if !dnsBox.value.isEmpty {
                    settings.dnsSettings = NEDNSSettings(servers: [dnsBox.value])
                }

                // IPv4
                var ipv4Addr: [String] = []
                var ipv4Mask: [String] = []
                var it = options.getInet4Address()
                while it?.hasNext() ?? false {
                    if let p = it?.next() {
                        ipv4Addr.append(p.address())
                        ipv4Mask.append(p.mask())
                    }
                }
                let ipv4Settings = NEIPv4Settings(addresses: ipv4Addr, subnetMasks: ipv4Mask)

                var ipv4Routes: [NEIPv4Route] = []
                if let routeIt = options.getInet4RouteAddress(), routeIt.hasNext() {
                    while routeIt.hasNext() {
                        if let p = routeIt.next() {
                            ipv4Routes.append(NEIPv4Route(destinationAddress: p.address(), subnetMask: p.mask()))
                        }
                    }
                } else {
                    ipv4Routes.append(NEIPv4Route.default())
                }
                var ipv4Excludes: [NEIPv4Route] = []
                var exclIt = options.getInet4RouteExcludeAddress()
                while exclIt?.hasNext() ?? false {
                    if let p = exclIt?.next() {
                        ipv4Excludes.append(NEIPv4Route(destinationAddress: p.address(), subnetMask: p.mask()))
                    }
                }
                ipv4Settings.includedRoutes = ipv4Routes
                ipv4Settings.excludedRoutes = ipv4Excludes
                settings.ipv4Settings = ipv4Settings

                // IPv6
                var ipv6Addr: [String] = []
                var ipv6Prefix: [NSNumber] = []
                var it6 = options.getInet6Address()
                while it6?.hasNext() ?? false {
                    if let p = it6?.next() {
                        ipv6Addr.append(p.address())
                        ipv6Prefix.append(NSNumber(value: p.prefix()))
                    }
                }
                let ipv6Settings = NEIPv6Settings(addresses: ipv6Addr, networkPrefixLengths: ipv6Prefix)
                var ipv6Routes: [NEIPv6Route] = []
                if let routeIt6 = options.getInet6RouteAddress(), routeIt6.hasNext() {
                    while routeIt6.hasNext() {
                        if let p = routeIt6.next() {
                            ipv6Routes.append(NEIPv6Route(destinationAddress: p.address(), networkPrefixLength: NSNumber(value: p.prefix())))
                        }
                    }
                } else {
                    ipv6Routes.append(NEIPv6Route.default())
                }
                var ipv6Excludes: [NEIPv6Route] = []
                var exclIt6 = options.getInet6RouteExcludeAddress()
                while exclIt6?.hasNext() ?? false {
                    if let p = exclIt6?.next() {
                        ipv6Excludes.append(NEIPv6Route(destinationAddress: p.address(), networkPrefixLength: NSNumber(value: p.prefix())))
                    }
                }
                ipv6Settings.includedRoutes = ipv6Routes
                ipv6Settings.excludedRoutes = ipv6Excludes
                settings.ipv6Settings = ipv6Settings
            }

            networkSettings = settings
            try await tunnel.setTunnelNetworkSettings(settings)
        }

        // 取 TUN 文件描述符交给 Go 核心
        if let fd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            ret0_.pointee = fd
            return
        }
        let fd = LibboxGetTunnelFileDescriptor()
        if fd != -1 {
            ret0_.pointee = fd
        } else {
            throw NSError(domain: "tunnel", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法获取 TUN 文件描述符"])
        }
    }

    // MARK: - 平台探测

    func usePlatformAutoDetectControl() -> Bool { false }

    func autoDetectControl(_ fd: Int32) throws {}

    func useProcFS() -> Bool { false }

    func findConnectionOwner(
        _ ipProtocol: Int32,
        sourceAddress: String?,
        sourcePort: Int32,
        destinationAddress: String?,
        destinationPort: Int32
    ) throws -> LibboxConnectionOwner {
        LibboxConnectionOwner()
    }

    // MARK: - 默认接口监听

    func startDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {
        guard let listener else { return }
        let monitor = NWPathMonitor()
        nwMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            self?.updateDefaultInterface(listener, path)
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    private func updateDefaultInterface(_ listener: any LibboxInterfaceUpdateListenerProtocol, _ path: Network.NWPath) {
        guard path.status == .satisfied, let iface = path.availableInterfaces.first else {
            listener.updateDefaultInterface("", interfaceIndex: -1, isExpensive: false, isConstrained: false)
            return
        }
        listener.updateDefaultInterface(
            iface.name,
            interfaceIndex: Int32(iface.index),
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained
        )
    }

    func closeDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {
        nwMonitor?.cancel()
        nwMonitor = nil
    }

    func getInterfaces() throws -> any LibboxNetworkInterfaceIteratorProtocol {
        guard let monitor = nwMonitor else {
            return NetworkInterfaceArray([])
        }
        let path = monitor.currentPath
        guard path.status == .satisfied else {
            return NetworkInterfaceArray([])
        }
        var interfaces: [LibboxNetworkInterface] = []
        for iface in path.availableInterfaces {
            let ni = LibboxNetworkInterface()
            ni.name = iface.name
            ni.index = Int32(iface.index)
            switch iface.type {
            case .wifi: ni.type = LibboxInterfaceTypeWIFI
            case .cellular: ni.type = LibboxInterfaceTypeCellular
            case .wiredEthernet: ni.type = LibboxInterfaceTypeEthernet
            default: ni.type = LibboxInterfaceTypeOther
            }
            interfaces.append(ni)
        }
        return NetworkInterfaceArray(interfaces)
    }

    // MARK: - 其他平台接口

    func underNetworkExtension() -> Bool { true }

    func includeAllNetworks() -> Bool { false }

    func readWIFIState() -> LibboxWIFIState? { nil }

    func systemCertificates() -> (any LibboxStringIteratorProtocol)? { nil }

    func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? { nil }

    func clearDNSCache() {}

    func send(_ notification: LibboxNotification?) throws {}

    // MARK: - 命令服务回调

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        LibboxSystemProxyStatus()
    }

    func serviceReload() throws {}

    func serviceStop() throws {
        tunnel.stopService()
    }

    func setSystemProxyEnabled(_ enabled: Bool) throws {}

    func writeDebugMessage(_ message: String?) {
        if let message {
            os_log(.debug, "%{public}@", message)
        }
    }
}

/// 简单的迭代器封装
final class NetworkInterfaceArray: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    private var iterator: IndexingIterator<[LibboxNetworkInterface]>
    private var nextValue: LibboxNetworkInterface?

    init(_ array: [LibboxNetworkInterface]) {
        iterator = array.makeIterator()
    }

    func hasNext() -> Bool {
        nextValue = iterator.next()
        return nextValue != nil
    }

    func next() -> LibboxNetworkInterface? {
        nextValue
    }
}
