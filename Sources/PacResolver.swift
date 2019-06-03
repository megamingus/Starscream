//
//  PacResolver.swift
//  Starscream
//
//  Created by Mingo Llorente on 03/06/2019.
//  Copyright © 2019 Vluxe. All rights reserved.
//


import Foundation

class PACResolver {
    
    init(scriptURL: URL) {
        self.scriptURL = scriptURL
    }
    
    let scriptURL: URL
    
    enum Result {
        case error(error: CFError)
        case proxies(proxies: CFArray)
    }
    typealias Callback = (_ result: Result) -> Void
    
    private struct Request {
        let targetURL: URL
        let callback: Callback
    }
    private var requests: [Request] = []
    private var runLoopSource: CFRunLoopSource?
    
    func resolve(targetURL: URL, callback: @escaping Callback) {
        DispatchQueue.main.async {
            let wasEmpty = self.requests.isEmpty
            self.requests.append(Request(targetURL: targetURL, callback: callback))
            if wasEmpty {
                self.startNextRequest()
            }
        }
    }
    
    private func startNextRequest() {
        guard let request = self.requests.first else {
            return
        }
        
        var context = CFStreamClientContext()
        context.info = Unmanaged.passRetained(self).toOpaque()
        //        let pacURL = URL(string: self.scriptURL) as! URL
        let pacURL = self.scriptURL
        
        let rls = CFNetworkExecuteProxyAutoConfigurationURL(pacURL as CFURL,
                                                            request.targetURL as CFURL,
                                                            { (info, proxies, error) in
                                                                let obj = Unmanaged<PACResolver>.fromOpaque(info).takeRetainedValue()
                                                                if let error = error {
                                                                    obj.resolveDidFinish(result: .error(error: error))
                                                                } else {
                                                                    obj.resolveDidFinish(result: .proxies(proxies: proxies))
                                                                }
        },
                                                            &context
            ).takeUnretainedValue()
        assert(self.runLoopSource == nil)
        self.runLoopSource = rls
        CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, .defaultMode)
    }
    
    private func resolveDidFinish(result: Result) {
        CFRunLoopSourceInvalidate(self.runLoopSource!)
        self.runLoopSource = nil
        let request = self.requests.removeFirst()
        
        request.callback(result)
        
        self.startNextRequest()
    }
}
