import AppKit

class FloatingIndicator {
    private var window: NSWindow?
    private var contentView: IndicatorView?
    private var animationTimer: Timer?

    func show(state: IndicatorState) {
        if window == nil {
            createWindow()
        }
        contentView?.state = state
        if state == .recording {
            startAnimation()
        } else if state == .transcribing {
            startTranscribingAnimation()
        }
        window?.orderFront(nil)
    }

    func hide() {
        stopAnimation()
        window?.orderOut(nil)
    }

    private func createWindow() {
        let width: CGFloat = 72
        let height: CGFloat = 36

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - width / 2
        let y = screenFrame.minY + 24

        let frame = NSRect(x: x, y: y, width: width, height: height)
        let w = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.level = .floating
        w.ignoresMouseEvents = true
        w.collectionBehavior = [.canJoinAllSpaces, .stationary]
        w.hasShadow = true

        let view = IndicatorView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        w.contentView = view

        self.window = w
        self.contentView = view
    }

    private func startAnimation() {
        stopAnimation()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            self?.contentView?.animationPhase += 1.0 / 24.0
            self?.contentView?.needsDisplay = true
        }
    }

    private func startTranscribingAnimation() {
        stopAnimation()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            self?.contentView?.animationPhase += 1.0 / 24.0
            self?.contentView?.needsDisplay = true
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    enum IndicatorState {
        case recording
        case transcribing
    }
}

private class IndicatorView: NSView {
    var state: FloatingIndicator.IndicatorState = .recording
    var animationPhase: Double = 0

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds

        // Background pill
        let bgColor = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.17, alpha: 0.95)
        bgColor.setFill()
        let pillPath = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        pillPath.fill()

        switch state {
        case .recording:
            drawRecording(in: rect)
        case .transcribing:
            drawTranscribing(in: rect)
        }
    }

    private func drawRecording(in rect: NSRect) {
        // Blue dot
        let dotSize: CGFloat = 12
        let dotX: CGFloat = 14
        let dotY = rect.midY - dotSize / 2
        let dotRect = NSRect(x: dotX, y: dotY, width: dotSize, height: dotSize)

        // Pulsing blue dot
        let pulse = CGFloat(0.85 + 0.15 * sin(animationPhase * 3.0))
        NSColor(calibratedRed: 0.25 * pulse, green: 0.52 * pulse, blue: 1.0 * pulse, alpha: 1.0).setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        // Waveform bars
        let barCount = 5
        let barWidth: CGFloat = 2.5
        let barGap: CGFloat = 2.5
        let barStartX: CGFloat = 34
        let baseHeights: [CGFloat] = [6, 10, 14, 10, 6]

        NSColor.white.setFill()

        for i in 0..<barCount {
            let phase = animationPhase * 2.5 - Double(i) * 0.2
            let scale = CGFloat(0.3 + 0.7 * (sin(phase * .pi * 2) + 1.0) / 2.0)
            let height = baseHeights[i] * scale
            let x = barStartX + CGFloat(i) * (barWidth + barGap)
            let y = rect.midY - height / 2
            let barRect = NSRect(x: x, y: y, width: barWidth, height: height)
            NSBezierPath(roundedRect: barRect, xRadius: 1.25, yRadius: 1.25).fill()
        }
    }

    private func drawTranscribing(in rect: NSRect) {
        // Three bouncing dots
        let dotSize: CGFloat = 6
        let gap: CGFloat = 8
        let totalWidth = 3 * dotSize + 2 * gap
        let startX = rect.midX - totalWidth / 2

        for i in 0..<3 {
            let phase = animationPhase * 2.0 - Double(i) * 0.2
            let bounce = CGFloat(max(0, sin(phase * .pi * 2))) * 4.0
            let alpha = CGFloat(0.4 + 0.6 * max(0, sin(phase * .pi * 2)))
            let x = startX + CGFloat(i) * (dotSize + gap)
            let y = rect.midY - dotSize / 2 + bounce

            NSColor.white.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: dotSize, height: dotSize)).fill()
        }
    }
}
