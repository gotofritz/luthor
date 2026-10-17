import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
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

  @Test func syncFolderComesFromLuthorSyncDir() {
    let config = LuthorConfiguration(environment: ["LUTHOR_SYNC_DIR": "/Users/me/Dropbox/Luthor"], home: Self.home)

    #expect(config.syncDirectory == URL(fileURLWithPath: "/Users/me/Dropbox/Luthor"))
  }

  @Test(arguments: [[:], ["LUTHOR_SYNC_DIR": ""]])
  func syncFolderIsUnsetWithoutLuthorSyncDir(environment: [String: String]) {
    #expect(LuthorConfiguration(environment: environment, home: Self.home).syncDirectory == nil)
  }

  @Test func deviceNeedsItsOwnNameInASharedFolder() {
    let config = LuthorConfiguration(
      environment: ["LUTHOR_SYNC_DIR": "/d"], home: Self.home, hostName: "Fritz's MacBook")

    #expect(config.deviceID == DeviceID("Fritz's MacBook"))
  }

  @Test func deviceIDFromTheEnvironmentWinsOverTheHostName() {
    let config = LuthorConfiguration(
      environment: ["LUTHOR_SYNC_DIR": "/d", "LUTHOR_DEVICE_ID": "work"], home: Self.home, hostName: "Fritz's MacBook")

    #expect(config.deviceID == DeviceID("work"))
  }

  @Test func deviceStaysLocalWithoutASharedFolder() {
    let config = LuthorConfiguration(environment: [:], home: Self.home, hostName: "Fritz's MacBook")

    #expect(config.deviceID == DeviceID("local"))
  }

  @Test func logLivesInTheSharedFolderWhenThereIsOne() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let config = LuthorConfiguration(
      environment: ["LUTHOR_SYNC_DIR": dir.url.path, "LUTHOR_DEVICE_ID": "mac"], home: dir.file("home"))

    try config.makeEventLog().append([captured("t1", "buy milk")])

    #expect(try FileManager.default.contentsOfDirectory(atPath: dir.url.path) == ["events-mac.jsonl"])
    #expect(config.location.path == dir.url.path)
  }

  @Test func logIsOneFileWithoutASharedFolder() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let config = LuthorConfiguration(environment: ["LUTHOR_LOG": dir.file("tasks.jsonl").path], home: dir.file("home"))

    try config.makeEventLog().append([captured("t1", "buy milk")])

    #expect(try JSONLinesEventLog(fileURL: dir.file("tasks.jsonl")).readAll() == [captured("t1", "buy milk")])
    #expect(config.location == dir.file("tasks.jsonl"))
  }

  @Test func chosenDropboxPutsTheLogInItsFolder() {
    let dropbox = LogStorage(kind: .dropbox, dropboxFolder: URL(fileURLWithPath: "/Users/me/Dropbox/Luthor"))

    let config = LuthorConfiguration(environment: [:], home: Self.home, hostName: "desk", storage: dropbox)

    #expect(config.syncDirectory == URL(fileURLWithPath: "/Users/me/Dropbox/Luthor"))
    #expect(config.deviceID == DeviceID("desk"))
  }

  @Test func chosenHomeFolderKeepsTheDefaultLog() {
    let home = LogStorage(kind: .homeFolder, dropboxFolder: URL(fileURLWithPath: "/Users/me/Dropbox/Luthor"))

    let config = LuthorConfiguration(environment: [:], home: Self.home, storage: home)

    #expect(config.syncDirectory == nil)
    #expect(config.logURL == URL(fileURLWithPath: "/Users/me/.luthor/events.jsonl"))
  }

  @Test(arguments: ["LUTHOR_LOG", "LUTHOR_SYNC_DIR"])
  func theEnvironmentWinsOverTheChosenPlace(key: String) {
    let dropbox = LogStorage(kind: .dropbox, dropboxFolder: URL(fileURLWithPath: "/Users/me/Dropbox/Luthor"))

    let config = LuthorConfiguration(environment: [key: "/elsewhere"], home: Self.home, storage: dropbox)

    #expect(config.location == URL(fileURLWithPath: "/elsewhere"))
  }

  @Test func theEnvironmentSaysWhetherItSetsThePlace() {
    #expect(LuthorConfiguration.environmentSetsLocation(["LUTHOR_LOG": "/a"]))
    #expect(LuthorConfiguration.environmentSetsLocation(["LUTHOR_SYNC_DIR": "/a"]))
    #expect(!LuthorConfiguration.environmentSetsLocation(["LUTHOR_LOG": "", "LUTHOR_DEVICE_ID": "x"]))
  }
}
