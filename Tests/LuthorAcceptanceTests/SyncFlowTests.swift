import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given two Macs sharing a Dropbox folder")
struct TwoMacSyncFlowTests {
  @Test("a task captured on one Mac shows on the other after it reloads")
  func capturedTaskReachesTheOtherMac() throws {
    let dropbox = try TemporaryDirectory()
    defer { dropbox.remove() }
    let desk = launchApp(sharing: dropbox.url, as: "desk")
    let laptop = launchApp(sharing: dropbox.url, as: "laptop")

    desk.capture("buy milk")
    laptop.reload()

    #expect(laptop.tasks.map(\.title) == ["buy milk"])
  }

  @Test("two Macs with the same host name still write their own files")
  func sameHostNameKeepsTheFilesApart() throws {
    let dropbox = try TemporaryDirectory()
    defer { dropbox.remove() }
    let work = launchApp(configuration: sharedConfiguration(dropbox, machineID: "aaaaaaaa-1111"))
    let home = launchApp(configuration: sharedConfiguration(dropbox, machineID: "bbbbbbbb-2222"))

    work.capture("call the bank")
    home.capture("buy milk")
    work.reload()
    home.reload()

    #expect(work.tasks.map(\.title).sorted() == ["buy milk", "call the bank"])
    #expect(home.tasks.map(\.title).sorted() == ["buy milk", "call the bank"])
    let files = try FileManager.default.contentsOfDirectory(atPath: dropbox.url.path).sorted()
    #expect(files == ["events-MacBook-aaaaaaaa.jsonl", "events-MacBook-bbbbbbbb.jsonl"])
  }

  @Test("completing it on the other Mac completes it on the first")
  func completionComesBack() throws {
    let dropbox = try TemporaryDirectory()
    defer { dropbox.remove() }
    let desk = launchApp(sharing: dropbox.url, as: "desk")
    let laptop = launchApp(sharing: dropbox.url, as: "laptop")
    desk.capture("buy milk")
    laptop.reload()

    laptop.selection = try laptop.task("buy milk")
    laptop.completeSelected()
    desk.reload()

    #expect(desk.tasks.isEmpty)
  }

  @Test("tasks captured on both Macs while apart are on both, in the same order, once the files meet")
  func offlineEditsConverge() throws {
    let deskFolder = try TemporaryDirectory()
    let laptopFolder = try TemporaryDirectory()
    defer {
      deskFolder.remove()
      laptopFolder.remove()
    }
    let desk = launchApp(sharing: deskFolder.url, as: "desk")
    let laptop = launchApp(sharing: laptopFolder.url, as: "laptop")

    // Both Macs capture a first task at the same Lamport count, each in its own copy of the folder.
    desk.capture("buy milk")
    laptop.capture("call mum")
    // Dropbox delivers each file to the other Mac.
    try FileManager.default.copyItem(
      at: deskFolder.file("events-desk.jsonl"), to: laptopFolder.file("events-desk.jsonl"))
    try FileManager.default.copyItem(
      at: laptopFolder.file("events-laptop.jsonl"), to: deskFolder.file("events-laptop.jsonl"))
    desk.reload()
    laptop.reload()

    #expect(Set(desk.tasks.map(\.title)) == ["buy milk", "call mum"])
    #expect(desk.tasks.map(\.title) == laptop.tasks.map(\.title))
  }

  @Test("each Mac writes only its own file, so the sync service never has a conflict to make")
  func eachMacWritesItsOwnFile() throws {
    let dropbox = try TemporaryDirectory()
    defer { dropbox.remove() }
    let desk = launchApp(sharing: dropbox.url, as: "desk")
    let laptop = launchApp(sharing: dropbox.url, as: "laptop")

    desk.capture("buy milk")
    laptop.capture("call mum")

    let names = try FileManager.default.contentsOfDirectory(atPath: dropbox.url.path).sorted()
    #expect(names == ["events-desk.jsonl", "events-laptop.jsonl"])
  }

  @Test("a Mac that opens the folder later sees everything written so far")
  func newMacSeesTheHistory() throws {
    let dropbox = try TemporaryDirectory()
    defer { dropbox.remove() }
    let desk = launchApp(sharing: dropbox.url, as: "desk")
    desk.capture("buy milk")
    desk.capture("call mum")

    let laptop = launchApp(sharing: dropbox.url, as: "laptop")

    #expect(Set(laptop.tasks.map(\.title)) == ["buy milk", "call mum"])
  }
}

/// The configuration of a Mac called "MacBook" that shares `folder` and has the given machine ID.
private func sharedConfiguration(_ folder: TemporaryDirectory, machineID: String) -> LuthorConfiguration {
  LuthorConfiguration(
    environment: ["LUTHOR_SYNC_DIR": folder.url.path], home: folder.file("home"), hostName: "MacBook",
    machineID: machineID)
}
