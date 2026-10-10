import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct RingGauge: View {
    let progress: Double
    let tint: Color
    let value: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.16), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [tint, GCColor.accent], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text(value)
                .font(.headline.weight(.heavy))
                .foregroundStyle(GCColor.text)
        }
    }
}

struct PremiumStatsHero: View {
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [GCColor.porcelain, GCColor.champagne.opacity(0.62), GCColor.platinum.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: 20) {
                RingGauge(progress: 0.91, tint: GCColor.gold, value: "91")
                    .frame(width: 116, height: 116)
                    .padding(10)
                    .background(GCColor.card.opacity(0.7), in: Circle())

                VStack(alignment: .leading, spacing: 9) {
                    Text("Gift Health")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(GCColor.text.opacity(0.52))
                        .textCase(.uppercase)
                    Text("Elite memory coverage")
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                        .foregroundStyle(GCColor.text)
                    Text("Most important people have ideas, no-repeat rules and recent gift history.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GCColor.text.opacity(0.58))
                        .lineLimit(3)
                }
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(GCColor.cardHighlight.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: GCColor.primary.opacity(0.10), radius: 24, y: 16)
    }
}

struct SpendingTrendCard: View {
    private let data = [
        BudgetPoint(month: "Jan", value: 45),
        BudgetPoint(month: "Feb", value: 62),
        BudgetPoint(month: "Mar", value: 58),
        BudgetPoint(month: "Apr", value: 86),
        BudgetPoint(month: "May", value: 74),
        BudgetPoint(month: "Jun", value: 112)
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Average Budget")
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(GCColor.text)
                        Text("Last six gift decisions")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GCColor.text.opacity(0.54))
                    }
                    Spacer()
                    Text("$74")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(GCColor.accent)
                }

                BudgetTrendGraph(data: data)
                .frame(height: 170)
            }
        }
    }
}

struct BudgetTrendGraph: View {
    let data: [BudgetPoint]

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(GCColor.accent.opacity(0.055))

                    TrendArea(values: data.map(\.value))
                        .fill(
                            LinearGradient(
                                colors: [GCColor.accent.opacity(0.24), GCColor.accent.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    TrendLine(values: data.map(\.value))
                        .stroke(GCColor.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                    TrendPoints(values: data.map(\.value))
                        .fill(GCColor.gold)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }

            HStack {
                ForEach(data) { point in
                    Text(point.month)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(GCColor.text.opacity(0.42))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct TrendLine: Shape {
    let values: [Int]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = chartPoints(in: rect, values: values)
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

struct TrendArea: Shape {
    let values: [Int]

    func path(in rect: CGRect) -> Path {
        var path = TrendLine(values: values).path(in: rect)
        guard let first = chartPoints(in: rect, values: values).first,
              let last = chartPoints(in: rect, values: values).last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: first.x, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct TrendPoints: Shape {
    let values: [Int]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for point in chartPoints(in: rect, values: values) {
            path.addEllipse(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
        }
        return path
    }
}

private func chartPoints(in rect: CGRect, values: [Int]) -> [CGPoint] {
    guard let minValue = values.min(), let maxValue = values.max(), values.count > 1 else { return [] }
    let range = Swift.max(maxValue - minValue, 1)
    return values.enumerated().map { index, value in
        let x = rect.minX + CGFloat(index) / CGFloat(values.count - 1) * rect.width
        let normalized = CGFloat(value - minValue) / CGFloat(range)
        let y = rect.maxY - normalized * rect.height
        return CGPoint(x: x, y: y)
    }
}

struct CategoryDistributionCard: View {
    private let segments = [
        SegmentData(title: "Ideas", progress: 0.36, tint: GCColor.accent),
        SegmentData(title: "History", progress: 0.27, tint: GCColor.primary),
        SegmentData(title: "Wishlist", progress: 0.22, tint: GCColor.success),
        SegmentData(title: "Dreams", progress: 0.15, tint: GCColor.gold)
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Gift Memory Mix", action: nil)
                HStack(spacing: 18) {
                    DonutSegments(segments: segments)
                        .frame(width: 136, height: 136)
                    VStack(spacing: 10) {
                        ForEach(segments) { segment in
                            HStack(spacing: 9) {
                                Circle()
                                    .fill(segment.tint)
                                    .frame(width: 9, height: 9)
                                Text(segment.title)
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(GCColor.text.opacity(0.62))
                                Spacer()
                                Text("\(Int(segment.progress * 100))%")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(GCColor.text)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct RelationshipCoverageCard: View {
    private let rows = [
        CoverageRow(name: "Emma", wishes: 0.82, ideas: 0.93, history: 0.74),
        CoverageRow(name: "Mom", wishes: 0.66, ideas: 0.78, history: 0.88),
        CoverageRow(name: "Alex", wishes: 0.58, ideas: 0.64, history: 0.42)
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "People Coverage", action: nil)
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(row.name)
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(GCColor.text)
                            Spacer()
                            Text("\(Int(((row.wishes + row.ideas + row.history) / 3) * 100))%")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(GCColor.gold)
                        }
                        CoverageBars(row: row)
                    }
                    if row.id != rows.last?.id {
                        Divider().opacity(0.55)
                    }
                }
            }
        }
    }
}

struct CoverageBars: View {
    let row: CoverageRow

    var body: some View {
        HStack(spacing: 6) {
            CoverageBar(progress: row.wishes, tint: GCColor.success)
            CoverageBar(progress: row.ideas, tint: GCColor.accent)
            CoverageBar(progress: row.history, tint: GCColor.primary)
        }
        .frame(height: 8)
    }
}

struct CoverageBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.12))
                Capsule()
                    .fill(tint)
                    .frame(width: max(8, proxy.size.width * progress))
            }
        }
    }
}

struct DonutSegments: View {
    let segments: [SegmentData]

    var body: some View {
        ZStack {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                let start = segments.prefix(index).reduce(0) { $0 + $1.progress }
                Circle()
                    .trim(from: start, to: start + segment.progress - 0.012)
                    .stroke(segment.tint, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 2) {
                Text("147")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(GCColor.text)
                Text("signals")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(GCColor.text.opacity(0.48))
            }
        }
    }
}

struct BudgetPoint: Identifiable {
    let id = UUID()
    let month: String
    let value: Int
}

struct SegmentData: Identifiable {
    let id = UUID()
    let title: String
    let progress: Double
    let tint: Color
}

struct CoverageRow: Identifiable {
    let id = UUID()
    let name: String
    let wishes: Double
    let ideas: Double
    let history: Double
}

struct StatCircle: View {
    let value: String
    let label: String
    let progress: Double
    let tint: Color

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(tint.opacity(0.13), lineWidth: 11)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(colors: [tint, GCColor.champagne], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 11, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(value)
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(GCColor.text)
                        Image(systemName: "sparkle")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(GCColor.gold)
                    }
                }
                .frame(width: 104, height: 104)
                Text(label)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(GCColor.text)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 154)
        }
    }
}
