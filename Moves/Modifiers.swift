import Cocoa
import Defaults

class Modifiers {
  typealias ChangeHandler = (Intention) -> Void

  let handleChange: ChangeHandler

  var onMonitors: [Any?] = []
  var offMonitors: [Any?] = []
  var eventTap: CFMachPort?
  var runLoopSource: CFRunLoopSource?

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

    setupEventTap()
  }

  func remove() {
    removeOffMonitors()
    removeOnMonitors()
    removeEventTap()
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

  private func setupEventTap() {
    let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

    let callback: CGEventTapCallBack = { _, type, event, userInfo in
      guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
      let modifiers = Unmanaged<Modifiers>.fromOpaque(userInfo).takeUnretainedValue()

      if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = modifiers.eventTap {
          CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passRetained(event)
      }

      modifiers.handleKeyEvent()
      return Unmanaged.passRetained(event)
    }

    let userInfo = Unmanaged.passUnretained(self).toOpaque()
    eventTap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .listenOnly,
      eventsOfInterest: CGEventMask(eventMask),
      callback: callback,
      userInfo: userInfo
    )

    guard let eventTap = eventTap else { return }

    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    guard let runLoopSource = runLoopSource else { return }

    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
  }

  private func removeEventTap() {
    if let runLoopSource = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    }
    if let eventTap = eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
    }
    eventTap = nil
    runLoopSource = nil
  }

  private func handleKeyEvent() {
    if pendingIntention != .idle && activationTimer != nil {
      DispatchQueue.main.async {
        self.cancelActivationTimer()
        self.pendingIntention = .idle
      }
    }
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
      // If already active, switch modes immediately without delay
      if intention != .idle {
        cancelActivationTimer()
        pendingIntention = newIntention
        intention = newIntention
      } else {
        scheduleActivation(for: newIntention)
      }
    }
  }

  private func localMonitor(_ event: NSEvent) -> NSEvent? {
    globalMonitor(event)
    return event
  }
}
