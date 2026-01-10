import AXSwift
import Cocoa
import Defaults
import Settings
import Sparkle

extension Settings.PaneIdentifier {
  static let general = Self("general")
  static let excludes = Self("excludes")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  @IBOutlet var sparkle: SPUStandardUpdaterController!

  let statusItem = StatusItem()
  let windowHandler = WindowHandler()

  lazy var preferencesWindowController = SettingsWindowController(
    panes: [
      GeneralPreferencesController(),
      ExcludesViewController(),
    ], style: .segmentedControl
  )

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    Task {
      for await value in Defaults.updates(.showInMenubar) {
        if value {
          self.statusItem.enable()
        } else {
          self.statusItem.disable()
        }
      }
    }

    statusItem.handleCheckForUpdates = { self.sparkle.checkForUpdates(nil) }
    statusItem.handlePreferences = { self.showPreferences() }

    let modifiers = Modifiers { self.windowHandler.intention = $0 }

    Task {
      for await value in Defaults.updates(.accessibilityEnabled) {
        if value {
          modifiers.observe()
        } else {
          modifiers.remove()
        }
      }
    }

    DistributedNotificationCenter.default.addObserver(
      forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: nil
    ) { _ in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        Defaults[.accessibilityEnabled] = AXSwift.checkIsProcessTrusted()
      }
    }

    Defaults[.accessibilityEnabled] = AXSwift.checkIsProcessTrusted(prompt: true)

    if Defaults[.showPrefsOnLaunch] {
      showPreferences()
    }
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    preferencesWindowController.show()
  }

  func showPreferences() {
    preferencesWindowController.show()
    NSApp.activate(ignoringOtherApps: true)
  }

  // MARK: - URLs

  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      handleURL(url)
    }
  }

  private func handleURL(_ url: URL) {
    guard url.scheme == "moves" else { return }

    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let host = url.host
    else { return }

    let queryItems = components.queryItems ?? []

    switch host {
    case "template":
      let templateName = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      guard !templateName.isEmpty else { return }

      guard let templateType = TemplateType(rawValue: templateName) else { return }
      ActiveWindow.applyTemplate(templateType)

    case "custom":
      let positionString: String
      let command = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

      if let positionParam = queryItems.first(where: { $0.name == "position" })?.value,
        !positionParam.isEmpty
      {
        positionString = positionParam
      } else if !command.isEmpty {
        positionString = command
      } else {
        positionString = "topLeft"
      }

      // Convert position string to WindowPosition enum
      let position: WindowPosition
      if let validPosition = WindowPosition(rawValue: positionString) {
        position = validPosition
      } else {
        // Default to topLeft if invalid position provided
        position = .topLeft
      }

      // Get screen dimensions for relative calculations
      let screenRect = NSScreen.main?.visibleFrame ?? .zero

      var width: CGFloat? = nil
      if let absoluteWidth = queryItems.first(where: { $0.name == "absoluteWidth" })?.value.flatMap(
        { CGFloat(Double($0) ?? 0) }),
        absoluteWidth > 0
      {
        width = absoluteWidth
      } else if let relativeWidth = queryItems.first(where: { $0.name == "relativeWidth" })?.value
        .flatMap({ Double($0) }),
        relativeWidth > 0
      {
        width = CGFloat(relativeWidth) * screenRect.width
      }

      var height: CGFloat? = nil
      if let absoluteHeight = queryItems.first(where: { $0.name == "absoluteHeight" })?.value
        .flatMap({ CGFloat(Double($0) ?? 0) }),
        absoluteHeight > 0
      {
        height = absoluteHeight
      } else if let relativeHeight = queryItems.first(where: { $0.name == "relativeHeight" })?.value
        .flatMap({ Double($0) }),
        relativeHeight > 0
      {
        height = CGFloat(relativeHeight) * screenRect.height
      }

      // Calculate X offset - try absoluteXOffset first, then relativeXOffset
      var xOffset: CGFloat = 0
      if let absoluteXOffset = queryItems.first(where: { $0.name == "absoluteXOffset" })?.value
        .flatMap({ CGFloat(Double($0) ?? 0) })
      {
        xOffset = absoluteXOffset
      } else if let relativeXOffset = queryItems.first(where: { $0.name == "relativeXOffset" })?
        .value.flatMap({ Double($0) })
      {
        xOffset = CGFloat(relativeXOffset) * screenRect.width
      }

      // Calculate Y offset - try absoluteYOffset first, then relativeYOffset
      var yOffset: CGFloat = 0
      if let absoluteYOffset = queryItems.first(where: { $0.name == "absoluteYOffset" })?.value
        .flatMap({ CGFloat(Double($0) ?? 0) })
      {
        yOffset = absoluteYOffset
      } else if let relativeYOffset = queryItems.first(where: { $0.name == "relativeYOffset" })?
        .value.flatMap({ Double($0) })
      {
        yOffset = CGFloat(relativeYOffset) * screenRect.height
      }

      // Position the window
      ActiveWindow.customPosition(
        position: position, width: width, height: height, xOffset: xOffset, yOffset: yOffset)

    default:
      // Handle legacy paths or invalid URLs
      break
    }
  }
}
