import SwiftUI
import Combine
import UniformTypeIdentifiers

fileprivate extension View {
  @ViewBuilder
  func onChangeCompat<Value: Equatable>(_ value: Value, publisher: Published<Value>.Publisher, perform: @escaping (Value) -> Void) -> some View {
    if #available(macOS 14, *) {
      self.onChange(of: value) { newValue in
        perform(newValue)
      }
    } else {
      self.onReceive(publisher.dropFirst()) { newValue in
        perform(newValue)
      }
    }
  }

  @ViewBuilder
  func onChangeCompat<Value>(_ publisher: Published<Value>.Publisher, perform: @escaping (Value) -> Void) -> some View {
    self.onReceive(publisher.dropFirst(), perform: perform)
  }
}

enum PreferenceTab {
  case general
  case timers
}

struct PreferencesView: View {
  @StateObject private var viewModel = PreferencesViewModel()
  @State private var selectedTab: PreferenceTab = .general
  @State private var hoverStates: [PreferenceTab: Bool] = [:]
  @State private var isShowingSoundImporter: Bool = false

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        ForEach(
          [
            (tab: PreferenceTab.general, icon: "gearshape", label: "General"),
            (tab: PreferenceTab.timers, icon: "timer", label: "Timers"),
          ], id: \.tab
        ) { tabInfo in
          Button {
            selectedTab = tabInfo.tab
          } label: {
            ZStack {
              Color.clear
                .contentShape(Rectangle())
                .overlay(
                  Group {
                    if hoverStates[tabInfo.tab] ?? false {
                      Color.gray.opacity(0.1)
                    } else if selectedTab == tabInfo.tab {
                      Color.blue.opacity(0.2)
                    } else {
                      Color.clear
                    }
                  }
                )

              VStack(spacing: 4) {
                Image(systemName: tabInfo.icon)
                  .font(.system(size: 16))
                Text(tabInfo.label)
                  .font(.system(size: 10))
              }
              .padding(.vertical, 8)
            }
            .frame(height: 50)
            .frame(minWidth: 60)
            .foregroundColor(selectedTab == tabInfo.tab ? .blue : .gray)
          }
          .buttonStyle(BorderlessButtonStyle())
          .cornerRadius(8)
          .onHover { hover in
            hoverStates[tabInfo.tab] = hover
          }
        }
      }
      .padding(.horizontal)
      .padding(.top)
      ScrollView {
        VStack {
          switch selectedTab {
          case .general:
            generalSettingsView
          case .timers:
            timerSettingsView
          }
        }
        .padding()
      }
    }
    .onAppear {
      viewModel.loadPreferences()
    }
    .fileImporter(
      isPresented: $isShowingSoundImporter,
      allowedContentTypes: SoundManager.shared.allowedExtensions.compactMap {
        UTType(filenameExtension: $0)
      }
    ) { result in
      switch result {
      case .success(let url):
        viewModel.storeCustomAlarmSound(url: url)
      case .failure(let error):
        print("File import failed: \(error)")
      }
    }
  }

  var generalSettingsView: some View {
    VStack(spacing: 20) {
      SettingsSection(title: "General") {
        SettingsRow(
          title: "Start at Login",
          helpText: "Automatically start Dropclock when you log in to your Mac."
        ) {
          Toggle("", isOn: $viewModel.startAtLogin)
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            .frame(width: 40)
            .onChangeCompat(viewModel.startAtLogin, publisher: viewModel.$startAtLogin) { _ in
              viewModel.savePreferences()
            }
        }
      }
      .padding(.top, 10)
    }
  }

  var timerSettingsView: some View {
    VStack(spacing: 20) {
      SettingsSection(title: "Timers") {
        SettingsRow(
            title: "Play Alarm Sound",
            helpText:
              "When enabled, Dropclock plays an alarm sound as soon as a timer finishes."
          ) {
            Toggle("", isOn: $viewModel.playAlarmSound)
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            .frame(width: 40)
            .onChangeCompat(viewModel.playAlarmSound, publisher: viewModel.$playAlarmSound) { _ in
              viewModel.savePreferences()
            }
        }

        if viewModel.playAlarmSound {
          SettingsRow(
            title: "Keep playing until manually stopped",
            helpText:
              "Loops the alarm and keeps the finished timer in the list until you remove it."
          ) {
            Toggle("", isOn: $viewModel.loopAlarmUntilStopped)
              .toggleStyle(SwitchToggleStyle())
              .labelsHidden()
              .frame(width: 40)
              .onChangeCompat(viewModel.loopAlarmUntilStopped, publisher: viewModel.$loopAlarmUntilStopped) { _ in
                viewModel.savePreferences()
              }
          }

          SettingsRow(
            title: "Alarm Sound File",
            helpText:
              "Select one of the .mp3/.wav files that are part of the app."
          ) {
            VStack(alignment: .trailing, spacing: 6) {
              Toggle("Use custom sound file", isOn: $viewModel.useCustomAlarmSound)
                .toggleStyle(SwitchToggleStyle())
                .frame(width: 220, alignment: .trailing)
                .onChangeCompat(viewModel.useCustomAlarmSound, publisher: viewModel.$useCustomAlarmSound) { _ in
                  viewModel.savePreferences()
                }

              if viewModel.useCustomAlarmSound {
                HStack {
                  Text(
                    viewModel.customAlarmSoundName.isEmpty
                      ? "No file selected"
                      : viewModel.customAlarmSoundName
                  )
                  .foregroundColor(.secondary)
                  .lineLimit(1)
                  Button("Choose File…") {
                    isShowingSoundImporter = true
                  }
                }
              } else {
                if viewModel.availableAlarmSounds.isEmpty {
                  Text("No sound files found")
                    .foregroundColor(.secondary)
                    .frame(width: 180, alignment: .trailing)
                } else {
                  Picker("", selection: $viewModel.selectedAlarmSound) {
                    ForEach(viewModel.availableAlarmSounds, id: \.self) { sound in
                      Text(viewModel.displayName(for: sound)).tag(sound)
                    }
                  }
                  .pickerStyle(MenuPickerStyle())
                  .frame(width: 180, alignment: .trailing)
                  .onChangeCompat(viewModel.selectedAlarmSound, publisher: viewModel.$selectedAlarmSound) { _ in
                    viewModel.savePreferences()
                  }
                }
              }
            }
          }
        }
      }
      .padding(.bottom, 20)
    }
  }
}
