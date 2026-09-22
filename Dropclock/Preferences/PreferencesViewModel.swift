import ServiceManagement
import SwiftUI

class PreferencesViewModel: ObservableObject {
  @Published var startAtLogin: Bool = false
  @Published var playAlarmSound: Bool = false
  @Published var selectedAlarmSound: String = ""
  @Published var availableAlarmSounds: [String] = []
  @Published var loopAlarmUntilStopped: Bool = false
  @Published var useCustomAlarmSound: Bool = false
  @Published var customAlarmSoundName: String = ""

  private struct Keys {
    static let playAlarmSound = "playAlarmSound"
    static let selectedAlarmSound = "selectedAlarmSound"
    static let loopAlarmUntilStopped = "loopAlarmUntilStopped"
    static let useCustomAlarmSound = "useCustomAlarmSound"
    static let customAlarmSoundBookmark = "customAlarmSoundBookmark"
    static let customAlarmSoundName = "customAlarmSoundName"
  }

  init() {
    loadPreferences()
    startAtLogin = SMAppService.mainApp.status == .enabled
  }

  func loadPreferences() {
    playAlarmSound = UserDefaults.standard.bool(forKey: Keys.playAlarmSound)
    selectedAlarmSound =
    UserDefaults.standard.string(forKey: Keys.selectedAlarmSound) ?? ""
    loopAlarmUntilStopped = UserDefaults.standard.bool(
      forKey: Keys.loopAlarmUntilStopped)
    useCustomAlarmSound = UserDefaults.standard.bool(
      forKey: Keys.useCustomAlarmSound)
    customAlarmSoundName = UserDefaults.standard.string(
      forKey: Keys.customAlarmSoundName) ?? ""
    refreshAvailableAlarmSounds()
  }

  func savePreferences() {
    UserDefaults.standard.set(playAlarmSound, forKey: Keys.playAlarmSound)
    UserDefaults.standard.set(selectedAlarmSound, forKey: Keys.selectedAlarmSound)
    UserDefaults.standard.set(
      loopAlarmUntilStopped, forKey: Keys.loopAlarmUntilStopped)
    UserDefaults.standard.set(
      useCustomAlarmSound, forKey: Keys.useCustomAlarmSound)
    UserDefaults.standard.set(
      customAlarmSoundName, forKey: Keys.customAlarmSoundName)
    updateLoginItem()
  }

  func refreshAvailableAlarmSounds() {
    availableAlarmSounds = SoundManager.shared.availableAlarmSounds()
    if !selectedAlarmSound.isEmpty
        && !availableAlarmSounds.contains(selectedAlarmSound)
    {
      selectedAlarmSound = availableAlarmSounds.first ?? ""
      savePreferences()
    } else if selectedAlarmSound.isEmpty {
      selectedAlarmSound = availableAlarmSounds.first ?? ""
    }
  }

  func displayName(for sound: String) -> String {
    URL(fileURLWithPath: sound).deletingPathExtension().lastPathComponent
  }

  func storeCustomAlarmSound(url: URL) {
    let startedAccess = url.startAccessingSecurityScopedResource()
    do {
      let bookmark = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil)
      DispatchQueue.main.async { [weak self] in
        UserDefaults.standard.set(
          bookmark, forKey: Keys.customAlarmSoundBookmark)
        self?.customAlarmSoundName = url.lastPathComponent
        self?.useCustomAlarmSound = true
        self?.savePreferences()
      }
    } catch {
      print("Failed to store custom alarm sound: \(error)")
    }
    if startedAccess {
      url.stopAccessingSecurityScopedResource()
    }
  }

  func updateLoginItem() {
    do {
      if startAtLogin {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      print(
        "Error \(startAtLogin ? "enabling" : "disabling") login item: \(error)")
      startAtLogin.toggle()
    }
  }
}
