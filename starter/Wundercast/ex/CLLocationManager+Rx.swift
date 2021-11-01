//
//  CLLocationManager_Rx.swift
//  Wundercast
//
//  Created by wz on 2021/10/29.
//  Copyright © 2021 Razeware LLC. All rights reserved.
//

import Foundation
import CoreLocation
import RxCocoa
import RxSwift


extension CLLocationManager: HasDelegate {}

class RxCLLocationManagerDelegateProxy: DelegateProxy<CLLocationManager, CLLocationManagerDelegate>, DelegateProxyType, CLLocationManagerDelegate {
    
    weak public private(set) var locationManager: CLLocationManager?
    
    public init(locationManager: ParentObject) {
        self.locationManager = locationManager
        
        super.init(parentObject: locationManager, delegateProxy: RxCLLocationManagerDelegateProxy.self)
        
    }
    
    static func registerKnownImplementations() {
        register { RxCLLocationManagerDelegateProxy(locationManager: $0) }
    }
    
    
}

public extension Reactive where Base: CLLocationManager {
    var delegate: DelegateProxy<CLLocationManager, CLLocationManagerDelegate> {
        RxCLLocationManagerDelegateProxy.proxy(for: base)
    }
    
    var authorStatus: Observable<CLAuthorizationStatus> {
        delegate.methodInvoked(#selector(CLLocationManagerDelegate.locationManagerDidChangeAuthorization(_:))).map { pa in
            CLAuthorizationStatus(rawValue: pa[1] as! Int32)!
        }.startWith(base.authorizationStatus)
    }
    
    func getCurrentLocation() -> Observable<CLLocation> {
        let loc = authorStatus.filter {
               $0 == .authorizedAlways || $0 == .authorizedWhenInUse
        }.flatMap { _ in
            self.didUpdateLocations.compactMap(\.first)
        }.take(1).do(onDispose: {
            [weak base] in  base?.stopUpdatingLocation()
        })
        
        base.requestWhenInUseAuthorization()
        base.startUpdatingLocation()
        
        return loc
    }
    
    var didUpdateLocations: Observable<[CLLocation]> {
        delegate.methodInvoked(#selector(CLLocationManagerDelegate.locationManager(_:didUpdateLocations:))).map { pa in
            // 1 表示 第二个参数
            pa[1] as! [CLLocation]
        }
    }
    
    
}
