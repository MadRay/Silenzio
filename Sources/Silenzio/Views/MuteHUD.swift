import AppKit
import SwiftUI

/// Brief centered HUD shown whenever mute state changes (hotkey, popover, or system sync).
@MainActor
final class MuteHUDController {
    static let shared = MuteHUDController()

    private var panel: NSPanel?
    private var hosting: NSHostingView<MuteHUDView>?
    private var hideWorkItem: DispatchWorkItem?
    private let displayDuration: TimeInterval = 1.4

    private init() {}

    func show(muted: Bool) {
        let view = MuteHUDView(isMuted: muted)
        let fitting = makeHostingView(rootView: view)
        let size = fitting.fittingSize

        let panel = ensurePanel(size: size)
        hosting?.removeFromSuperview()
        fitting.frame = NSRect(origin: .zero, size: size)

        if let contentView = panel.contentView {
            contentView.subviews.forEach { $0.removeFromSuperview() }
            fitting.autoresizingMask = [.width, .height]
            contentView.addSubview(fitting)
            fitting.frame = contentView.bounds
        } else {
            panel.contentView = fitting
        }

        hosting = fitting
        panel.setContentSize(size)
        center(panel, size: size)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }

        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration, execute: work)
    }

    private func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            panel?.orderOut(nil)
        })
    }

    private func makeHostingView(rootView: MuteHUDView) -> NSHostingView<MuteHUDView> {
        let hosting = NSHostingView(rootView: rootView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        // Avoid AppKit filling the square window behind the rounded card.
        if #available(macOS 13.0, *) {
            hosting.sizingOptions = [.intrinsicContentSize]
        }
        return hosting
    }

    private func ensurePanel(size: NSSize) -> NSPanel {
        if let panel {
            return panel
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // Window shadow follows the rectangular frame and paints black corners —
        // the card draws its own soft shadow in SwiftUI instead.
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        let clearContent = NSView(frame: NSRect(origin: .zero, size: size))
        clearContent.wantsLayer = true
        clearContent.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = clearContent

        self.panel = panel
        return panel
    }

    private func center(_ panel: NSPanel, size: NSSize) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + 24
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}

struct MuteHUDView: View {
    let isMuted: Bool

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isMuted ? SilenzioTheme.muteRed : SilenzioTheme.liveGreen)
                    .frame(width: 72, height: 72)
                    .shadow(
                        color: (isMuted ? SilenzioTheme.muteRed : SilenzioTheme.liveGreen).opacity(0.45),
                        radius: 16
                    )
                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(isMuted ? Color.white : SilenzioTheme.liveGreenIcon)
            }

            Text(isMuted ? "Microphone Muted" : "Microphone Live")
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: 0x1C1C1E).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        // Small inset so the soft shadow isn't clipped by the panel.
        .padding(12)
        .background(Color.clear)
    }
}
