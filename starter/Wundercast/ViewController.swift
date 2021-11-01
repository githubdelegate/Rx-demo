/*
 * Copyright (c) 2014-2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import RxSwift
import RxCocoa
import SwiftyJSON
import CoreLocation
import MapKit

class ViewController: UIViewController {

  @IBOutlet weak var activityView: UIActivityIndicatorView!
  @IBOutlet weak var searchCityName: UITextField!
  @IBOutlet weak var tempLabel: UILabel!
  @IBOutlet weak var humidityLabel: UILabel!
  @IBOutlet weak var iconLabel: UILabel!
  @IBOutlet weak var cityNameLabel: UILabel!
    
   @IBOutlet weak var locBtn: UIButton!
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var mapBtn: UIButton!
    
    
 private let locationMgr = CLLocationManager()

 let bag = DisposeBag()
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.

    style()
      
    let searchInput = searchCityName.rx.controlEvent(.editingDidEndOnExit).map{ self.searchCityName.text ?? "" }.filter{ !$0.isEmpty }
      
      let txtsearch = searchInput
          .flatMapLatest { txt in
              ApiController.shared.currentWeather(city: txt)
                  .catchAndReturn(.empty)}
      
      
      
      let mapInput = mapView.rx.regionDidChangeAnimated.skip(1).takeLast(1).map { _ -> CLLocation in
          print(" did change region =  ")
         return  CLLocation(latitude: self.mapView.centerCoordinate.latitude, longitude: self.mapView.centerCoordinate.longitude)
      }
      
      let geoInput = locBtn.rx.tap.flatMapLatest { _ in
          self.locationMgr.rx.getCurrentLocation()
      }
      
      let geoSearch =  Observable.merge(mapInput, geoInput).flatMapLatest { location in
          ApiController.shared.currentWeather(at: location.coordinate).catchAndReturn(.empty)
      }      
  
      
      let search = Observable.merge(geoSearch, txtsearch).retry(when: { e in
          e.enumerated().flatMap { (attempt, error) -> Observable<Int> in
              if attempt >= 4 - 1 {
                  return Observable.error(error)
              }
              
              return Observable<Int>.timer(.seconds(attempt + 1), scheduler: MainScheduler.instance)
          }
      }).asDriver(onErrorJustReturn: .empty)
      
      search.map { "\($0.temperature) C"}.drive(tempLabel.rx.text).disposed(by: bag)
      search.map(\.icon).drive(iconLabel.rx.text).disposed(by: bag)
      search.map(\.cityName).drive(cityNameLabel.rx.text).disposed(by: bag)
      search.map{ "\($0.humidity) %" }.drive(humidityLabel.rx.text).disposed(by: bag)
      
      // 只要用户输入完成 就开始加载动画， 返回true， 请求结果完成就隐藏动画 false
      let running = Observable.merge(
        searchInput.map{ _ in true },
        geoInput.map({ _ in true }),
        mapInput.map({ _ in true }),
        search.map{ _ in false }.asObservable())
          .startWith(true)
          .asDriver(onErrorJustReturn: false)
      
      running.asObservable().subscribe { run in
          print(" runing--- \(run)")
      }.disposed(by: bag)
      
      running.skip(1).drive(activityView.rx.isAnimating).disposed(by: bag)
      
      running.drive(tempLabel.rx.isHidden).disposed(by: bag)
      running.drive(iconLabel.rx.isHidden).disposed(by: bag)
      running.drive(humidityLabel.rx.isHidden).disposed(by: bag)
      running.drive(cityNameLabel.rx.isHidden).disposed(by: bag)
      
      
      // mapView 部分
      mapBtn.rx.tap.subscribe { _ in
          self.mapView.isHidden.toggle()
      }
   
      /* 看下面代码 简单的语义理解的话就是
       等待请求的天气信息返回后-> 处理生成天气地理数据模型-> 把模型数据绑定到overlay UI上进行展示
       非常的清晰明了。 但是这些都是自定义实现的，不是Rx原生支持的，overlay 使用Mapviewde delegate 的话，需要写几个代理方法，通过自定义的Rx的封装 简单明了
       */
      mapView.rx.setDelegate(self).disposed(by: bag)
      search.map { weather in
          // 动态切换地图
          self.mapView.setRegion(MKCoordinateRegion(center: weather.coordinate, span: MKCoordinateSpanMake(0.8, 0.8)), animated: true)
          // 返回overlay地理数据
        return  weather.overlay()
      }.drive(mapView.rx.overlay).disposed(by: bag)
      
      
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    Appearance.applyBottomLine(to: searchCityName)
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: - Style

  private func style() {
    view.backgroundColor = UIColor.aztec
    searchCityName.textColor = UIColor.ufoGreen
    tempLabel.textColor = UIColor.cream
    humidityLabel.textColor = UIColor.cream
    iconLabel.textColor = UIColor.cream
    cityNameLabel.textColor = UIColor.cream
  }
}



extension ViewController : MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let overlay = overlay as? ApiController.Weather.Overlay else {
            return MKOverlayRenderer()
        }
        
        return ApiController.Weather.OverlayView(overlay: overlay, overlayIcon: overlay.icon)
    }
}
