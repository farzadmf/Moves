import Cocoa
import Defaults

class FloatingIndicator {
  static let shared = FloatingIndicator()

  private var window: NSWindow?

  func show(for intention: Intention, appName: String?) {
    hide()

    let size = CGFloat(Defaults[.indicatorSize])
    let fontSize = CGFloat(Defaults[.indicatorFontSize])
    let padding: CGFloat = 16

    // Calculate label size first
    var labelActualHeight: CGFloat = 0
    var labelWidth: CGFloat = size
    if let appName = appName {
      let tempLabel = NSTextField(labelWithString: appName)
      tempLabel.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
      tempLabel.sizeToFit()
      labelActualHeight = tempLabel.frame.height + 12
      labelWidth = max(tempLabel.frame.width + 20, size)
    }

    let totalHeight = size + (appName != nil ? padding + labelActualHeight : 0)
    let totalWidth = max(size + 40, labelWidth + 20)

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: totalWidth, height: totalHeight),
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    window.level = .floating
    window.backgroundColor = .clear
    window.isOpaque = false
    window.ignoresMouseEvents = true
    window.hasShadow = false

    let container = NSView(frame: NSRect(x: 0, y: 0, width: totalWidth, height: totalHeight))

    let background = NSView(frame: NSRect(x: (totalWidth - size) / 2, y: labelActualHeight + (appName != nil ? padding : 0), width: size, height: size))
    background.wantsLayer = true
    background.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
    background.layer?.cornerRadius = size * 0.15

    let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: size, height: size))
    let symbolName = intention == .move ? "arrow.up.and.down.and.arrow.left.and.right" : "arrow.up.left.and.arrow.down.right"
    if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
      let config = NSImage.SymbolConfiguration(pointSize: size * 0.6, weight: .bold)
      imageView.image = image.withSymbolConfiguration(config)
      imageView.contentTintColor = .white
    }
    background.addSubview(imageView)
    container.addSubview(background)

    if let appName = appName {
      let labelContainer = NSView(frame: NSRect(x: (totalWidth - labelWidth) / 2, y: 0, width: labelWidth, height: labelActualHeight))
      labelContainer.wantsLayer = true
      labelContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
      labelContainer.layer?.cornerRadius = 4

      let label = NSTextField(labelWithString: appName)
      label.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
      label.textColor = .white
      label.backgroundColor = .clear
      label.isBezeled = false
      label.isEditable = false
      label.alignment = .center
      label.sizeToFit()
      label.frame = NSRect(
        x: (labelWidth - label.frame.width) / 2,
        y: (labelActualHeight - label.frame.height) / 2,
        width: label.frame.width,
        height: label.frame.height
      )
      labelContainer.addSubview(label)
      container.addSubview(labelContainer)
    }

    window.contentView = container

    if let screen = NSScreen.main {
      let screenFrame = screen.visibleFrame
      let x = screenFrame.midX - totalWidth / 2
      let y = screenFrame.midY - totalHeight / 2
      window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    window.orderFrontRegardless()
    self.window = window
  }

  func hide() {
    window?.orderOut(nil)
    window = nil
  }
}
