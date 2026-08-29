//
//  Renderer.swift
//  BitPhone
//

import AudioToolbox
import MetalKit
import simd

/// The answer the bit gives when tapped, with the sound resource it plays.
enum Answer: String, CaseIterable {
    case yes = "tron_bit_yes"
    case no = "tron_bit_no"
}

/// Matches Uniforms in Shaders.metal.
private struct Uniforms {
    var modelViewMatrix: float4x4
    var projectionMatrix: float4x4
    var normalMatrix: float3x3
    var color: SIMD4<Float>
}

final class Renderer: NSObject, MTKViewDelegate {

    static let colorPixelFormat = MTLPixelFormat.bgra8Unorm
    static let depthPixelFormat = MTLPixelFormat.depth32Float

    /// The animation steps below are per frame and were tuned for a 60 Hz
    /// display link, so the view is capped at 60 fps.
    static let framesPerSecond = 60

    private struct Mesh {
        let buffer: MTLBuffer
        let vertexCount: Int
    }

    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState

    private let icosahedron: Mesh
    private let dodecahedron: Mesh
    private let yesShape: Mesh
    private let noShape: Mesh

    private let sounds = AnswerSounds()

    // MARK: - Animation state

    private static let idleColor = SIMD4<Float>(95 / 255, 159 / 255, 234 / 255, 1)
    private static let yesColor = SIMD4<Float>(0.988, 0.8, 0.25, 1)
    private static let noColor = SIMD4<Float>(0.788, 0.35, 0.075, 1)

    private let timeMultiplier: Float = 7
    private var wobbleAngle: Float = 0
    private var answerAngle: Float = 0
    private var answer: Answer?
    private var rotation = matrix_identity_float4x4
    private var rotationAxis = SIMD3<Float>(1, 1, 1)
    private var rotationMomentum: Float = 0.4

    // MARK: - Setup

    init?(device: MTLDevice) {
        guard let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "bit_vertex"),
              let fragmentFunction = library.makeFunction(name: "bit_fragment")
        else { return nil }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = Self.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = Self.depthPixelFormat

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = true

        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor),
              let depthState = device.makeDepthStencilState(descriptor: depthDescriptor),
              let icosahedron = Self.makeMesh(BitGeometry.icosahedron(), device: device),
              let dodecahedron = Self.makeMesh(BitGeometry.dodecahedron(), device: device),
              let yesShape = Self.makeMesh(BitGeometry.yes(), device: device),
              let noShape = Self.makeMesh(BitGeometry.no(), device: device)
        else { return nil }

        self.commandQueue = commandQueue
        self.pipelineState = pipelineState
        self.depthState = depthState
        self.icosahedron = icosahedron
        self.dodecahedron = dodecahedron
        self.yesShape = yesShape
        self.noShape = noShape
    }

    private static func makeMesh(_ vertices: [Vertex], device: MTLDevice) -> Mesh? {
        guard let buffer = device.makeBuffer(bytes: vertices,
                                             length: vertices.count * MemoryLayout<Vertex>.stride,
                                             options: [])
        else { return nil }
        return Mesh(buffer: buffer, vertexCount: vertices.count)
    }

    // MARK: - Interaction

    /// A finger moved: rotate immediately and leave some spin momentum, like
    /// the original's touchesMoved handling. Deltas are in view points.
    func drag(deltaX: Float, deltaY: Float) {
        rotationAxis = SIMD3(deltaY, deltaX, 1)
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY) / 4
        rotationMomentum = distance
        rotate(byDegrees: distance)
    }

    /// A tap: flash a random yes/no answer, unless one is already playing.
    func tap() {
        guard answer == nil else { return }
        let answer = Answer.allCases.randomElement()!
        self.answer = answer
        answerAngle = 0
        sounds.play(answer)
    }

    private func rotate(byDegrees degrees: Float) {
        rotation = float4x4(rotationDegrees: degrees, axis: rotationAxis) * rotation
    }

    // MARK: - Per-frame animation

    private func advanceAnimation() {
        wobbleAngle += 5 / timeMultiplier
        if wobbleAngle > 360 {
            wobbleAngle -= 360
        }

        rotationMomentum /= 1.05
        if rotationMomentum < 0.1 {
            rotationMomentum = 0.1
        }
        rotate(byDegrees: rotationMomentum)

        if answer != nil {
            // The original advanced this angle twice per frame (once in the
            // view's draw callback and once in the renderer), so the steps
            // are doubled here.
            answerAngle += (answerAngle < 90 ? 44 : 16) / timeMultiplier
            if answerAngle >= 180 {
                answerAngle = 0
                answer = nil
            }
        }
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        advanceAnimation()

        guard let renderPassDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState)
        encoder.setFrontFacing(.counterClockwise)
        encoder.setCullMode(.back)

        // Widen the frustum along the longer axis so the scene keeps its
        // aspect ratio instead of being stretched to fill the viewport. Read
        // the size here rather than in drawableSizeWillChange: that callback
        // never fires when the view is created at its final size.
        let size = view.drawableSize
        let aspectRatio = size.height > 0 ? Float(size.width / size.height) : 1
        var frustumX: Float = 1
        var frustumY: Float = 1
        if aspectRatio > 1 {
            frustumX = aspectRatio
        } else {
            frustumY = 1 / aspectRatio
        }
        let projection = float4x4(frustumX: frustumX, frustumY: frustumY, near: 1.5, far: 20)

        let yesScale: Float = answer == .yes ? sin(answerAngle * .pi / 180) : 0
        let noScale: Float = answer == .no ? sin(answerAngle * .pi / 180) : 0

        var color = Self.idleColor
        switch answer {
        case .yes:
            color = simd_mix(Self.idleColor, Self.yesColor, SIMD4(repeating: yesScale))
        case .no:
            color = simd_mix(Self.idleColor, Self.noColor, SIMD4(repeating: noScale))
        case nil:
            break
        }

        let base = float4x4(translation: [0, 0, -3]) * rotation * float4x4(uniformScale: 0.9)

        // The two idle shapes pulse out of phase; both shrink away while an
        // answer shape scales in.
        let icosahedronScale = 0.9 + abs(sin(wobbleAngle * .pi / 180)) / 2 - yesScale / 2 - noScale
        let dodecahedronScale = 1 + abs(sin((wobbleAngle + 90) * .pi / 180)) / 2 - yesScale / 2 - noScale

        draw(icosahedron, scaledBy: icosahedronScale, base: base, color: color, projection: projection, encoder: encoder)
        draw(dodecahedron, scaledBy: dodecahedronScale, base: base, color: color, projection: projection, encoder: encoder)
        draw(yesShape, scaledBy: yesScale * 1.7, base: base, color: color, projection: projection, encoder: encoder)
        draw(noShape, scaledBy: noScale * 1.7, base: base, color: color, projection: projection, encoder: encoder)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func draw(_ mesh: Mesh,
                      scaledBy scale: Float,
                      base: float4x4,
                      color: SIMD4<Float>,
                      projection: float4x4,
                      encoder: MTLRenderCommandEncoder) {
        // At scale zero nothing would rasterize; skip the draw. Negative
        // scales (the wobble math dips below zero briefly) are kept: they
        // flip the winding so the shape is culled away, matching the
        // original.
        guard abs(scale) > 1e-5 else { return }

        // The modelview is rotation and uniform scale only, and the shader
        // normalizes, so the upper-left 3x3 works as the normal matrix.
        let modelView = base * float4x4(uniformScale: scale)
        var uniforms = Uniforms(modelViewMatrix: modelView,
                                projectionMatrix: projection,
                                normalMatrix: modelView.upperLeft3x3,
                                color: color)

        encoder.setVertexBuffer(mesh.buffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: mesh.vertexCount)
    }
}

// MARK: - Sounds

/// Plays the yes/no sound effects as system sounds, like the original.
private final class AnswerSounds {
    private var soundIDs: [Answer: SystemSoundID] = [:]

    init() {
        for answer in Answer.allCases {
            guard let url = Bundle.main.url(forResource: answer.rawValue, withExtension: "aiff") else { continue }
            var soundID: SystemSoundID = 0
            if AudioServicesCreateSystemSoundID(url as CFURL, &soundID) == kAudioServicesNoError {
                soundIDs[answer] = soundID
            }
        }
    }

    func play(_ answer: Answer) {
        guard let soundID = soundIDs[answer] else { return }
        AudioServicesPlaySystemSound(soundID)
    }
}

// MARK: - Matrix helpers

extension float4x4 {
    init(uniformScale scale: Float) {
        self.init(diagonal: [scale, scale, scale, 1])
    }

    init(translation: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4(translation, 1)
    }

    init(rotationDegrees degrees: Float, axis: SIMD3<Float>) {
        let quaternion = simd_quatf(angle: degrees * .pi / 180, axis: simd_normalize(axis))
        self.init(quaternion)
    }

    /// glFrustumf(-fx, fx, -fy, fy, near, far), adapted to Metal's [0, 1]
    /// depth range.
    init(frustumX: Float, frustumY: Float, near: Float, far: Float) {
        self.init(columns: (
            SIMD4(near / frustumX, 0, 0, 0),
            SIMD4(0, near / frustumY, 0, 0),
            SIMD4(0, 0, far / (near - far), -1),
            SIMD4(0, 0, near * far / (near - far), 0)
        ))
    }

    var upperLeft3x3: float3x3 {
        float3x3(SIMD3(columns.0.x, columns.0.y, columns.0.z),
                 SIMD3(columns.1.x, columns.1.y, columns.1.z),
                 SIMD3(columns.2.x, columns.2.y, columns.2.z))
    }
}
