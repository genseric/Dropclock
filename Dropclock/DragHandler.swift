import AppKit
import SwiftUI

extension AppDelegate {

  internal func setupDrag(for button: NSStatusBarButton) {
    button.target = self
    button.action = #selector(statusItemPressed(_:))
    button.sendAction(on: [.leftMouseDown, .rightMouseDown])
  }

  // macOS 27 hands the app an instant mouseDown/mouseUp pair for a status item
  // press and swallows the drag, so a gesture recognizer never fires. Poll the
  // global mouse state instead and show the menu ourselves.
  @objc internal func statusItemPressed(_ sender: NSStatusBarButton) {
    guard let event = NSApp.currentEvent, event.type == .leftMouseDown,
      let window = sender.window
    else {
      // Deferred: opening the menu inside the button's mouseDown handler makes
      // the system swallow the next left press on the item.
      DispatchQueue.main.async { self.showStatusMenu() }
      return
    }
    beginDrag(button: sender, at: window.convertPoint(toScreen: event.locationInWindow))
  }

  internal func showStatusMenu() {
    guard let statusItem = statusItem, let button = statusItem.button else { return }
    statusItem.menu = statusMenu
    button.performClick(nil)
    statusItem.menu = nil
  }

  private func beginDrag(button: NSStatusBarButton, at pressLocation: NSPoint) {
    baseTime = Date()
    dragStartLocation = pressLocation
    dragPollTimer?.invalidate()
    let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
      self?.pollDrag(button: button)
    }
    // .common so it keeps firing inside NSButton's mouse-tracking loop on older macOS.
    RunLoop.main.add(timer, forMode: .common)
    dragPollTimer = timer
  }

  private func pollDrag(button: NSStatusBarButton) {
    guard let start = dragStartLocation else { return }
    let mouseLoc = NSEvent.mouseLocation
    let deltaX = abs(mouseLoc.x - start.x)
    let deltaY = abs(mouseLoc.y - start.y)
    let maxDelta = max(deltaX, deltaY)

    if NSEvent.pressedMouseButtons & 1 == 0 {
      endDrag(maxDelta: maxDelta)
      return
    }

    // Time Calculation Logic
    var calculatedInterval: TimeInterval = 0
    if maxDelta < SecondThreshold {
      removeDragTimerPanel()
      calculatedInterval = 0
    } else if maxDelta < ThirtySecondThreshold {
      let increments = Int(maxDelta - SecondThreshold) + 1
      calculatedInterval = TimeInterval(30 + increments)
    } else if maxDelta < MinuteThreshold {
      let increments = Int((maxDelta - ThirtySecondThreshold) / 5)
      calculatedInterval = TimeInterval(60 + increments * 30)
    } else {
      let increments = Int((maxDelta - MinuteThreshold) / 5)
      calculatedInterval = TimeInterval(300 + increments * 60)
    }

    dragTimeInterval = calculatedInterval
    endTime = baseTime.addingTimeInterval(dragTimeInterval)

    let displayText: String
    if calculatedInterval < 60 {
      displayText = "\(Int(calculatedInterval)) sec"
    } else if calculatedInterval < 300 {
      let minutes = Int(calculatedInterval) / 60
      let seconds = Int(calculatedInterval) - minutes * 60
      displayText = "\(minutes) min \(seconds) sec"
    } else {
      if calculatedInterval <= 3600 {
        let minutes = Int(calculatedInterval) / 60
        displayText = "\(minutes) min"
      } else {
        let hours = Int(calculatedInterval) / 3600
        let minutes = Int(Int(calculatedInterval) - hours * 3600) / 60
        displayText = "\(hours) hr \(minutes) min"
      }
    }

    if maxDelta >= SecondThreshold && dragTimerPanel == nil {
      createDragTimerPanel()
    }

    if dragTimerPanel != nil {
      let windowWidth = dragTimerPanel!.frame.width
      let adjustedOrigin = NSPoint(
        x: mouseLoc.x - (windowWidth / 2) - 10, y: mouseLoc.y)
      updateDragTimerWindow(
        withText: displayText, endTimeText: formatter.string(from: endTime!),
        atPoint: adjustedOrigin)
    }

    // Only draw the line once the cursor has left the menu bar.
    if dragLineView == nil, let menuBarBottom = button.window?.frame.minY,
      mouseLoc.y < menuBarBottom
    {
      createDragLine(button: button)
    }
    updateDragLine(button: button)
  }

  private func endDrag(maxDelta: CGFloat) {
    dragPollTimer?.invalidate()
    dragPollTimer = nil
    removeDragTimerPanel()
    removeDragLine()
    if dragTimeInterval > 0 {
      pendingTimerData = (startTime: Date(), duration: dragTimeInterval)
      showNameInputField()
    } else if maxDelta < SecondThreshold {
      // Plain click without a drag: open the menu, as before.
      DispatchQueue.main.async { self.showStatusMenu() }
    }
    dragTimeInterval = 0
    dragStartLocation = nil
    updateStatusIcon()
  }

  private func createDragLine(button: NSStatusBarButton) {
    guard let screen = NSScreen.main
    else { return }

    let buttonFrame = button.window!.frame
    let startPoint = NSPoint(x: buttonFrame.midX, y: buttonFrame.midY)
    let endPoint = NSEvent.mouseLocation

    // Create a new window
    dragLineWindow = NSWindow(
      contentRect: screen.frame, styleMask: .borderless, backing: .buffered,
      defer: false)
    dragLineWindow?.backgroundColor = .clear

    dragLineWindow?.ignoresMouseEvents = true
    dragLineWindow?.orderFrontRegardless()

    dragLineView = DragLineView(frame: screen.frame)
    dragLineView?.startPoint = startPoint
    dragLineView?.endPoint = endPoint
    dragLineWindow?.level = .statusBar
    dragLineView?.wantsLayer = true
    dragLineView?.layer?.zPosition = CGFloat(Float.greatestFiniteMagnitude)

    dragLineWindow?.contentView?.addSubview(dragLineView!)
    dragLineView?.update(start: startPoint, end: endPoint)
  }

  private func updateDragLine(button: NSStatusBarButton) {
    guard let lineView = dragLineView, NSScreen.main != nil
    else { return }

    let buttonFrame = button.window!.frame
    let startPoint = NSPoint(x: buttonFrame.midX, y: buttonFrame.midY)
    let endPoint = NSEvent.mouseLocation

    lineView.update(start: startPoint, end: endPoint)
  }

  private func removeDragLine() {
    DispatchQueue.main.async {
      self.dragLineView?.removeFromSuperview()
      self.dragLineView = nil
      self.dragLineWindow?.orderOut(nil)
      self.dragLineWindow = nil
    }
  }
}
