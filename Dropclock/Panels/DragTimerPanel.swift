import AppKit
import SwiftUI

class DragTimerPanel {
  private var panel: NSPanel?
  private var timerLabel: NSTextField?
  private var endTimeLabel: NSTextField?

  var frame: NSRect {
    return panel?.frame ?? .zero
  }

  func show() {
    cleanup()

    guard let screen = NSScreen.main else { return }
    let windowSize = NSSize(width: 120, height: 50)
    let windowOrigin = NSPoint(
      x: screen.frame.midX - windowSize.width / 2,
      y: screen.frame.midY - windowSize.height / 2)

    let panel = NSPanel(
      contentRect: NSRect(origin: windowOrigin, size: windowSize),
      styleMask: [.nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    panel.isFloatingPanel = true
    panel.level = .popUpMenu
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isMovable = false
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true

    let backgroundView = NSView(frame: panel.contentView!.bounds)
    backgroundView.wantsLayer = true
    backgroundView.layer?.backgroundColor = NSColor.black.cgColor
    backgroundView.layer?.cornerRadius = 8
    backgroundView.layer?.masksToBounds = true
    backgroundView.layer?.borderWidth = 1
    backgroundView.layer?.borderColor =
      NSColor.white.withAlphaComponent(0.2).cgColor

    let stackView = NSStackView()
    stackView.orientation = .vertical
    stackView.alignment = .centerX
    stackView.spacing = 3
    stackView.translatesAutoresizingMaskIntoConstraints = false

    timerLabel = NSTextField(labelWithString: "00:00")
    timerLabel?.font = NSFont.systemFont(ofSize: 16, weight: .medium)
    timerLabel?.textColor = .white
    timerLabel?.alignment = .center
    timerLabel?.isBordered = false
    timerLabel?.drawsBackground = false

    endTimeLabel = NSTextField(labelWithString: "at 12:00")
    endTimeLabel?.font = NSFont.systemFont(ofSize: 13)
    endTimeLabel?.textColor = .white
    endTimeLabel?.alignment = .center
    endTimeLabel?.isBordered = false
    endTimeLabel?.drawsBackground = false

    stackView.addArrangedSubview(timerLabel!)
    stackView.addArrangedSubview(endTimeLabel!)

    backgroundView.addSubview(stackView)
    panel.contentView?.addSubview(backgroundView)

    NSLayoutConstraint.activate([
      stackView.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
      stackView.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
      stackView.widthAnchor.constraint(
        equalTo: backgroundView.widthAnchor, multiplier: 0.9),
    ])

    panel.orderFront(nil)
    self.panel = panel
  }

  func update(timerText: String, endTimeText: String, at point: NSPoint) {
    DispatchQueue.main.async {
      self.timerLabel?.stringValue = timerText
      self.endTimeLabel?.stringValue = "at: \(endTimeText)"

      let windowWidth = self.panel?.frame.width ?? 0
      let windowHeight = self.panel?.frame.height ?? 0
      let newOrigin = NSPoint(
        x: point.x - windowWidth / 2,
        y: point.y - windowHeight / 2)
      self.panel?.setFrameOrigin(newOrigin)
    }
  }

  func cleanup() {
    panel?.close()
    panel = nil
  }
}
