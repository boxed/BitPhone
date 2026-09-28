//
//  BitMacApp.swift
//  BitMac
//
//  The macOS version of the bit: a borderless, transparent, floating window
//  in which only the bit itself is visible, so the animation appears to be
//  drawn on top of the other windows on screen.
//

import AppKit
import MetalKit

@main
enum BitMacMain {
    // NSApplicationMain does not instantiate the delegate when there is no
    // main nib, so wire it up explicitly.
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: BitWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = Self.makeMainMenu()

        // Set the icon directly as well: LaunchServices caches the iconless
        // registration of previous builds aggressively.
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }

        let size: CGFloat = 480
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: size, height: size)
        let contentRect = NSRect(x: screen.midX - size / 2, y: screen.midY - size / 2,
                                 width: size, height: size)

        let window = BitWindow(contentRect: contentRect, styleMask: .borderless,
                               backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = BitView(frame: NSRect(origin: .zero, size: contentRect.size))
        // Remember position and size. The window isn't .resizable, so the
        // autosave only restores the position on its own; force the size.
        window.setFrameUsingName("bit", force: true)
        window.setFrameAutosaveName("bit")
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private static func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About Bit",
                                   action: #selector(showAbout),
                                   keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Bit",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q"))
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(appMenuItem)
        return mainMenu
    }

    @objc private func showAbout() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.paragraphSpacing = 6

        let credits = NSAttributedString(
            string: """
            Click the bit to ask it a question.
            Drag to spin it.
            Hold the mouse button down on it for a moment \
            to pick it up, then drag to move it.
            Control-drag up or down to resize it.
            """,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle,
            ])
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// A borderless window that can still become key, so it receives mouse and
/// keyboard events.
final class BitWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }
}

/// The Metal view showing the bit. Dragging spins it, and clicking asks it a
/// question. Holding the mouse button still for a moment picks the bit up
/// (it dips, then pops slightly larger); dragging then moves the window, and
/// releasing puts it down. Control-dragging up and down resizes the bit.
final class BitView: MTKView {
    /// The bit never reaches past this fraction of the view's half-size;
    /// outside that circle the window lets clicks fall through to whatever
    /// is underneath.
    private static let hitRadiusFraction: CGFloat = 0.8

    private static let holdToPickUpInterval: TimeInterval = 0.5
    private static let dragDeadZone: CGFloat = 3

    private let renderer: Renderer
    private var dragged = false
    private var mouseIsDown = false
    private var pickedUp = false
    private var pendingDragDistance: CGFloat = 0
    private var resizeCenter: NSPoint?
    private var clickThroughTimer: Timer?
    private var holdTimer: Timer?
    private var lastMouseLocation: NSPoint?
    private var occlusionObserver: NSObjectProtocol?

    init(frame: NSRect) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let renderer = Renderer(device: device)
        else { preconditionFailure("Metal is not available") }
        self.renderer = renderer

        super.init(frame: frame, device: device)

        colorPixelFormat = Renderer.colorPixelFormat
        depthStencilPixelFormat = Renderer.depthPixelFormat
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        // The renderer's animation is time-based, so a lower frame rate only
        // reduces smoothness (and CPU use), not the animation's speed. 30 fps
        // is plenty for the wobble and roughly halves the rendering cost.
        preferredFramesPerSecond = 30
        wantsLayer = true
        layer?.isOpaque = false
        delegate = renderer

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.updateClickThrough()
        }
        timer.tolerance = 0.02  // let the OS coalesce the wake-ups
        clickThroughTimer = timer
    }

    deinit {
        clickThroughTimer?.invalidate()
        holdTimer?.invalidate()
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Rendering is pointless while the window is not visible at all (on
    /// another space, or fully covered), so pause it there.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
            self.occlusionObserver = nil
        }
        guard let window else { return }
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window, queue: .main
        ) { [weak self] _ in
            guard let self, let window = self.window else { return }
            self.isPaused = !window.occlusionState.contains(.visible)
        }
    }

    /// The window takes mouse events only while the cursor is over the bit,
    /// so the transparent parts of the window behave as if they were not
    /// there.
    private func updateClickThrough() {
        guard let window, !mouseIsDown else { return }
        // The answer only changes when the pointer moves (the window moves
        // and resizes only with the mouse held down), so a stationary mouse
        // makes this tick free.
        let location = NSEvent.mouseLocation
        guard location != lastMouseLocation else { return }
        lastMouseLocation = location
        let mouse = convert(window.convertPoint(fromScreen: location), from: nil)
        let radius = min(bounds.width, bounds.height) / 2 * Self.hitRadiusFraction
        let overBit = hypot(mouse.x - bounds.midX, mouse.y - bounds.midY) <= radius
        window.ignoresMouseEvents = !overBit
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        mouseIsDown = true
        dragged = false
        pendingDragDistance = 0
        holdTimer = Timer.scheduledTimer(withTimeInterval: Self.holdToPickUpInterval, repeats: false) { [weak self] _ in
            self?.pickUp()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            holdTimer?.invalidate()
            holdTimer = nil
            dragged = true
            if resizeCenter == nil, let frame = window?.frame {
                resizeCenter = NSPoint(x: frame.midX, y: frame.midY)
            }
            resizeWindow(by: -event.deltaY)
            return
        }

        if pickedUp {
            guard let window else { return }
            let origin = window.frame.origin
            window.setFrameOrigin(NSPoint(x: origin.x + event.deltaX,
                                          y: origin.y - event.deltaY))
            return
        }

        // A small dead zone so the jitter of a finger held still doesn't
        // cancel the pickup (or twitch the bit).
        if !dragged {
            pendingDragDistance += hypot(event.deltaX, event.deltaY)
            guard pendingDragDistance > Self.dragDeadZone else { return }
            holdTimer?.invalidate()
            holdTimer = nil
            dragged = true
        }

        renderer.drag(deltaX: Float(event.deltaX), deltaY: Float(event.deltaY))
    }

    override func mouseUp(with event: NSEvent) {
        holdTimer?.invalidate()
        holdTimer = nil
        resizeCenter = nil
        if pickedUp {
            putDown()
        } else if !dragged {
            renderer.tap()
        }
        dragged = false
        mouseIsDown = false
        // The window may have moved or resized under the pointer; make the
        // next tick recompute click-through even if the mouse stays put.
        lastMouseLocation = nil
    }

    /// Control-dragging up grows the window (and with it the bit), dragging
    /// down shrinks it. The frame is always derived from the center captured
    /// when the gesture started; recentering incrementally would accumulate
    /// rounding drift and make the window wander.
    private func resizeWindow(by delta: CGFloat) {
        guard let window, let center = resizeCenter else { return }
        let side = min(max(window.frame.width + delta, 120), 1200)
        let frame = NSRect(x: (center.x - side / 2).rounded(),
                           y: (center.y - side / 2).rounded(),
                           width: side.rounded(),
                           height: side.rounded())
        window.setFrame(frame, display: true)
    }

    private func pickUp() {
        holdTimer = nil
        pickedUp = true
        renderer.pickUp()
        NSCursor.closedHand.push()
    }

    private func putDown() {
        pickedUp = false
        renderer.putDown()
        NSCursor.pop()
    }
}
