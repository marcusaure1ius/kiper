import CoreMotion
import SwiftUI

// MARK: - Wallet-style holographic sheen

/// Iridescent band that follows device tilt (Apple Cash card). Without a motion
/// sensor (Simulator) it sweeps slowly by itself.
struct HolographicSheen: ViewModifier {
    var cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.overlay {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let motion = MotionTracker.shared
                let t = context.date.timeIntervalSinceReferenceDate
                let x = motion.isAvailable ? motion.roll * 1.2 : sin(t * 0.45) * 0.7
                let y = motion.isAvailable ? motion.pitch * 1.2 : cos(t * 0.35) * 0.3
                band(x: x, y: y)
                    .blendMode(scheme == .dark ? .plusLighter : .overlay)
                    .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            }
            .allowsHitTesting(false)
            .onAppear { MotionTracker.shared.start() }
            .onDisappear { MotionTracker.shared.stop() }
        }
    }
}

extension HolographicSheen {
    private func band(x: Double, y: Double) -> LinearGradient {
        let strength = scheme == .dark ? 0.32 : 0.5
        let stops: [Gradient.Stop] = [
            .init(color: .clear, location: 0.30),
            .init(color: Color(hex: 0xA0E9FF).opacity(strength), location: 0.42),
            .init(color: Color(hex: 0xFFB3F0).opacity(strength), location: 0.50),
            .init(color: Color(hex: 0xFFF3A0).opacity(strength * 0.8), location: 0.58),
            .init(color: .clear, location: 0.70),
        ]
        return LinearGradient(
            stops: stops,
            startPoint: UnitPoint(x: -0.3 + x, y: -0.1 + y),
            endPoint: UnitPoint(x: 1.3 + x, y: 1.1 + y)
        )
    }
}

/// Shared, ref-counted device-motion reader.
@MainActor
@Observable
final class MotionTracker {
    static let shared = MotionTracker()

    private(set) var roll = 0.0
    private(set) var pitch = 0.0
    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var users = 0
    @ObservationIgnored private var referencePitch: Double?

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            let roll = motion.attitude.roll, pitch = motion.attitude.pitch
            MainActor.assumeIsolated {
                let tracker = MotionTracker.shared
                let reference = tracker.referencePitch ?? pitch
                tracker.referencePitch = reference
                // Low-pass filter so the sheen glides instead of jittering.
                tracker.roll += (roll - tracker.roll) * 0.15
                tracker.pitch += ((pitch - reference) - tracker.pitch) * 0.15
            }
        }
    }

    func stop() {
        users = max(users - 1, 0)
        guard users == 0 else { return }
        manager.stopDeviceMotionUpdates()
        referencePitch = nil
    }
}

// MARK: - Scroll reveal (WWDC24 scroll effects)

/// Rows shrink, fade and blur slightly as they leave the visible area.
struct ScrollReveal: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollTransition(.interactive, axis: .vertical) { view, phase in
            // phase.value: 0 fully visible, ±1 fully outside — fade gradually.
            let k = min(abs(phase.value), 1)
            return view
                .scaleEffect(1 - 0.1 * k)
                .opacity(1 - 0.65 * k)
                .blur(radius: 3 * k)
        }
    }
}

extension View {
    func scrollReveal() -> some View { modifier(ScrollReveal()) }
}

/// A rouble amount that "counts up" from zero when it first appears.
struct CountUpRub: View {
    let value: Double
    @State private var shown: Double?

    var body: some View {
        Text(Fmt.rub(shown ?? 0))
            .contentTransition(.numericText(value: shown ?? 0))
            .onAppear {
                guard shown == nil else { return }
                withAnimation(.smooth(duration: 1.1).delay(0.15)) { shown = value }
            }
            .onChange(of: value) { _, new in
                withAnimation(.smooth) { shown = new }
            }
    }
}

// MARK: - SF Symbols 7 draw-on toast

struct Toast: Equatable, Identifiable {
    let id = UUID()
    let text: String
    let symbol: String
    var tint: Color = .green
}

/// Glass capsule whose icon draws itself in (SF Symbols 7 Draw On).
struct ToastView: View {
    let toast: Toast
    @State private var drawn = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(toast.tint)
                .symbolEffect(.drawOff, options: .nonRepeating, isActive: !drawn)
            Text(toast.text)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .capsule)
        .task {
            try? await Task.sleep(for: .seconds(0.15))
            drawn = true
        }
    }
}
