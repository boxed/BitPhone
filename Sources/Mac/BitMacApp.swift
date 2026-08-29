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
        appMenu.addItem(NSMenuItem(title: "Quit Bit",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q"))
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(appMenuItem)
        return mainMenu
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
/// releasing puts it down.
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
    private var clickThroughTimer: Timer?
    private var holdTimer: Timer?

    init(frame: NSRect) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let renderer = Renderer(device: device)
        else { preconditionFailure("Metal is not available") }
        self.renderer = renderer

        super.init(frame: frame, device: device)

        colorPixelFormat = Renderer.colorPixelFormat
        depthStencilPixelFormat = Renderer.depthPixelFormat
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        preferredFramesPerSecond = Renderer.framesPerSecond
        wantsLayer = true
        layer?.isOpaque = false
        delegate = renderer

        clickThroughTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.updateClickThrough()
        }
    }

    deinit {
        clickThroughTimer?.invalidate()
        holdTimer?.invalidate()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// The window takes mouse events only while the cursor is over the bit,
    /// so the transparent parts of the window behave as if they were not
    /// there.
    private func updateClickThrough() {
        guard let window, !mouseIsDown else { return }
        let mouse = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
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
        if pickedUp {
            putDown()
        } else if !dragged {
            renderer.tap()
        }
        dragged = false
        mouseIsDown = false
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
