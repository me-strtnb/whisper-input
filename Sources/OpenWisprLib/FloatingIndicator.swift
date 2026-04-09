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
        contentView?.audioLevel = 0
        if state == .transcribing {
            startTranscribingAnimation()
        }
        window?.orderFront(nil)
    }

    func hide() {
        stopAnimation()
        window?.orderOut(nil)
    }

    func updateAudioLevel(_ level: Float) {
        DispatchQueue.main.async { [weak self] in
            guard let view = self?.contentView else { return }
            // Smooth the level for natural movement
            view.audioLevel = view.audioLevel * 0.3 + level * 0.7
            view.needsDisplay = true
        }
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

    private func startTranscribingAnimation() {
        stopAnimation()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            guard let view = self?.contentView else { return }
            view.animationPhase += 1.0 / 20.0
            view.needsDisplay = true
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
    var audioLevel: Float = 0

    // Keep recent levels for per-bar variation
    private var levelHistory: [Float] = [0, 0, 0, 0, 0]
    private var historyIndex = 0

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
        // Update level history for per-bar variation
        levelHistory[historyIndex] = audioLevel
        historyIndex = (historyIndex + 1) % levelHistory.count

        // Blue dot with subtle pulse based on audio level
        let dotSize: CGFloat = 12
        let dotX: CGFloat = 14
        let dotY = rect.midY - dotSize / 2
        let dotRect = NSRect(x: dotX, y: dotY, width: dotSize, height: dotSize)

        let brightness = CGFloat(0.7 + 0.3 * audioLevel)
        NSColor(calibratedRed: 0.25 * brightness, green: 0.52 * brightness, blue: 1.0, alpha: 1.0).setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        // Waveform bars driven by audio level
        let barCount = 5
        let barWidth: CGFloat = 2.5
        let barGap: CGFloat = 2.5
        let barStartX: CGFloat = 34
        let minHeight: CGFloat = 2.5
        let maxHeights: [CGFloat] = [6, 10, 14, 10, 6]

        NSColor.white.setFill()

        for i in 0..<barCount {
            // Use slightly offset history entries for each bar
            let idx = (historyIndex + i) % levelHistory.count
            let barLevel = CGFloat(levelHistory[idx])
            let height = minHeight + (maxHeights[i] - minHeight) * barLevel
            let x = barStartX + CGFloat(i) * (barWidth + barGap)
            let y = rect.midY - height / 2
            let barRect = NSRect(x: x, y: y, width: barWidth, height: height)
            NSBezierPath(roundedRect: barRect, xRadius: 1.25, yRadius: 1.25).fill()
        }
    }

    private func drawTranscribing(in rect: NSRect) {
        let dotSize: CGFloat = 6
        let gap: CGFloat = 8
        let totalWidth = 3 * dotSize + 2 * gap
        let startX = rect.midX - totalWidth / 2

        for i in 0..<3 {
            let phase = animationPhase * 1.5 - Double(i) * 0.25
            let bounce = CGFloat(max(0, sin(phase * .pi * 2))) * 4.0
            let alpha = CGFloat(0.4 + 0.6 * max(0, sin(phase * .pi * 2)))
            let x = startX + CGFloat(i) * (dotSize + gap)
            let y = rect.midY - dotSize / 2 + bounce

            NSColor.white.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: dotSize, height: dotSize)).fill()
        }
    }
}
