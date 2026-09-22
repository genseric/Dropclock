import AppKit

class DragLineView: NSView {
  var startPoint: NSPoint = .zero
  var endPoint: NSPoint = .zero

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    let linePath = NSBezierPath()
    linePath.move(to: startPoint)
    linePath.line(to: endPoint)
    linePath.lineCapStyle = .round

    // White halo under a dark core keeps the line visible on light and dark backgrounds.
    NSColor.white.setStroke()
    linePath.lineWidth = 5.0
    linePath.stroke()

    NSColor.black.setStroke()
    linePath.lineWidth = 3.0
    linePath.stroke()
  }

  func update(start: NSPoint, end: NSPoint) {
    startPoint = start
    endPoint = end
    needsDisplay = true
    self.layer?.setNeedsDisplay()
  }
}
