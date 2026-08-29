//
//  BitView.swift
//  BitPhone
//

import MetalKit

/// The Metal view showing the bit. Dragging spins it; tapping asks it a
/// question.
final class BitView: MTKView {
    private let renderer: Renderer
    private var dragged = false

    init(frame: CGRect) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let renderer = Renderer(device: device)
        else { preconditionFailure("Metal is not available") }
        self.renderer = renderer

        super.init(frame: frame, device: device)

        colorPixelFormat = Renderer.colorPixelFormat
        depthStencilPixelFormat = Renderer.depthPixelFormat
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        preferredFramesPerSecond = Renderer.framesPerSecond
        delegate = renderer
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let previous = touch.previousLocation(in: self)
        renderer.drag(deltaX: Float(location.x - previous.x),
                      deltaY: Float(location.y - previous.y))
        dragged = true
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !dragged {
            renderer.tap()
        }
        dragged = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        dragged = false
    }
}
