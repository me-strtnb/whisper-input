import AppKit

class FloatingIndicator {
    private var window: NSWindow?
    private var contentView: IndicatorView?
    private var animationTimer: Timer?

    func show(state: IndicatorState) {
        if window == nil {
            createWindow()
        }
        positionOnActiveScreen()
        contentView?.state = state
        contentView?.audioLevel = 0
        if state == .transcribing {
            startTranscribingAnimation()
        }
        window?.orderFront(nil)
    }

    private func positionOnActiveScreen() {
        guard let w = window else { return }
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main
        guard let activeScreen = screen else { return }
        let screenFrame = activeScreen.visibleFrame
        let x = screenFrame.midX - w.frame.width / 2
        let y = screenFrame.minY + 32
        w.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func hide() {
        stopAnimation()
        window?.orderOut(nil)
    }

    func updateAudioLevel(_ level: Float) {
        DispatchQueue.main.async { [weak self] in
            guard let view = self?.contentView else { return }
            // Smooth but responsive
            view.audioLevel = view.audioLevel * 0.15 + level * 0.85
            view.needsDisplay = true
        }
    }

    private func createWindow() {
        let width: CGFloat = 90
        let height: CGFloat = 44

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - width / 2
        let y = screenFrame.minY + 32

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

    private var levelHistory: [Float] = [0, 0, 0, 0, 0]
    private var historyIndex = 0

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds

        // Glass-style background
        let pillPath = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)

        // Dark translucent fill
        NSColor(calibratedWhite: 0.1, alpha: 0.65).setFill()
        pillPath.fill()

        // Inner light border for glass edge
        NSColor(calibratedWhite: 1.0, alpha: 0.15).setStroke()
        let insetRect = rect.insetBy(dx: 0.5, dy: 0.5)
        let borderPath = NSBezierPath(roundedRect: insetRect, xRadius: insetRect.height / 2, yRadius: insetRect.height / 2)
        borderPath.lineWidth = 1.0
        borderPath.stroke()

        switch state {
        case .recording:
            drawRecording(in: rect)
        case .transcribing:
            drawTranscribing(in: rect)
        }
    }

    private func drawRecording(in rect: NSRect) {
        // Update level history
        levelHistory[historyIndex] = audioLevel
        historyIndex = (historyIndex + 1) % levelHistory.count

        // Blue dot — glows brighter with audio
        let dotSize: CGFloat = 14
        let dotX: CGFloat = 18
        let dotY = rect.midY - dotSize / 2
        let dotRect = NSRect(x: dotX, y: dotY, width: dotSize, height: dotSize)

        // Glow behind dot
        let glowLevel = CGFloat(audioLevel)
        if glowLevel > 0.05 {
            let glowSize = dotSize + 8 * glowLevel
            let glowRect = NSRect(x: dotX - (glowSize - dotSize) / 2, y: dotY - (glowSize - dotSize) / 2, width: glowSize, height: glowSize)
            NSColor(calibratedRed: 0.3, green: 0.55, blue: 1.0, alpha: 0.25 * glowLevel).setFill()
            NSBezierPath(ovalIn: glowRect).fill()
        }

        let brightness = CGFloat(0.75 + 0.25 * audioLevel)
        NSColor(calibratedRed: 0.2 * brightness, green: 0.5 * brightness, blue: 1.0, alpha: 1.0).setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        // Waveform bars — much more dynamic range
        let barCount = 5
        let barWidth: CGFloat = 3.0
        let barGap: CGFloat = 3.0
        let barStartX: CGFloat = 40
        let minHeight: CGFloat = 3.0
        let maxHeights: [CGFloat] = [8, 14, 20, 14, 8]

        for i in 0..<barCount {
            let idx = (historyIndex + i) % levelHistory.count
            // Amplify the level for more dramatic movement
            let rawLevel = levelHistory[idx]
            let amplified = min(1.0, Float(pow(Double(rawLevel), 0.6)) * 1.8)
            let barLevel = CGFloat(amplified)
            let height = minHeight + (maxHeights[i] - minHeight) * barLevel
            let x = barStartX + CGFloat(i) * (barWidth + barGap)
            let y = rect.midY - height / 2
            let barRect = NSRect(x: x, y: y, width: barWidth, height: height)

            // Bars get brighter with higher level
            let barAlpha = CGFloat(0.6 + 0.4 * amplified)
            NSColor.white.withAlphaComponent(barAlpha).setFill()
            NSBezierPath(roundedRect: barRect, xRadius: 1.5, yRadius: 1.5).fill()
        }
    }

    private func drawTranscribing(in rect: NSRect) {
        let dotSize: CGFloat = 7
        let gap: CGFloat = 9
        let totalWidth = 3 * dotSize + 2 * gap
        let startX = rect.midX - totalWidth / 2

        for i in 0..<3 {
            let phase = animationPhase * 1.5 - Double(i) * 0.25
            let bounce = CGFloat(max(0, sin(phase * .pi * 2))) * 5.0
            let alpha = CGFloat(0.4 + 0.6 * max(0, sin(phase * .pi * 2)))
            let x = startX + CGFloat(i) * (dotSize + gap)
            let y = rect.midY - dotSize / 2 + bounce

            NSColor.white.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: dotSize, height: dotSize)).fill()
        }
    }
}
