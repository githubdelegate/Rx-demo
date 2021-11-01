//
//  MapView+Rx.swift
//  Wundercast
//
//  Created by wz on 2021/10/29.
//  Copyright © 2021 Razeware LLC. All rights reserved.
//

import Foundation
import CoreLocation
import CoreLocationUI
import UIKit
import MapKit
import RxCocoa
import RxSwift

extension MKMapView : HasDelegate {
}

class RxMKMapViewDelegateProxy: DelegateProxy<MKMapView, MKMapViewDelegate> , DelegateProxyType, MKMapViewDelegate {
    
    weak public private(set) var mapView: MKMapView?
    
    public init(mapView: ParentObject) {
        self.mapView = mapView
        
        super.init(parentObject: mapView, delegateProxy: RxMKMapViewDelegateProxy.self)
    }
    
    static func registerKnownImplementations() {
        register { RxMKMapViewDelegateProxy(mapView: $0) }
    }
    
    
}

public extension Reactive where Base: MKMapView {
    var delegate: DelegateProxy<MKMapView, MKMapViewDelegate> {
        RxMKMapViewDelegateProxy.proxy(for: base)
    }
    
    func setDelegate(_ delegate: MKMapViewDelegate) -> Disposable {
        RxMKMapViewDelegateProxy.installForwardDelegate(delegate, retainDelegate: false, onProxyForObject: self.base)
    }
    
    var overlay: Binder<MKOverlay> {
        Binder(base) {
            mapView, overlay in
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlays([overlay])
        }
    }
}
