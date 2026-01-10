import Cocoa
import Defaults

class Modifiers {
  typealias ChangeHandler = (Intention) -> Void

  let handleChange: ChangeHandler

  var onMonitors: [Any?] = []
  var offMonitors: [Any?] = []
  var keyMonitors: [Any?] = []

  var pendingIntention: Intention = .idle
  var activationTimer: Timer?

  var intention: Intention = .idle {
    didSet { intentionChanged(oldValue: oldValue) }
  }

  init(changeHandler: @escaping ChangeHandler) {
    self.handleChange = changeHandler
  }

  deinit {
    remove()
  }

  func observe() {
    remove()

    onMonitors.append(contentsOf: [
      NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: self.globalMonitor),
      NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: self.localMonitor),
    ])

    keyMonitors.append(contentsOf: [
      NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: self.keyDownMonitor),
      NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: self.localKeyDownMonitor),
    ])
  }

  func remove() {
    removeOffMonitors()
    removeOnMonitors()
    removeKeyMonitors()
    cancelActivationTimer()
  }

  private func removeOnMonitors() {
    onMonitors.forEach { (monitor) in
      guard let m = monitor else { return }
      NSEvent.removeMonitor(m)
    }
    onMonitors = []
  }

  private func removeOffMonitors() {
    offMonitors.forEach { (monitor) in
      guard let m = monitor else { return }
      NSEvent.removeMonitor(m)
    }
    offMonitors = []
  }

  private func removeKeyMonitors() {
    keyMonitors.forEach { (monitor) in
      guard let m = monitor else { return }
      NSEvent.removeMonitor(m)
    }
    keyMonitors = []
  }

  private func cancelActivationTimer() {
    activationTimer?.invalidate()
    activationTimer = nil
  }

  private func intentionChanged(oldValue: Intention) {
    guard oldValue != intention else { return }

    if intention == .idle {
      removeOffMonitors()
    } else {
      setupOffMonitors()
    }

    handleChange(intention)
  }

  private func intentionFrom(_ flags: NSEvent.ModifierFlags) -> Intention {
    let mods = modsFromFlags(flags)

    if mods.isEmpty { return .idle }

    let moveMods = Defaults[.moveModifiers]
    let resizeMods = Defaults[.resizeModifiers]

    if !moveMods.isEmpty && mods == moveMods {
      return .move
    } else if !resizeMods.isEmpty && mods == resizeMods {
      return .resize
    } else {
      return .idle
    }
  }

  private func modsFromFlags(_ flags: NSEvent.ModifierFlags) -> Set<Modifier> {
    var mods: Set<Modifier> = Set()
    if flags.contains(.command) { mods.insert(.command) }
    if flags.contains(.option) { mods.insert(.option) }
    if flags.contains(.control) { mods.insert(.control) }
    if flags.contains(.shift) { mods.insert(.shift) }
    if flags.contains(.function) { mods.insert(.fn) }
    return mods
  }

  private func setupOffMonitors() {
    offMonitors.append(contentsOf: [
      NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: self.globalMonitor),
      NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: self.localMonitor),
    ])
  }

  private func scheduleActivation(for newIntention: Intention) {
    cancelActivationTimer()
    pendingIntention = newIntention

    let delay = Defaults[.activationDelay]
    if delay <= 0 {
      intention = newIntention
      return
    }

    activationTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
      guard let self = self else { return }
      self.intention = self.pendingIntention
    }
  }

  private func globalMonitor(_ event: NSEvent) {
    let newIntention = intentionFrom(event.modifierFlags)

    if newIntention == .idle {
      cancelActivationTimer()
      pendingIntention = .idle
      intention = .idle
    } else if newIntention != pendingIntention {
      scheduleActivation(for: newIntention)
    }
  }

  private func localMonitor(_ event: NSEvent) -> NSEvent? {
    globalMonitor(event)
    return event
  }

  private func keyDownMonitor(_ event: NSEvent) {
    if pendingIntention != .idle && activationTimer != nil {
      scheduleActivation(for: pendingIntention)
    }
  }

  private func localKeyDownMonitor(_ event: NSEvent) -> NSEvent? {
    keyDownMonitor(event)
    return event
  }
}
