// Adapted from metasidd/Orb at a48fc3382ad40905ca4aa9691c6b504004740ad1.
// https://github.com/metasidd/Orb
/*
MIT License

Copyright (c) 2024 Siddhant Mehta

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

//
//  OrbConfiguration.swift
//  Orb
//
//  Created by Siddhant Mehta on 2024-11-08.
//

import SwiftUI
private struct OrbMotionKey:EnvironmentKey {static let defaultValue=true}
extension EnvironmentValues {var orbMotionEnabled:Bool {get{self[OrbMotionKey.self]}set{self[OrbMotionKey.self]=newValue}}}


public struct OrbConfiguration {
    public let glowColor: Color
    public let backgroundColors: [Color]
    public let particleColor: Color

    public let showBackground: Bool
    public let showWavyBlobs: Bool
    public let showParticles: Bool
    public let showGlowEffects: Bool
    public let showShadow: Bool

    public let coreGlowIntensity: Double
    public let speed: Double

    internal init(
        backgroundColors: [Color],
        glowColor: Color,
        particleColor: Color,
        coreGlowIntensity: Double,
        showBackground: Bool,
        showWavyBlobs: Bool,
        showParticles: Bool,
        showGlowEffects: Bool,
        showShadow: Bool,
        speed: Double
    ) {
        self.backgroundColors = backgroundColors
        self.glowColor = glowColor
        self.particleColor = particleColor
        self.showBackground = showBackground
        self.showWavyBlobs = showWavyBlobs
        self.showParticles = showParticles
        self.showGlowEffects = showGlowEffects
        self.showShadow = showShadow
        self.coreGlowIntensity = coreGlowIntensity
        self.speed = speed
    }

    public init(
        backgroundColors: [Color] = [.green, .blue, .pink],
        glowColor: Color = .white,
        coreGlowIntensity: Double = 1.0,
        showBackground: Bool = true,
        showWavyBlobs: Bool = true,
        showParticles: Bool = true,
        showGlowEffects: Bool = true,
        showShadow: Bool = true,
        speed: Double = 60
    ) {
        self.init(
            backgroundColors: backgroundColors,
            glowColor: glowColor,
            particleColor: .white,
            coreGlowIntensity: coreGlowIntensity,
            showBackground: showBackground,
            showWavyBlobs: showWavyBlobs,
            showParticles: showParticles,
            showGlowEffects: showGlowEffects,
            showShadow: showShadow,
            speed: speed
        )
    }
}

//
//  RealisticShadows.swift
//  Prototype-Orb
//
//  Created by Siddhant Mehta on 2024-11-06.
//
import SwiftUI

struct RealisticShadowModifier: ViewModifier {
    let colors: [Color]
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .blur(radius: radius * 0.75)
                    .opacity(0.5)
                    .offset(y: radius * 0.5)
            }
            .background {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .blur(radius: radius * 3)
                    .opacity(0.3)
                    .offset(y: radius * 0.75)
            }
    }
}

//
//  OrbView.swift
//  Prototype-Orb
//
//  Created by Siddhant Mehta on 2024-11-06.
//
import SwiftUI

public struct OrbView: View {
    private let config: OrbConfiguration

    public init(configuration: OrbConfiguration = OrbConfiguration()) {
        self.config = configuration
    }

    public var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                // Base gradient background layer
                if config.showBackground {
                    background
                }

                // Creates depth with rotating glow effects
                baseDepthGlows(size: size)

                // Adds organic movement with flowing blob shapes
                if config.showWavyBlobs {
                    wavyBlob
                    wavyBlobTwo
                }

                // Adds bright, energetic core glow animations
                if config.showGlowEffects {
                    coreGlowEffects(size: size)
                }

                // Overlays floating particle effects for additional dynamism
                if config.showParticles {
                    particleView
                        .frame(maxWidth: size, maxHeight: size)
                }
            }
            // Orb outline for depth
            .overlay {
                realisticInnerGlows
            }
            // Masking out all the effects so it forms a perfect circle
            .mask {
                Circle()
            }
            .aspectRatio(1, contentMode: .fit)
            // Adding realistic, layered shadows so its brighter near the core, and softer as it grows outwards
            .modifier(
                RealisticShadowModifier(
                    colors: config.showShadow ? config.backgroundColors : [.clear],
                    radius: size * 0.08
                )
            )
        }
    }

    private var background: some View {
        LinearGradient(colors: config.backgroundColors,
                       startPoint: .bottom,
                       endPoint: .top)
    }

    private var orbOutlineColor: LinearGradient {
        LinearGradient(colors: [.white, .clear],
                       startPoint: .bottom,
                       endPoint: .top)
    }

    private var particleView: some View {
        // Added multiple particle effects since the blurring amounts are different
        ZStack {
            ParticlesView(
                color: config.particleColor,
                speedRange: 10...20,
                sizeRange: 0.5...1,
                particleCount: 10,
                opacityRange: 0...0.3
            )
            .blur(radius: 1)

            ParticlesView(
                color: config.particleColor,
                speedRange: 20...30,
                sizeRange: 0.2...1,
                particleCount: 10,
                opacityRange: 0.3...0.8
            )
        }
        .blendMode(.plusLighter)
    }

    private var wavyBlob: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            RotatingGlowView(color: .white.opacity(0.75),
                           rotationSpeed: config.speed * 1.5,
                           direction: .clockwise)
                .mask {
                    WavyBlobView(color: .white, loopDuration: 60 / config.speed * 1.75)
                        .frame(maxWidth: size * 1.875)
                        .offset(x: 0, y: size * 0.31)
                }
                .blur(radius: 1)
                .blendMode(.plusLighter)
        }
    }

    private var wavyBlobTwo: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            RotatingGlowView(color: .white,
                           rotationSpeed: config.speed * 0.75,
                           direction: .counterClockwise)
                .mask {
                    WavyBlobView(color: .white, loopDuration: 60 / config.speed * 2.25)
                        .frame(maxWidth: size * 1.25)
                        .rotationEffect(.degrees(90))
                        .offset(x: 0, y: size * -0.31)
                }
                .opacity(0.5)
                .blur(radius: 1)
                .blendMode(.plusLighter)
        }
    }

    private func coreGlowEffects(size: CGFloat) -> some View {
        ZStack {
            RotatingGlowView(color: config.glowColor,
                          rotationSpeed: config.speed * 3,
                          direction: .clockwise)
                .blur(radius: size * 0.08)
                .opacity(config.coreGlowIntensity)

            RotatingGlowView(color: config.glowColor,
                          rotationSpeed: config.speed * 2.3,
                          direction: .clockwise)
                .blur(radius: size * 0.06)
                .opacity(config.coreGlowIntensity)
                .blendMode(.plusLighter)
        }
        .padding(size * 0.08)
    }

    // New combined function replacing outerGlow and outerRing
    private func baseDepthGlows(size: CGFloat) -> some View {
        ZStack {
            // Outer glow (previously outerGlow function)
            RotatingGlowView(color: config.glowColor,
                          rotationSpeed: config.speed * 0.75,
                          direction: .counterClockwise)
                .padding(size * 0.03)
                .blur(radius: size * 0.06)
                .rotationEffect(.degrees(180))
                .blendMode(.destinationOver)

            // Outer ring (previously outerRing function)
            RotatingGlowView(color: config.glowColor.opacity(0.5),
                          rotationSpeed: config.speed * 0.25,
                          direction: .clockwise)
                .frame(maxWidth: size * 0.94)
                .rotationEffect(.degrees(180))
                .padding(8)
                .blur(radius: size * 0.032)
        }
    }

    private var realisticInnerGlows: some View {
        ZStack {
            // Outer stroke with heavy blur
            Circle()
                .stroke(orbOutlineColor, lineWidth: 8)
                .blur(radius: 32)
                .blendMode(.plusLighter)

            // Inner stroke with light blur
            Circle()
                .stroke(orbOutlineColor, lineWidth: 4)
                .blur(radius: 12)
                .blendMode(.plusLighter)

            Circle()
                .stroke(orbOutlineColor, lineWidth: 1)
                .blur(radius: 4)
                .blendMode(.plusLighter)
        }
        .padding(1)
    }
}


//
//  Particles.swift
//  Prototype-Orb
//
//  Created by Siddhant Mehta on 2024-11-06.
//
import SwiftUI
import SpriteKit

class ParticleScene: SKScene {
    let color: UIColor
    let speedRange: ClosedRange<Double>
    let sizeRange: ClosedRange<CGFloat>
    let particleCount: Int
    let opacityRange: ClosedRange<Double>

    init(
        size: CGSize,
        color: UIColor,
        speedRange: ClosedRange<Double>,
        sizeRange: ClosedRange<CGFloat>,
        particleCount: Int,
        opacityRange: ClosedRange<Double>
    ) {
        self.color = color
        self.speedRange = speedRange
        self.sizeRange = sizeRange
        self.particleCount = particleCount
        self.opacityRange = opacityRange
        super.init(size: size)

        backgroundColor = .clear
        setupParticleEmitter()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupParticleEmitter() {
        let emitter = SKEmitterNode()

        // Create a white particle texture
        emitter.particleTexture = createParticleTexture()

        // Update color properties
        emitter.particleColorSequence = nil
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1.0

        // Basic emitter properties
        emitter.particleSpeed = CGFloat(speedRange.lowerBound)
        emitter.particleSpeedRange = CGFloat(speedRange.upperBound - speedRange.lowerBound)
        emitter.particleScale = sizeRange.lowerBound
        emitter.particleScaleRange = sizeRange.upperBound - sizeRange.lowerBound

        // Alpha and fade properties
        emitter.particleAlpha = 0 // Start invisible
        emitter.particleAlphaSpeed = CGFloat(opacityRange.upperBound) / 0.5 // Fade in over 0.5 seconds
        emitter.particleAlphaRange = CGFloat(opacityRange.upperBound - opacityRange.lowerBound)

        // Create alpha sequence for fade in/out
        let alphaSequence = SKKeyframeSequence(keyframeValues: [
            0,                              // Start invisible
            Double.random(in: opacityRange),        // Fade in to max opacity
            Double.random(in: opacityRange),        // Stay at max opacity
            Double.random(in: opacityRange)         // Fade to min opacity
        ], times: [
            0,      // At start
            0.2,    // Reach max at 20% of lifetime
            0.8,    // Stay at max until 80% of lifetime
            1.0     // Fade to min by end
        ])
        emitter.particleAlphaSequence = alphaSequence

        // Create scale sequence for grow/shrink animation
        let scaleSequence = SKKeyframeSequence(keyframeValues: [
            sizeRange.lowerBound * 0.7,    // Start at half min size
            sizeRange.upperBound * 0.9,    // Grow to max size
            sizeRange.upperBound,          // Stay at max
            sizeRange.lowerBound * 0.8     // Shrink back to half min size
        ], times: [
            0,      // At start
            0.4,    // Reach max at 20% of lifetime
            0.7,    // Stay at max until 80% of lifetime
            1.0     // Shrink by end
        ])
        emitter.particleScaleSequence = scaleSequence

        emitter.particleBlendMode = .add

        // Center the emitter and set emission area to full size
        emitter.position = CGPoint(x: size.width/2, y: size.height/2)
        emitter.particlePositionRange = CGVector(dx: size.width, dy: size.height)

        // Particle birth and lifetime
        emitter.particleBirthRate = CGFloat(particleCount) / 2.0
        emitter.numParticlesToEmit = 0
        emitter.particleLifetime = 2.0
        emitter.particleLifetimeRange = 1.0

        // Update movement properties
        emitter.emissionAngle = CGFloat.pi / 2  // Point upwards (90 degrees)
        emitter.emissionAngleRange = CGFloat.pi / 6  // Allow 30 degree variation each way

        // Add some sideways drift
        emitter.xAcceleration = 0  // No horizontal acceleration
        emitter.yAcceleration = 20 // Slight upward acceleration

        addChild(emitter)
    }

    private func createParticleTexture() -> SKTexture {
        let size = CGSize(width: 8, height: 8)  // Smaller size for better performance
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            // Simple filled white circle
            UIColor.white.setFill()
            let circlePath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
            circlePath.fill()
        }

        return SKTexture(image: image)
    }
}

struct ParticlesView: View {
    let color: Color
    let speedRange: ClosedRange<Double>
    let sizeRange: ClosedRange<CGFloat>
    let particleCount: Int
    let opacityRange: ClosedRange<Double>

    var scene: SKScene {
        let scene = ParticleScene(
            size: CGSize(width: 300, height: 300), // Use fixed size
            color: UIColor(color),
            speedRange: speedRange,
            sizeRange: sizeRange,
            particleCount: particleCount,
            opacityRange: opacityRange
        )
        scene.scaleMode = .aspectFit
        return scene
    }

    var body: some View {
        GeometryReader { geometry in
            SpriteView(scene: scene, options: [.allowsTransparency])
                .frame(width: geometry.size.width, height: geometry.size.height)
                .ignoresSafeArea()
        }
    }
}


//
//  BackgroundView.swift
//  Prototype-Orb
//
//  Created by Siddhant Mehta on 2024-11-06.
//

import SwiftUI

enum RotationDirection {
    case clockwise
    case counterClockwise

    var multiplier: Double {
        switch self {
        case .clockwise: return 1
        case .counterClockwise: return -1
        }
    }
}

struct RotatingGlowView: View {
    @Environment(\.orbMotionEnabled) private var motionEnabled

    private let color: Color
    private let rotationSpeed: Double
    private let direction: RotationDirection

    init(color: Color,
         rotationSpeed: Double = 30,
         direction: RotationDirection)
    {
        self.color = color
        self.rotationSpeed = rotationSpeed
        self.direction = direction
    }

    var body: some View {
        TimelineView(.animation(minimumInterval:1.0/30,paused:!motionEnabled)){timeline in
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            Circle()
                .fill(color)
                .mask {
                    ZStack {
                        Circle()
                            .frame(width: size, height: size)
                            .blur(radius: size * 0.16)
                        Circle()
                            .frame(width: size * 1.31, height: size * 1.31)
                            .offset(y: size * 0.31)
                            .blur(radius: size * 0.16)
                            .blendMode(.destinationOut)
                    }
                }
                .rotationEffect(.degrees(motionEnabled ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy:360/rotationSpeed)*rotationSpeed*direction.multiplier:28*direction.multiplier))
        }
    }
        }
}


import SwiftUI

struct WavyBlobView: View {
    @Environment(\.orbMotionEnabled) private var motionEnabled
    @State private var points: [CGPoint] = (0 ..< 6).map { index in
        let angle = (Double(index) / 6) * 2 * .pi
        return CGPoint(
            x: 0.5 + cos(angle) * 0.9,
            y: 0.5 + sin(angle) * 0.9
        )
    }

    private let color: Color
    private let loopDuration: Double

    init(color: Color, loopDuration: Double = 1) {
        self.color = color
        self.loopDuration = loopDuration
    }

    var body: some View {
        TimelineView(.animation(minimumInterval:1.0/30,paused:!motionEnabled)) { timeline in
            Canvas { context, size in
                let timeNow = motionEnabled ? timeline.date.timeIntervalSinceReferenceDate:0
                let angle = (timeNow.remainder(dividingBy: loopDuration) / loopDuration) * 2 * .pi

                var path = Path()
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.45

                // Move points with larger variations using sine for smooth looping
                let adjustedPoints = points.enumerated().map { index, point in
                    let phaseOffset = Double(index) * .pi / 3
                    let xOffset = sin(angle + phaseOffset) * 0.15
                    let yOffset = cos(angle + phaseOffset) * 0.15
                    return CGPoint(
                        x: (point.x - 0.5 + xOffset) * radius + center.x,
                        y: (point.y - 0.5 + yOffset) * radius + center.y
                    )
                }

                // Start the path
                path.move(to: adjustedPoints[0])

                // Create smooth curves between points
                for i in 0 ..< adjustedPoints.count {
                    let next = (i + 1) % adjustedPoints.count

                    // Calculate the angle between points
                    let currentAngle = atan2(
                        adjustedPoints[i].y - center.y,
                        adjustedPoints[i].x - center.x
                    )
                    let nextAngle = atan2(
                        adjustedPoints[next].y - center.y,
                        adjustedPoints[next].x - center.x
                    )

                    // Create perpendicular handles
                    let handleLength = radius * 0.33

                    let control1 = CGPoint(
                        x: adjustedPoints[i].x + cos(currentAngle + .pi / 2) * handleLength,
                        y: adjustedPoints[i].y + sin(currentAngle + .pi / 2) * handleLength
                    )

                    let control2 = CGPoint(
                        x: adjustedPoints[next].x + cos(nextAngle - .pi / 2) * handleLength,
                        y: adjustedPoints[next].y + sin(nextAngle - .pi / 2) * handleLength
                    )

                    path.addCurve(
                        to: adjustedPoints[next],
                        control1: control1,
                        control2: control2
                    )
                }

                context.fill(path, with: .color(color))
            }
        }
        .animation(.spring(), value: points)
    }
}
