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
        let fitting = NSHostingView(rootView: view)
        fitting.frame = NSRect(origin: .zero, size: fitting.fittingSize)

        let size = fitting.fittingSize
        let panel = ensurePanel(size: size)
        hosting?.removeFromSuperview()
        fitting.frame = NSRect(origin: .zero, size: size)
        panel.contentView = fitting
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

    private func ensurePanel(size: NSSize) -> NSPanel {
        if let panel {
            return panel
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = true
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
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
        )
    }
}
