import Foundation
import LuthorDomain
import LuthorViewModels
import Testing

@Suite struct AppConfigurationTests {
  static let home = URL(fileURLWithPath: "/Users/me")

  @Test func logPathComesFromLuthorLog() {
    let config = AppConfiguration(environment: ["LUTHOR_LOG": "/tmp/tasks.jsonl"], home: Self.home)

    #expect(config.logURL == URL(fileURLWithPath: "/tmp/tasks.jsonl"))
  }

  @Test(arguments: [[:], ["LUTHOR_LOG": ""]])
  func logPathDefaultsToDotLuthorInHome(environment: [String: String]) {
    let config = AppConfiguration(environment: environment, home: Self.home)

    #expect(config.logURL == URL(fileURLWithPath: "/Users/me/.luthor/events.jsonl"))
  }

  @Test func deviceIDComesFromLuthorDeviceID() {
    let config = AppConfiguration(environment: ["LUTHOR_DEVICE_ID": "macbook"], home: Self.home)

    #expect(config.deviceID == DeviceID("macbook"))
  }

  @Test(arguments: [[:], ["LUTHOR_DEVICE_ID": ""]])
  func deviceIDDefaultsToLocal(environment: [String: String]) {
    let config = AppConfiguration(environment: environment, home: Self.home)

    #expect(config.deviceID == DeviceID("local"))
  }
}
