# Bus

[![Platform](http://img.shields.io/badge/platform-ios-blue.svg?style=flat
)](https://developer.apple.com/iphone/index.action)
[![Language](http://img.shields.io/badge/language-swift-brightgreen.svg?style=flat
)](https://developer.apple.com/swift)
[![License](http://img.shields.io/badge/license-MIT-lightgrey.svg?style=flat
)](http://mit-license.org)

iOS Bluetooth LE framework for  communicating with Credo CPR-Band



## Requirements

iOS 9.0+ 


## Installation

1. Add this framework to the project you want to use. (Check "copy items if needed")

2. Open the project editor Select your project among your "targets" and add this framework to "Embedded Binaries" if it is not already there.

3. Capabilities tap - Background Modes - Check "Uses Bluetooth LE accessories"

4. In your info.plist on project target add "Privacy - Bluetooth Peripheral Usage Description"  with a String description


## Basic usage

The basic procedure for communicating with the CPR-Band using this framework is as follows.

1. User will need to find the CPR-Band using the BLE scanning. The user selects the CPR-Band among the Bluetooth devices discovered through the BLE scanning.

2. The selected bands are automatically connected to the app and switched to the "ready" mode.

3. The Ready state can be switched to another state (Practicing, Evaluating), and the following functions can also be performed.
    - Change the correct range of compression depth values during CPR chest compressions.
    - Change the band name
    - Initialize both of the above steps
    - Turn off the band
    
4. In Practicing and Evaluating mode, the band sends pressure depth and user wrist angle information to the app. The characteristics of the transmitted data are as follows.
    - Real-time wrist angle value of band user (unit: angle, range: -90 ~ 90, period: about 100ms)
    - CPR Depth information per pressure on chest compressions. (Unit: cm, Range: 0 ~, period: About 500ms at actual pressing) 

5. Change to Ready state to end data reception.

The main code for using the above function is "Bus class" which is the role of managing communication with the band, and "NotManager class" which is the function of transmitting the information received from the band to the UI of the app.

### Bus initialization

An instance of the Bus class can be used to initiate a connection with the band.
Import Bus to your AppDelegate and create instance of it after "application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool" function.

```
import UIKit
import Bus

var bus: Bus!

func application(_ application: UIApplication, didFinishLaunchingWithOptionas launchOptions: [UIApplicationLaunchOptionKey: Any]?) -> Bool {

    // If you want your Bluetooth connection to the band to stay in your app's background for a long time, enter true as the keepAlive value.
    self.bus = Bus(keepAlive: true)
    
    return true
}

```


### NotManager initialization

You can create a "NotManager" instance to receive information that the bus passes to the UI during communication with the band.

```

import UIKit
import NotManager

class ViewController: UIViewController, GattUICallback {

    var notManager: NotManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // It uses the GattUICallback protocol to asynchronously and optionally receive multiple pieces of information. 
        self.notManager = NotManager(gattUICallback: self)
        
        // An enum value, NotKey, is used to categorize each piece of information that is delivered.
        // Register NotKey by selecting the type of notification you want to receive.
        self.notManager.register(NotKey.unavail, NotKey.bluetoothPower, NotManager.scanning)
        
        // If you want to receive all notifications, call this function.
        // self.notManager.registerAll()
        
    }

}

```

### GattUICallback

A protocol for asynchronously receiving band status and data information.
Except for callbacks to see if the device supports Bluetooth service, the sub-methods are optional.

```
// Currently device can not use Bluetooth service
func GattCallback_UnavailToUse(reason: String)

// When the mobile's Bluetooth power state changes
func GattCallback_BluetoothPowerChanged(isOff: Bool){}

// BLE scan status changes
func GattCallback_Scannnig(started: Bool){}

// Find new device through BLE scan
func GattCallback_ScanDevice(found: BT_Device){}

// The target band's connection status is changed
func GattCallback_BandConnectionChanged(mac: String, to: Status){}

// The target band's mode status is changed
func GattCallback_BandModeChanged(mac: String, to: Status){}

// Remaining battery capacity of the target band (percent)
func GattCallback_BatteryReceived(mac: String, percentage: Double){}

// Distance to target band (m)
func GattCallback_DistanceChanegd(mac: String, distance: Double){}

// The depth of the chest compressions when the band user performs CPR
func GattCallback_PeakReceived(mac: String, scale: Double){}

// The wrist angle of band user
func GattCallback_AngleReceived(mac: String, angle: Int){}

// The value of the command that the app successfully sent to the band
func GattCallback_CMDSent(mac: String, cmd: CMD){}

// The value of new name that the app successfully sent to the band
func GattCallback_NewNameSent(mac: String, newName: String){}

// App fails to transfer data to band
func GattCallback_DataSendFail(mac: String, data: Any?){}

```



### Find CPR-Band(s) 

The part where BLE scans to find the band is as follows.

```
{
    let isScanningNow: Bool = self.delegate.bus.isScanning

    delegate.bus.scanControl(start: !isScanningNow)
}
...

func GattCallback_Scanning(started: Bool) {

    print("Is the app start scanning? : \(started)")
}

func GattCallback_ScanDevice(found: BT_Device) {
    
    print("Found new Bluetooth device - name: \(found.name), MAC: \(found.mac), distance: \(found.distance)")
}


```

### Select a band 

Among the Bluetooth devices searched earlier, the user selects the desired CPR-Band
(Usually the band name starts with CPR-. You can select one band or up to six bands.)


```

var band: CPR_Band?
var bands: [CPR_Band]?

{
    // If you select a band
    self.band = self.delegate.bus.selectBand(by "MAC_ADDRESS")
    
    // If you want to select multiple bands to connect
    self.bands = self.delegate.bus.selectBands(by [MAC_ADDRESS_STRING_ARRAY])
}


```
If the band is selected normally using the MAC address, the corresponding CPR_Band value (or array) is returned.
The CPR_Band value is a struct that contains basic information such as band name and MAC address, but the value is not updated according to the actual band status.
Use Bus instance's  "func getBand(mac: String?) -> CPR_Band?" or  "func getBands(macs: [String]?) -> [String: CPR_Band]?" to read current copied value. 



### Band connection and mode change

The connection status or mode of the band uses the "Status" value of the enum type. 
To control the "Status" of a band or to obtain a "Status" value that changes in real time, use the following methods.

```
{
    
    // Request a connection using a single Mac address
    self.delegate.bus.connectBy(mac: "MAC_ADDRESS")
    
    // Request to disconnect using a single Mac address
    self.delegate.bus.disconnectBy(mac: "MAC_ADDRESS")
}

...

func GattCallback_BandConnectionChanged(mac: String, to: Status) {
    print("Band connection status was changed to : \(to)")
}

```

To change the mode(or name) of the band:
```
{
    // CMD includes call, ready, practice, evaluationStart, newRange, newName, reset, and powerOff.
    self.delegate.bus.sendCMD(mac: "MAC_ADDRESS", cmd: .practice)
        // *call: Call the band -> All the LEDs on the band are on and the buzzer starts to ring.
        // ready: Change the band's mode to ready (default mode)
        // practice: Change the mode of the band to practicing -> The LED of the band turns on gradually according to the movement of the band, the band transmits data to the app
        // evaluationStart: Change the mode of the band to evaluating -> all of the band's LEDs are off, but the band sends data to the app
        // *newRange: A command to inform the band that a new correct compression depth range will be transmitted
        // *newName: A command to inform the band that a new name for the band will be sent
        // *reset: A command that initializes the name of the band and the correct compression range value
        // *powerOff: Turn off the band
        
        // * Marked commands are only sent if the band is in ready mode
        
        
    // change CPR-Band name
    self.delegate.bus.changeBandName(mac: "MAC_ADDRESS", newName: "NEW_NAME")
}

...

func GattCallback_BandModeChanged(mac: String, to: Status) {
    print("Band mode was changed to : \(to)")
}


func GattCallback_CMDSent(mac: String, cmd: CMD) {
    print("CMD: \(cmd) was successfully sent to the band")
}


func GattCallback_NewNameSent(mac: String, newName: String) {
    print("Band name was changed to: \(newName)")
}


```
You can check whether the command was transmitted correctly by using  "GattCallback_CMDSent(mac: String, cmd: CMD)"
* GattCallback_CMDSent(mac: String, cmd: CMD)
    - If cmd is .newRange, this means that all of the correct compression range values were successfully transmitted.

You can check whether the command band status changes correctly by using  "GattCallback_BandModeChanged(mac: String, to: Status)"
 


### Receiving data

Basically, there are two kinds of data that the band sends to the app: the angle of the user's wrist and the depth of the pressure.
In addition, the Bus instance periodically transmits the battery level information of the band and the distance value to the band. If you want to use them, you can use the following methods of GattUICallback.

```

func GattCallback_BatteryReceived(mac: String, percentage: Double) {
    print("Battery rest: \(percentage)%")
}

func GattCallback_DistanceChanegd(mac: String, distance: Double) {
    print("distance: \(distance)m")
}


func GattCallback_AngleReceived(mac: String, angle: Int) {
    print("Band user current wrist angle: \(angle) degree")
}

func GattCallback_PeakReceived(mac: String, scale: Double) {
    print("Peak depth value of current Compression: \(scale)cm" )
}

```



## Advanced usage

In addition to communicating with the CPR-Band, there are some additional settings available through the Bus instance.


### Change settings

```
/**
Hold CPR data comes from bands or not

    - parameter hold: true -> CPR data will be stored at *CPR_Band.Compressions*
*/
public func holdCPRData(hold: Bool) {
    self.setting.HOLD_MEMORY.value = hold
}


/**
Interval to read CPR-Band battery remains(default: 60.0sec)

    - parameter interval: value of interval(sec)
*/
public func setBattRead(interval: Double) {
    self.setting.INTERVAL_READ_BATT.value = interval
}

/**
Interval to read RSSI value for calculating distance with the band

    - parameter interval: value of interval
*/
public func setRSSIRead(interval: Double) {
    self.setting.INTERVAL_READ_RSSI.value = interval
}



/**
Buffer size for eliminating noise from band user wrist angle value which comes from about per 100ms (default 5)

    - parameter size: buffer size
*/
public func setAngleMovingAveragingBuffer(size: Int) {
    self.setting.ANGLE_MAVERAGE_BUF_SIZE.value = size
    self.gattManager.buf_size = size
}



```



