import SwiftUI

struct AudioMeterView: View {
    let isMuted: Bool
    let level: Float
    private let barCount = 18

    var body: some View {
        Group {
            if isMuted {
                HStack {
                    Capsule()
                        .fill(SilenzioTheme.meterFlat)
                        .frame(height: 4)
                }
                .frame(height: 22)
            } else {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<barCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(barColor(for: index))
                            .frame(width: 4, height: barHeight(for: index))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 22)
            }
        }
        .animation(.easeOut(duration: 0.08), value: level)
    }

    private func threshold(for index: Int) -> Float {
        Float(index + 1) / Float(barCount)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let active = level >= threshold(for: index) * 0.85
        if active {
            // Varied heights for a lively meter silhouette.
            let pattern: [CGFloat] = [9, 14, 19, 12, 21, 15, 10, 17, 11, 16, 13, 18, 12, 20, 14, 11, 15, 10]
            return pattern[index % pattern.count]
        }
        let idle: [CGFloat] = [7, 9, 6, 8, 5, 7, 4, 6, 5, 7, 4, 6, 5, 4, 6, 5, 4, 5]
        return idle[index % idle.count]
    }

    private func barColor(for index: Int) -> Color {
        let active = level >= threshold(for: index) * 0.85
        if !active { return SilenzioTheme.meterIdle }
        return index > Int(Float(barCount) * 0.7)
            ? SilenzioTheme.liveGreenText
            : SilenzioTheme.liveGreen
    }
}

struct ShortcutChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(SilenzioTheme.primaryLabel.opacity(0.9))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(SilenzioTheme.chipBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(SilenzioTheme.chipBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct SegmentedPill<T: Hashable & Identifiable>: View where T: RawRepresentable, T.RawValue == String {
    let options: [T]
    @Binding var selection: T
    let title: (T) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(selection == option ? Color.white : SilenzioTheme.secondaryLabel)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 4)
                        .background(
                            Group {
                                if selection == option {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.white.opacity(0.16))
                                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.black.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
