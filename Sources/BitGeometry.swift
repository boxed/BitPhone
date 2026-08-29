//
//  BitGeometry.swift
//  BitPhone
//

import simd

/// A flat-shaded vertex. The layout (two 16-byte SIMD3<Float> fields) matches
/// the VertexIn struct in Shaders.metal.
struct Vertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
}

/// Builds the shapes the original OpenGL ES renderer drew: the icosahedron +
/// dodecahedron compound that forms the idle "bit", the octahedron flashed for
/// "yes", and the spiky star flashed for "no". Normals are per face (flat
/// shading), and some are deliberately unnormalized: the original fed them to
/// the fixed-function pipeline without GL_NORMALIZE, so their lengths modulate
/// the brightness. That look is preserved here.
enum BitGeometry {

    // MARK: - Icosahedron data (from the classic OpenGL red book)

    private static let X: Float = 0.525731112119133606
    private static let Z: Float = 0.850650808352039932

    private static let icosahedronVertices: [SIMD3<Float>] = [
        [-X, 0, Z], [X, 0, Z], [-X, 0, -Z], [X, 0, -Z],
        [0, Z, X], [0, Z, -X], [0, -Z, X], [0, -Z, -X],
        [Z, X, 0], [-Z, X, 0], [Z, -X, 0], [-Z, -X, 0],
    ]

    private static let icosahedronFaces: [(Int, Int, Int)] = [
        (1, 4, 0), (4, 9, 0), (4, 5, 9), (8, 5, 4), (1, 8, 4),
        (1, 10, 8), (10, 3, 8), (8, 3, 5), (3, 2, 5), (3, 7, 2),
        (3, 10, 7), (10, 6, 7), (6, 11, 7), (6, 0, 11), (6, 1, 0),
        (10, 1, 6), (11, 0, 9), (2, 11, 9), (5, 2, 9), (11, 2, 7),
    ]

    /// A triangle with the same face normal the original computed:
    /// normalize((a - b) × (b - c)).
    private static func flatTriangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> [Vertex] {
        let normal = simd_normalize(simd_cross(a - b, b - c))
        return [
            Vertex(position: a, normal: normal),
            Vertex(position: b, normal: normal),
            Vertex(position: c, normal: normal),
        ]
    }

    // MARK: - Shapes

    static func icosahedron() -> [Vertex] {
        icosahedronFaces.flatMap { face in
            flatTriangle(icosahedronVertices[face.0],
                         icosahedronVertices[face.1],
                         icosahedronVertices[face.2])
        }
    }

    static func dodecahedron() -> [Vertex] {
        let s: Float = 0.85
        let golden = (sqrt(Float(5)) - 1) / 2
        let t = golden * s
        let tt = golden * golden * s

        // Each face: an explicit (nearly unit) normal and five corners in the
        // order the original passed them to drawPentagon.
        let faces: [(normal: SIMD3<Float>, corners: [SIMD3<Float>])] = [
            ([0, s, t], [[t, t, t], [tt, s, 0], [-tt, s, 0], [-t, t, t], [0, tt, s]]),
            ([0, s, -t], [[0, tt, -s], [-t, t, -t], [-tt, s, 0], [tt, s, 0], [t, t, -t]]),
            ([s, t, 0], [[t, t, t], [s, 0, tt], [s, 0, -tt], [t, t, -t], [tt, s, 0]]),
            ([s, -t, 0], [[s, 0, tt], [t, -t, t], [tt, -s, 0], [t, -t, -t], [s, 0, -tt]]),
            ([0, -s, -t], [[t, -t, -t], [tt, -s, 0], [-tt, -s, 0], [-t, -t, -t], [0, -tt, -s]]),
            ([0, -s, t], [[-t, -t, t], [-tt, -s, 0], [tt, -s, 0], [t, -t, t], [0, -tt, s]]),
            ([t, 0, s], [[0, tt, s], [0, -tt, s], [t, -t, t], [s, 0, tt], [t, t, t]]),
            ([-t, 0, s], [[0, -tt, s], [0, tt, s], [-t, t, t], [-s, 0, tt], [-t, -t, t]]),
            ([t, 0, -s], [[0, -tt, -s], [0, tt, -s], [t, t, -t], [s, 0, -tt], [t, -t, -t]]),
            ([-t, 0, -s], [[-t, t, -t], [0, tt, -s], [0, -tt, -s], [-t, -t, -t], [-s, 0, -tt]]),
            ([-s, t, 0], [[-tt, s, 0], [-t, t, -t], [-s, 0, -tt], [-s, 0, tt], [-t, t, t]]),
            ([-s, -t, 0], [[-s, 0, -tt], [-t, -t, -t], [-tt, -s, 0], [-t, -t, t], [-s, 0, tt]]),
        ]

        return faces.flatMap { face -> [Vertex] in
            // The original drew each pentagon as a 5-vertex triangle strip in
            // the order p0, p1, p4, p2, p3; these index triples reproduce the
            // strip's triangles (and winding) as plain triangles.
            let strip = [face.corners[0], face.corners[1], face.corners[4], face.corners[2], face.corners[3]]
            return [(0, 1, 2), (2, 1, 3), (2, 3, 4)].flatMap { (i, j, k) in
                [
                    Vertex(position: strip[i], normal: face.normal),
                    Vertex(position: strip[j], normal: face.normal),
                    Vertex(position: strip[k], normal: face.normal),
                ]
            }
        }
    }

    /// The "yes" octahedron. The corner-pointing normals are unnormalized
    /// (length √3), which overbrightens the shape exactly as the original did.
    static func yes() -> [Vertex] {
        let faces: [(normal: SIMD3<Float>, corners: [SIMD3<Float>])] = [
            ([-1, -1, -1], [[-1, 0, 0], [0, 0, -1], [0, -1, 0]]),
            ([1, -1, -1], [[1, 0, 0], [0, -1, 0], [0, 0, -1]]),
            ([-1, -1, 1], [[0, -1, 0], [0, 0, 1], [-1, 0, 0]]),
            ([1, -1, 1], [[0, -1, 0], [1, 0, 0], [0, 0, 1]]),
            ([-1, 1, -1], [[-1, 0, 0], [0, 1, 0], [0, 0, -1]]),
            ([1, 1, -1], [[1, 0, 0], [0, 0, -1], [0, 1, 0]]),
            ([-1, 1, 1], [[0, 1, 0], [-1, 0, 0], [0, 0, 1]]),
            ([1, 1, 1], [[0, 1, 0], [0, 0, 1], [1, 0, 0]]),
        ]
        return faces.flatMap { face in
            face.corners.map { Vertex(position: $0, normal: face.normal) }
        }
    }

    /// The "no" star: 60 blade triangles around the icosahedron's faces, plus
    /// an inner core. The original drew the core inside a glScalef(0.7) that
    /// also scaled the normals by 1/0.7; both are baked into the vertices.
    static func no() -> [Vertex] {
        var vertices: [Vertex] = []

        for face in icosahedronFaces {
            let a = icosahedronVertices[face.0]
            let b = icosahedronVertices[face.1]
            let c = icosahedronVertices[face.2]
            vertices += starBlade(a, b, c)
            vertices += starBlade(b, c, a)
            vertices += starBlade(c, a, b)
        }

        for face in icosahedronFaces {
            let core = starCore(icosahedronVertices[face.0],
                                icosahedronVertices[face.1],
                                icosahedronVertices[face.2])
            vertices += core.map { Vertex(position: $0.position * 0.7, normal: $0.normal / 0.7) }
        }

        return vertices
    }

    private static func starBlade(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> [Vertex] {
        let center = (a + b + c) / 3 * 0.3
        let v1 = center + (c - b) * 0.1
        let v2 = center + (b - c) * 0.1
        return flatTriangle(a, v2, v1)
    }

    private static func starCore(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> [Vertex] {
        let center = (a + b + c) / 3
        return flatTriangle(center, a * 0.3, b * 0.3)
            + flatTriangle(center, b * 0.3, c * 0.3)
            + flatTriangle(center, c * 0.3, a * 0.3)
    }
}
