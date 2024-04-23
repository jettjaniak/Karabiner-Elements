import Combine
import Foundation
import SwiftUI

private func callback() {
  Task { @MainActor in
    LibKrbn.ConnectedDevices.shared.update()
  }
}

extension LibKrbn {
  final class ConnectedDevices: ObservableObject {
    static let shared = ConnectedDevices()
    static let didConnectedDevicesUpdate = Notification.Name("didConnectedDevicesUpdate")

    private var watching = false

    @Published var connectedDevices: [ConnectedDevice] = []

    // We register the callback in the `watch` method rather than in `init`.
    // If libkrbn_register_*_callback is called within init, there is a risk that `init` could be invoked again from the callback through `shared` before the initial `init` completes.

    public func watch() {
      if watching {
        return
      }
      watching = true

      libkrbn_enable_connected_devices_monitor()
      libkrbn_register_connected_devices_updated_callback(callback)
      libkrbn_enqueue_callback(callback)
    }

    public func update() {
      var newConnectedDevices: [LibKrbn.ConnectedDevice] = []

      let size = libkrbn_connected_devices_get_size()
      for i in 0..<size {
        var buffer = [Int8](repeating: 0, count: 32 * 1024)
        var transport = ""
        var manufacturerName = ""
        var productName = ""
        var deviceAddress = ""

        if libkrbn_connected_devices_get_descriptions_transport(i, &buffer, buffer.count) {
          transport = String(cString: buffer)
        }

        if libkrbn_connected_devices_get_descriptions_manufacturer(i, &buffer, buffer.count) {
          manufacturerName = String(cString: buffer)
            .replacingOccurrences(of: "[\r\n]", with: " ", options: .regularExpression)
        }
        if manufacturerName == "" {
          manufacturerName = "No manufacturer name"
        }

        if libkrbn_connected_devices_get_descriptions_product(i, &buffer, buffer.count) {
          productName = String(cString: buffer)
            .replacingOccurrences(of: "[\r\n]", with: " ", options: .regularExpression)
        }
        if productName == "" {
          if transport == "FIFO" {
            productName = "Apple Internal Keyboard / Trackpad"
          } else {
            productName = "No product name"
          }
        }

        if libkrbn_connected_devices_get_device_address(i, &buffer, buffer.count) {
          deviceAddress = String(cString: buffer)
        }

        let connectedDevice = LibKrbn.ConnectedDevice(
          index: i,
          manufacturerName: manufacturerName,
          productName: productName,
          transport: transport,
          vendorId: libkrbn_connected_devices_get_vendor_id(i),
          productId: libkrbn_connected_devices_get_product_id(i),
          deviceAddress: deviceAddress,
          isKeyboard: libkrbn_connected_devices_get_is_keyboard(i),
          isPointingDevice: libkrbn_connected_devices_get_is_pointing_device(i),
          isGamePad: libkrbn_connected_devices_get_is_game_pad(i),
          isBuiltInKeyboard: libkrbn_connected_devices_get_is_built_in_keyboard(i),
          isBuiltInTrackpad: libkrbn_connected_devices_get_is_built_in_trackpad(i),
          isBuiltInTouchBar: libkrbn_connected_devices_get_is_built_in_touch_bar(i),
          isAppleDevice: libkrbn_connected_devices_is_apple(i),
          isKarabinerVirtualHidDevice: libkrbn_connected_devices_is_karabiner_virtual_hid_device(i)
        )

        newConnectedDevices.append(connectedDevice)
      }

      connectedDevices = newConnectedDevices

      NotificationCenter.default.post(
        name: ConnectedDevices.didConnectedDevicesUpdate,
        object: nil
      )
    }
  }
}
