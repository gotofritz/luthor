import Foundation
import LuthorDomain
import LuthorStore
import Testing

@Suite struct LuthorConfigurationTests {
  static let home = URL(fileURLWithPath: "/Users/me")

  @Test func logPathComesFromLuthorLog() {
    let config = LuthorConfiguration(environment: ["LUTHOR_LOG": "/tmp/tasks.jsonl"], home: Self.home)

    #expect(config.logURL == URL(fileURLWithPath: "/tmp/tasks.jsonl"))
  }

  @Test(arguments: [[:], ["LUTHOR_LOG": ""]])
  func logPathDefaultsToDotLuthorInHome(environment: [String: String]) {
    let config = LuthorConfiguration(environment: environment, home: Self.home)

    #expect(config.logURL == URL(fileURLWithPath: "/Users/me/.luthor/events.jsonl"))
  }

  @Test func deviceIDComesFromLuthorDeviceID() {
    let config = LuthorConfiguration(environment: ["LUTHOR_DEVICE_ID": "macbook"], home: Self.home)

    #expect(config.deviceID == DeviceID("macbook"))
  }

  @Test(arguments: [[:], ["LUTHOR_DEVICE_ID": ""]])
  func deviceIDDefaultsToLocal(environment: [String: String]) {
    let config = LuthorConfiguration(environment: environment, home: Self.home)

    #expect(config.deviceID == DeviceID("local"))
  }

  @Test func viewComesFromLuthorView() {
    let config = LuthorConfiguration(environment: ["LUTHOR_VIEW": "Work"], home: Self.home)

    #expect(config.viewName == "Work")
  }

  @Test(arguments: [[:], ["LUTHOR_VIEW": ""]])
  func viewIsUnsetWithoutLuthorView(environment: [String: String]) {
    #expect(LuthorConfiguration(environment: environment, home: Self.home).viewName == nil)
  }
}
