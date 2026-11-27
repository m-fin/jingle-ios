import Foundation

/// Smooth fade-in used by the progressive wake.
/// Smoothstep stays quiet early (below a straight line) and eases into full volume.
public enum ProgressiveRamp {
    public static func gain(elapsed: TimeInterval, duration: TimeInterval) -> Double {
        if duration <= 0 {
            return elapsed < 0 ? 0 : 1
        }
        if elapsed <= 0 { return 0 }
        if elapsed >= duration { return 1 }
        let t = elapsed / duration
        return t * t * (3 - 2 * t)
    }
}
