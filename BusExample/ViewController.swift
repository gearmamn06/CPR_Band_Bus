//
//  ViewController.swift
//  BusExample
//
//  Created by ParkHyunsoo on 2018. 4. 19..
//  Copyright © 2018년 ParkHyunsoo. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Toast_Swift

import Bus

class ViewController: UIViewController, GattUICallback, UICollectionViewDelegate, UICollectionViewDataSource {

    
    // Basic UI components
    @IBOutlet weak var findBtn: UIButton!
    @IBOutlet weak var scanStatusLabel: UILabel!
    @IBOutlet weak var selectBtn: UIButton!
    @IBOutlet weak var connectBtn: UIButton!
    @IBOutlet weak var disconnectBtn: UIButton!
    @IBOutlet weak var bandStatusLabel: UILabel!
    @IBOutlet weak var BandNmLabel: UILabel!
    @IBOutlet weak var batteryLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var macLabel: UILabel!
    @IBOutlet weak var readyBtn: UIButton!
    @IBOutlet weak var resetBtn: UIButton!
    @IBOutlet weak var powerOffBtn: UIButton!
    @IBOutlet weak var practiceBtn: UIButton!
    @IBOutlet weak var evaluationBtn: UIButton!
    @IBOutlet weak var angleValueLabel: UILabel!
    @IBOutlet weak var angleReceivedTimeLabel: UILabel!
    @IBOutlet weak var depthLabel: UILabel!
    @IBOutlet weak var depthTimeLabel: UILabel!
    @IBOutlet weak var changeRangeBtn: UIButton!
    @IBOutlet weak var changeNameBtn: UIButton!
    @IBOutlet weak var changeBattIntervalBtn: UIButton!
    @IBOutlet weak var changeDistanceIntervalBtn: UIButton!
    
    /// To show found bluetooth device list during the BLE scan
    @IBOutlet weak var collectionView: UICollectionView!
    
    
    let delegate = UIApplication.shared.delegate as! AppDelegate
    
    /// Instance for receiving data from the Bus
    var notManager: NotManager!

    
    /// Found devices during BLE scan
    var foundDevs = Variable<[BT_Device]>([BT_Device]())
    
    /// Selected device MAC address among the foundDevs
    var selectedDevMac: String? {
        didSet {
            self.selectBtn?.isEnabled = !(self.selectedDevMac?.isEmpty ?? true)
            self.selectBtn?.alpha = self.selectBtn?.isEnabled ?? false ? 1.0 : 0.5
        }
    }
    
    /// Target band
    var cprBand: CPR_Band?
    /// The status value of the target CPR_Band
    var mainStatus = Variable<Status>(Status.disconnected)
    
    let disposeBag = DisposeBag()

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.bindButtons()
        
        // Available and diavailable buttons will be changed depending on mainStatus value
        self.mainStatus.asObservable().subscribe( { ev in
            guard let s = ev.element else { return }
            
            let btnsAll = [self.findBtn!, self.selectBtn!, self.connectBtn!, self.disconnectBtn!, self.readyBtn!, self.resetBtn!, self.powerOffBtn!, self.practiceBtn!, self.evaluationBtn!, self.changeRangeBtn!, self.changeNameBtn!, self.changeBattIntervalBtn!, self.changeDistanceIntervalBtn!]
            var disableBtns = btnsAll
            switch s {
            case .disconnected:
                // Only findBtn, connectBtn and selectBtn are allowed in this case
                disableBtns = self.removeBtn(btns: disableBtns, bs: self.findBtn, self.connectBtn, self.selectBtn)
            case .connected:
                // Only findBtn and disconnectBtn are allowed in this case
                disableBtns = self.removeBtn(btns: disableBtns, bs: self.findBtn, self.disconnectBtn)
            case .ready:
                // Other buttons are available except findBtn, selectBtn, connectBtn and readyBtn
                disableBtns = [ self.findBtn, self.selectBtn, self.connectBtn, self.readyBtn ]
            case .practicing:
                // Only readyBtn and evaluationBtn are allowed in this case
                disableBtns = self.removeBtn(btns: disableBtns, bs: self.readyBtn, self.evaluationBtn)
            case .evaluating:
                // Only readyBtn and practiceBtn are allowed in this case
                disableBtns = self.removeBtn(btns: disableBtns, bs: self.readyBtn, self.practiceBtn)
            default: break
            }
            
            for b in disableBtns {
                b.isEnabled = false
                b.alpha = 0.5
            }
            
            let ableBtns = btnsAll.filter{ !disableBtns.contains($0) }
            for b in ableBtns {
                b.isEnabled = true
                b.alpha = 1.0
            }
            
            self.bandStatusChnaged()
        }).disposed(by: self.disposeBag)
        
        // Reload collectionview if there are any changes in foundDevs.value
        self.foundDevs.asObservable().subscribe( { ev in
            self.collectionView.reloadData()
        })
        
        self.connectBtn.alpha = 0.5; self.connectBtn.isEnabled = false
        self.selectBtn.alpha = 0.5; self.selectBtn.isEnabled = false
    
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        if self.notManager == nil {
            self.notManager = NotManager(gattUICallback: self)
        }
        
        
        // register all notifications
        self.notManager.registerAll()
        
        // register notifications which user wants to receive,
        //self.notManager.register(keys: .unavail, .bluetoothPower, .scanning, .scanFound, ...)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.notManager?.unregister()
        self.notManager = nil
    }

    
    
    //// scan and prepare band examples ////
    
    
    func findBtnClicked() {
        self.findBtn.rx.tap.bind {
            
            // bus.isScanning indicating current BLE scanning status
            let to = !self.delegate.bus.isScanning
            
            // toggle BLE scanning
            self.delegate.bus.scanControl(start: to)
            if to {
                // if BLE scanning starts, initialize foundDevs and selectedDevMac
                self.foundDevs.value.removeAll()
                self.selectedDevMac = nil
            }
        }
    }
    
    func GattCallback_UnavailToUse(reason: String) {
        self.view.makeToast("Can't use bluetooth service, reason: \(reason)")
    }
    
    
    func GattCallback_Scannnig(started: Bool) {
        self.findBtn.setTitle(started ? "Stop Scanning" : "Find CPR-Band", for: .normal)
        self.scanStatusLabel.text = "BLE Scan status: \(started)"
    }
    
    
    func GattCallback_ScanDevice(found: BT_Device) {
        if !self.foundDevs.value.contains(found) {
            self.foundDevs.value.append(found)
        }
    }
    
    // collection view shows found bluetooth devices during the BLE scanning
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.foundDevs.value.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FoundDevCell", for: indexPath) as! FoundDevCell
        let dev = self.foundDevs.value[indexPath.row]
        cell.bandNmLabel.text = dev.name
        cell.distanceLabel.text = "Distance: " + (dev.distance == nil ?  "--" : String(format: "%.1f", dev.distance!) + "m")
        cell.bandNmLabel.textColor = dev.mac == self.selectedDevMac ? UIColor.blue : UIColor(red: 67.0/255.0, green: 67.0/255.0, blue: 67.0/255.0, alpha: 1)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let row = indexPath.row
        let dev = self.foundDevs.value[row]
        var indexes = [IndexPath(row: indexPath.row, section: 0)]
        if let dev = (self.foundDevs.value.filter{ $0.mac == self.selectedDevMac }.first), let index = self.foundDevs.value.index(of: dev) {
            indexes.append(IndexPath(row: index, section: 0))
        }
        self.selectedDevMac = dev.mac == self.selectedDevMac ? nil : dev.mac
        self.collectionView.reloadItems(at: indexes)
    }
    
    
    func selectBtnClicked() {
        self.selectBtn.rx.tap.bind {
            if let m = self.selectedDevMac {
                // Select the band by MAC address and get the corresponding CPR_Band value
                self.cprBand = self.delegate.bus.selectBand(by: m)
                
                // If user want to select multiple bands, use this function.
                // let bands = self.delegate.bus.selectBand(by: [MAC_ADDRESS_STRING_ARRAY])
                
                self.selectedDevMac = nil
                self.foundDevs.value.removeAll()
                self.bandStatusChnaged()
            }
        }
    }
    
    
    func connectionControlBtnsClicked() {
        
        self.connectBtn.rx.tap.bind {
            guard let m = self.cprBand?.mac else { return }
            
            // Connect using MAC address
            self.delegate.bus.connectBy(mac: m)
            
            // If user want to connect multiple bands, use this function.
            // self.delegate.bus.connectBy(macs: [MAC_ADDRESS_STRING_ARRAY])
        }
        
        self.disconnectBtn.rx.tap.bind{
            
            // Disconnect the band using MAC address(nil: disconnect all)
            self.delegate.bus.disconnectBy(mac: self.cprBand?.mac)
            
            // If user want to disconnect multiple bands, use this function.
            // self.delegate.bus.disconnectBy(macs: [MAC_ADDRESS_STRNIG_ARRAY])
        }
    }
    
    // Band connection status value will be returned
    func GattCallback_BandConnectionChanged(mac: String, to: Status) {
        self.mainStatus.value = to
        
    }
    
    func bandStatusChnaged() {
        self.BandNmLabel.text = "Band name: " + (self.cprBand?.name == nil ? "" : self.cprBand!.name)
        self.macLabel.text = "MAC address(identifier uuidString): \n" + (self.cprBand?.mac == nil ? "" : self.cprBand!.mac)
        self.bandStatusLabel.text = "Current Band Status: \(self.mainStatus.value)"
    }
    
    func GattCallback_BatteryReceived(mac: String, percentage: Double) {
        self.batteryLabel.text = "Battery(%): \(Int(percentage))"
    }
    
    func GattCallback_DistanceChanegd(mac: String, distance: Double) {
        self.distanceLabel.text = "Distance(m): " + String(format: "%.1f", distance)
    }
    
    
    
    
    ///// Band mode control and Data receiving
    
    
    // send CMD to the band for changing it's mode
    func bandModeControlBtnsClicked() {
        
        self.readyBtn.rx.tap.bind {
            guard let m = self.cprBand?.mac else {return}
            self.delegate.bus.sendCMD(mac: m, cmd: .ready)
            // self.delegate.bus.sendCMD(macs: [MAC_ADDRESS_STRING_ARRAY], cmd: cmd)
        }
        
        self.practiceBtn.rx.tap.bind {
            guard let m = self.cprBand?.mac else {return}
            self.delegate.bus.sendCMD(mac: m, cmd: .practice)
        }
        
        self.evaluationBtn.rx.tap.bind {
            guard let m = self.cprBand?.mac else {return}
            self.delegate.bus.sendCMD(mac: m, cmd: .evaluationStart)
        }
    }
    
    // It means the CMD data successfully transmitted to the band
    func GattCallback_CMDSent(mac: String, cmd: CMD) {
        print("CMD: \(cmd) sent to device MAC: \(mac)")
        if cmd == .newRange {
            self.view.makeToast("Successfully sent new correct compression depth range values!")
        }
    }
    
    // It means Band mode is changed
    func GattCallback_BandModeChanged(mac: String, to: Status) {
        self.mainStatus.value = to
    }

    
    func GattCallback_AngleReceived(mac: String, angle: Int) {
        self.angleValueLabel.text = "\(angle)"
        self.angleReceivedTimeLabel.text = "\(Date())"
    }
    
    func GattCallback_PeakReceived(mac: String, scale: Double) {
        self.depthLabel.text = String(format: "%.1f", scale)
        self.depthTimeLabel.text = "\(Date())"
    }
    
    
    
    /// Basic band setting and control
    
    
    func bandControlBtnsClicked() {
        
        self.resetBtn.rx.tap.bind {
            guard let m = self.cprBand?.mac else { return }
            self.delegate.bus.sendCMD(mac: m, cmd: .reset)
        }
        
        self.powerOffBtn.rx.tap.bind {
            guard let m = self.cprBand?.mac else { return }
            self.delegate.bus.sendCMD(mac: m, cmd: .powerOff)
        }
        
        self.changeRangeBtn.rx.tap.bind {
            guard let m = self.cprBand?.mac else { return }
            self.delegate.bus.sendNewRange(mac: m, min: 5.0, max: 7.0)
        }
        
        self.changeNameBtn.rx.tap.bind {
            guard let m = self.cprBand?.mac else { return }
            self.delegate.bus.changeBandName(mac: m, newName: "CPR-NewName")
        }
        
    }
    
    
    
    /// Change AppSetting
    
    
    func appSettingcontroltnsClicked() {
        
        self.changeBattIntervalBtn.rx.tap.bind {
            self.delegate.bus.setBattRead(interval: 4.0)
        }
        
        self.changeDistanceIntervalBtn.rx.tap.bind {
            self.delegate.bus.setRSSIRead(interval: 10.0)
        }
    }
    
    
    func GattCallback_NewNameSent(mac: String, newName: String) {
        self.BandNmLabel.text = newName
    }
    
    func GattCallback_DataSendFail(mac: String, data: Any?) {
        print("send data(\(data))to the band(MAC: \(mac) is fail..")
    }
    
    
    
    
    // functions
    
    func bindButtons() {
        self.findBtnClicked()
        self.selectBtnClicked()
        self.connectionControlBtnsClicked()
        self.bandModeControlBtnsClicked()
        self.bandControlBtnsClicked()
        self.appSettingcontroltnsClicked()
    }
    

    func removeBtn(btns: [UIButton], bs: UIButton...) -> [UIButton] {
        var sender = btns
        for b in bs {
            if let index = sender.index(of: b) {
                sender.remove(at: index)
            }
        }
        return sender
    }
}




