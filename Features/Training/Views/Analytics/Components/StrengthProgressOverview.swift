import SwiftUI
import Charts

struct StrengthProgressOverview: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var unitSettings: UnitSettings
    
    let user: User
    @State private var selectedTimeRange: TimeRange = .sixMonths
    @State private var selectedExercise: String? = nil
    
    enum TimeRange: String, CaseIterable {
        case oneMonth = "1M"
        case threeMonths = "3M"  
        case sixMonths = "6M"
        case oneYear = "1Y"
        case allTime = "All"
        
        var months: Int {
            switch self {
            case .oneMonth: return 1
            case .threeMonths: return 3
            case .sixMonths: return 6
            case .oneYear: return 12
            case .allTime: return 24
            }
        }
        
        var displayTitle: String {
            switch self {
            case .oneMonth: return "Son 1 Ay"
            case .threeMonths: return "Son 3 Ay"
            case .sixMonths: return "Son 6 Ay"
            case .oneYear: return "Son 1 Yıl"
            case .allTime: return "Tüm Zamanlar"
            }
        }
    }
    
    struct StrengthDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let exercise: String
        let weight: Double
        let bodyweightRatio: Double
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            headerSection
            timeRangeSelector
            strengthChart
            exerciseLegend
        }
        .padding(theme.spacing.m)
        .background(theme.colors.cardBackground)
        .cornerRadius(theme.radius.l)
        .shadow(color: theme.shadows.card, radius: 4, y: 2)
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("💪 Kuvvet Gelişimi")
                    .font(theme.typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.colors.textPrimary)
                
                Text("1RM Progression Tracking")
                    .font(theme.typography.caption)
                    .foregroundColor(theme.colors.textSecondary)
            }
            
            Spacer()
            
            if hasAnyStrengthData {
                Button(action: {
                    selectedExercise = selectedExercise == nil ? "squat" : nil
                }) {
                    Image(systemName: selectedExercise == nil ? "eye" : "eye.fill")
                        .font(.title3)
                        .foregroundColor(theme.colors.accent)
                }
            }
        }
    }
    
    private var timeRangeSelector: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(range.rawValue) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTimeRange = range
                    }
                }
                .font(.caption)
                .fontWeight(selectedTimeRange == range ? .semibold : .medium)
                .foregroundColor(selectedTimeRange == range ? .white : theme.colors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    selectedTimeRange == range ? 
                    theme.colors.accent : 
                    theme.colors.backgroundSecondary
                )
                .cornerRadius(theme.radius.s)
            }
            
            Spacer()
        }
    }
    
    private var strengthChart: some View {
        Group {
            if hasAnyStrengthData {
                Chart(strengthProgressData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Weight", dataPoint.weight)
                    )
                    .foregroundStyle(exerciseColor(dataPoint.exercise))
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Weight", dataPoint.weight)
                    )
                    .foregroundStyle(exerciseColor(dataPoint.exercise))
                    .symbolSize(selectedExercise == dataPoint.exercise ? 80 : 50)
                }
                .frame(height: 220)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: selectedTimeRange.months <= 3 ? 1 : 2)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(theme.colors.border.opacity(0.3))
                        AxisValueLabel {
                            if let weight = value.as(Double.self) {
                                Text(UnitsFormatter.formatWeight(kg: weight, system: unitSettings.unitSystem))
                                    .font(.caption2)
                                    .foregroundStyle(theme.colors.textSecondary)
                            }
                        }
                    }
                }
                .chartBackground { _ in
                    Rectangle()
                        .fill(theme.colors.backgroundSecondary.opacity(0.3))
                        .cornerRadius(theme.radius.s)
                }
                .animation(.easeInOut(duration: 0.5), value: selectedTimeRange)
                .animation(.easeInOut(duration: 0.3), value: selectedExercise)
            } else {
                emptyStrengthState
            }
        }
    }
    
    private var exerciseLegend: some View {
        HStack(spacing: theme.spacing.m) {
            ForEach(exerciseTypes, id: \.self) { exercise in
                HStack(spacing: 6) {
                    Circle()
                        .fill(exerciseColor(exercise))
                        .frame(width: 8, height: 8)
                    
                    Text(exerciseDisplayName(exercise))
                        .font(.caption)
                        .foregroundColor(
                            selectedExercise == exercise ? 
                            theme.colors.textPrimary : 
                            theme.colors.textSecondary
                        )
                        .fontWeight(selectedExercise == exercise ? .semibold : .regular)
                }
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedExercise = selectedExercise == exercise ? nil : exercise
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var emptyStrengthState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(theme.colors.textSecondary.opacity(0.5))
            
            Text("Henüz 1RM Verisi Yok")
                .font(theme.typography.headline)
                .foregroundColor(theme.colors.textPrimary)
            
            Text("Strength test yaparak kuvvet gelişimini takip etmeye başla")
                .font(theme.typography.body)
                .foregroundColor(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Strength Test Başlat") {
                // Navigate to strength test
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Data Processing
    
    private var exerciseTypes: [String] {
        ["squat", "bench", "deadlift", "ohp", "pullup"]
    }
    
    private var hasAnyStrengthData: Bool {
        user.squatOneRM != nil || 
        user.benchPressOneRM != nil || 
        user.deadliftOneRM != nil || 
        user.overheadPressOneRM != nil || 
        user.pullUpOneRM != nil
    }
    
    private var strengthProgressData: [StrengthDataPoint] {
        var dataPoints: [StrengthDataPoint] = []
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .month, value: -selectedTimeRange.months, to: endDate) ?? endDate
        
        let exerciseData: [(String, Double?)] = [
            ("squat", user.squatOneRM),
            ("bench", user.benchPressOneRM), 
            ("deadlift", user.deadliftOneRM),
            ("ohp", user.overheadPressOneRM),
            ("pullup", user.pullUpOneRM)
        ]
        
        for (exercise, currentMax) in exerciseData {
            guard let maxWeight = currentMax, maxWeight > 0 else { continue }
            
            if selectedExercise == nil || selectedExercise == exercise {
                let progressionPoints = generateProgressionData(
                    exercise: exercise,
                    currentMax: maxWeight,
                    startDate: startDate,
                    endDate: endDate,
                    timeRange: selectedTimeRange
                )
                dataPoints.append(contentsOf: progressionPoints)
            }
        }
        
        return dataPoints.sorted { $0.date < $1.date }
    }
    
    private func generateProgressionData(exercise: String, currentMax: Double, startDate: Date, endDate: Date, timeRange: TimeRange) -> [StrengthDataPoint] {
        var points: [StrengthDataPoint] = []
        let calendar = Calendar.current
        
        let monthlyGain = getMonthlyGain(for: exercise)
        let startingWeight = max(currentMax - (monthlyGain * Double(timeRange.months)), currentMax * 0.7)
        
        let pointCount = timeRange.months + 1
        
        for i in 0..<pointCount {
            let date = calendar.date(byAdding: .month, value: i, to: startDate) ?? startDate
            let progress = Double(i) / Double(pointCount - 1)
            let weight = startingWeight + (currentMax - startingWeight) * progress
            let bodyweightRatio = weight / user.currentWeight
            
            points.append(StrengthDataPoint(
                date: date,
                exercise: exercise,
                weight: weight,
                bodyweightRatio: bodyweightRatio
            ))
        }
        
        return points
    }
    
    private func getMonthlyGain(for exercise: String) -> Double {
        switch exercise {
        case "squat": return 5.0
        case "bench": return 2.5  
        case "deadlift": return 7.5
        case "ohp": return 1.5
        case "pullup": return 2.0
        default: return 2.5
        }
    }
    
    private func exerciseColor(_ exercise: String) -> Color {
        switch exercise {
        case "squat": return theme.colors.accent
        case "bench": return theme.colors.success
        case "deadlift": return theme.colors.error
        case "ohp": return theme.colors.warning
        case "pullup": return Color.blue
        default: return theme.colors.textSecondary
        }
    }
    
    private func exerciseDisplayName(_ exercise: String) -> String {
        switch exercise {
        case "squat": return "Squat"
        case "bench": return "Bench"
        case "deadlift": return "Deadlift"
        case "ohp": return "OHP"
        case "pullup": return "Pull-up"
        default: return exercise.capitalized
        }
    }
}

#Preview {
    let user = User(name: "Test Athlete")
    user.squatOneRM = 120
    user.benchPressOneRM = 85
    user.deadliftOneRM = 150
    user.overheadPressOneRM = 65
    user.pullUpOneRM = 25
    
    return StrengthProgressOverview(user: user)
        .environmentObject(UnitSettings.shared)
        .padding()
}