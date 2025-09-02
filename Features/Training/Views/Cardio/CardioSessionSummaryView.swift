import SwiftUI
import MapKit
import SwiftData

struct CardioSessionSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var unitSettings: UnitSettings
    @EnvironmentObject private var healthKitService: HealthKitService
    
    let session: CardioSession
    let user: User
    let onDismiss: (() -> Void)?
    
    init(session: CardioSession, user: User, onDismiss: (() -> Void)? = nil) {
        self.session = session
        self.user = user
        self.onDismiss = onDismiss
    }
    
    @State private var feeling: SessionFeeling = .good
    @State private var notes: String = ""
    @State private var showingShareSheet = false
    @State private var mapSnapshot: UIImage?
    @State private var mapCameraPosition = MapCameraPosition.automatic
    
    // Edit modals
    @State private var showingDurationEdit = false
    @State private var showingDistanceEdit = false
    @State private var showingCaloriesEdit = false
    @State private var showingHeartRateEdit = false
    
    // Edit values
    @State private var editHours: Int = 0
    @State private var editMinutes: Int = 0
    @State private var editSeconds: Int = 0
    @State private var editDistance: Double = 0.0
    @State private var editCalories: Int = 0
    @State private var editAvgHeartRate: Int = 0
    @State private var editMaxHeartRate: Int = 0
    
    // Edit tracking
    @State private var isDurationEdited = false
    @State private var isDistanceEdited = false
    @State private var isCaloriesEdited = false
    @State private var isHeartRateEdited = false
    
    private var routeCoordinates: [CLLocationCoordinate2D] {
        guard let routeData = session.routeData,
              let routePoints = try? JSONSerialization.jsonObject(with: routeData) as? [[String: Double]] else {
            return []
        }
        
        return routePoints.compactMap { point in
            guard let lat = point["lat"], let lng = point["lng"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.l) {
                    // Success Header
                    successHeader
                    
                    // Main Stats
                    mainStatsSection
                    
                    // Route Map (if available)
                    if !routeCoordinates.isEmpty {
                        routeMapSection
                    }
                    
                    // Detailed Stats
                    detailedStatsSection
                    
                    // Heart Rate Stats (always visible)
                    heartRateStatsSection
                    
                    // Feeling Selection
                    feelingSection
                    
                    // Notes
                    notesSection
                    
                    // Action Buttons
                    actionButtons
                }
                .padding(theme.spacing.m)
            }
            .navigationTitle("Antrenman Özeti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = createShareImage() {
                CardioShareSheet(items: [image, createShareText()])
            }
        }
        .sheet(isPresented: $showingDurationEdit) {
            DurationEditSheet(
                hours: $editHours,
                minutes: $editMinutes,
                seconds: $editSeconds,
                onSave: saveDurationEdit,
                onCancel: { showingDurationEdit = false }
            )
        }
        .sheet(isPresented: $showingDistanceEdit) {
            DistanceEditSheet(
                distance: $editDistance,
                unitSystem: unitSettings.unitSystem,
                onSave: saveDistanceEdit,
                onCancel: { showingDistanceEdit = false }
            )
        }
        .sheet(isPresented: $showingHeartRateEdit) {
            HeartRateEditSheet(
                avgHeartRate: $editAvgHeartRate,
                maxHeartRate: $editMaxHeartRate,
                onSave: saveHeartRateEdit,
                onCancel: { showingHeartRateEdit = false }
            )
        }
        .sheet(isPresented: $showingCaloriesEdit) {
            CaloriesEditSheet(
                calories: $editCalories,
                onSave: saveCaloriesEdit,
                onCancel: { showingCaloriesEdit = false }
            )
        }
    }
    
    // MARK: - Success Header
    private var successHeader: some View {
        VStack(spacing: theme.spacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(theme.colors.success)
                .symbolRenderingMode(.hierarchical)
            
            Text("Tebrikler!")
                .font(theme.typography.title2)
                .fontWeight(.bold)
                .foregroundColor(theme.colors.textPrimary)
            
            Text("Antrenmanını tamamladın")
                .font(theme.typography.body)
                .foregroundColor(theme.colors.textSecondary)
        }
        .padding(.vertical, theme.spacing.l)
    }
    
    // MARK: - Main Stats
    private var mainStatsSection: some View {
        HStack(spacing: theme.spacing.m) {
            MainStatCard(
                icon: "timer",
                value: session.formattedDuration,
                label: TrainingKeys.Cardio.duration.localized,
                color: theme.colors.accent,
                onEdit: { 
                    initializeDurationEdit()
                    showingDurationEdit = true 
                },
                isEdited: isDurationEdited
            )
            
            MainStatCard(
                icon: "location.fill",
                value: session.formattedDistance(using: unitSettings.unitSystem),
                label: TrainingKeys.Cardio.distance.localized,
                color: theme.colors.success,
                onEdit: { 
                    initializeDistanceEdit()
                    showingDistanceEdit = true 
                },
                isEdited: isDistanceEdited
            )
            
            MainStatCard(
                icon: "flame.fill",
                value: "\(session.totalCaloriesBurned ?? 0)",
                label: TrainingKeys.Cardio.calories.localized,
                color: theme.colors.warning,
                onEdit: { 
                    initializeCaloriesEdit()
                    showingCaloriesEdit = true 
                },
                isEdited: isCaloriesEdited
            )
        }
    }
    
    // MARK: - Route Map
    private var routeMapSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(theme.colors.accent)
                Text("Rotanız")
                    .font(theme.typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.colors.textPrimary)
                Spacer()
            }
            
            Map(position: $mapCameraPosition) {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(.blue, lineWidth: 4)
                
                if let start = routeCoordinates.first {
                    Marker("Başlangıç", coordinate: start)
                        .tint(.green)
                }
                
                if let end = routeCoordinates.last {
                    Marker("Bitiş", coordinate: end)
                        .tint(.red)
                }
            }
            .frame(height: 300)
            .cornerRadius(theme.radius.m)
            .onAppear {
                if !routeCoordinates.isEmpty {
                    let region = calculateRegion(for: routeCoordinates)
                    mapCameraPosition = .region(region)
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Detailed Stats
    private var detailedStatsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(theme.colors.accent)
                Text("Detaylı İstatistikler")
                    .font(theme.typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.colors.textPrimary)
                Spacer()
            }
            
            VStack(spacing: theme.spacing.s) {
                DetailStatRow(label: TrainingKeys.Cardio.averagePace.localized, value: session.formattedAveragePace(using: unitSettings.unitSystem) ?? "--:--")
                Divider()
                DetailStatRow(label: TrainingKeys.Cardio.avgSpeed.localized, value: session.formattedSpeed(using: unitSettings.unitSystem) ?? "-- \(UnitsFormatter.formatSpeedUnit(system: unitSettings.unitSystem))")
                
                if let elevation = session.elevationGain, elevation > 0 {
                    Divider()
                    DetailStatRow(label: TrainingKeys.Cardio.elevation.localized, value: UnitsFormatter.formatDistance(meters: elevation, system: unitSettings.unitSystem))
                }
                
                if let effort = session.perceivedEffort {
                    Divider()
                    DetailStatRow(label: "Algılanan Zorluk", value: "\(effort)/10")
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Heart Rate Stats
    private var heartRateStatsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(theme.colors.error)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nabız İstatistikleri")
                        .font(theme.typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.colors.textPrimary)
                    
                    if isHeartRateEdited {
                        Text("DÜZENLENDI")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.colors.accent)
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                Button(action: { 
                    initializeHeartRateEdit()
                    showingHeartRateEdit = true 
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundColor(theme.colors.accent)
                }
            }
            
            if let avgHR = session.averageHeartRate, avgHR > 0 {
                // Show existing heart rate data
                HStack(spacing: theme.spacing.xl) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ortalama")
                            .font(theme.typography.caption)
                            .foregroundColor(theme.colors.textSecondary)
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(avgHR)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(theme.colors.textPrimary)
                            Text("bpm")
                                .font(theme.typography.caption)
                                .foregroundColor(theme.colors.textSecondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Maksimum")
                            .font(theme.typography.caption)
                            .foregroundColor(theme.colors.textSecondary)
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(session.maxHeartRate ?? 0)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(theme.colors.error)
                            Text("bpm")
                                .font(theme.typography.caption)
                                .foregroundColor(theme.colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                }
            } else {
                // Show add heart rate option
                Button(action: { 
                    initializeHeartRateEdit()
                    showingHeartRateEdit = true 
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(theme.colors.accent)
                        Text("Nabız Verisi Ekle")
                            .font(theme.typography.body)
                            .foregroundColor(theme.colors.accent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(theme.colors.textSecondary)
                    }
                    .padding(theme.spacing.m)
                    .background(theme.colors.accent.opacity(0.1))
                    .cornerRadius(theme.radius.m)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .cardStyle()
    }
    
    // MARK: - Feeling Section
    private var feelingSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            Text("Nasıl Hissediyorsun?")
                .font(theme.typography.headline)
                .fontWeight(.semibold)
                .foregroundColor(theme.colors.textPrimary)
            
            HStack(spacing: theme.spacing.s) {
                ForEach(SessionFeeling.allCases, id: \.self) { feelingOption in
                    Button(action: { feeling = feelingOption }) {
                        VStack(spacing: 4) {
                            Text(feelingOption.emoji)
                                .font(.title2)
                            Text(feelingOption.displayName)
                                .font(.caption2)
                                .fontWeight(feeling == feelingOption ? .semibold : .regular)
                        }
                        .foregroundColor(feeling == feelingOption ? .white : theme.colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacing.s)
                        .background(
                            RoundedRectangle(cornerRadius: theme.radius.s)
                                .fill(feeling == feelingOption ? theme.colors.accent : theme.colors.backgroundSecondary)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            Text("Notlar (Opsiyonel)")
                .font(theme.typography.body)
                .fontWeight(.medium)
                .foregroundColor(theme.colors.textPrimary)
            
            TextField("Antrenman hakkında notlarınız...", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(theme.spacing.m)
                .background(theme.colors.backgroundSecondary)
                .cornerRadius(theme.radius.m)
                .lineLimit(3...5)
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: theme.spacing.m) {
            Button(action: saveSession) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("Kaydet")
                        .font(theme.typography.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(theme.spacing.l)
                .background(theme.colors.accent)
                .cornerRadius(theme.radius.m)
            }
            
            Button(action: discardSession) {
                Text("Kaydetmeden Çık")
                    .font(theme.typography.body)
                    .foregroundColor(theme.colors.textSecondary)
            }
        }
        .padding(.vertical, theme.spacing.l)
    }
    
    // MARK: - Helper Methods
    private func calculateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }
        
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLon - minLon) * 1.3
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    private func saveSession() {
        // Update session with feeling and notes
        session.feeling = feeling.rawValue
        session.sessionNotes = notes.isEmpty ? nil : notes
        session.completeSession()
        
        // Save to context
        modelContext.insert(session)
        
        // Update user stats
        user.addCardioSession(
            duration: TimeInterval(session.totalDuration),
            distance: session.totalDistance
        )
        
        do {
            try modelContext.save()
            Logger.info("Cardio session saved successfully")
            
            // Log activity for dashboard
            ActivityLoggerService.shared.logCardioCompleted(
                activityType: session.workoutName,
                distance: session.totalDistance,
                duration: TimeInterval(session.totalDuration),
                calories: Double(session.totalCaloriesBurned ?? 0),
                user: user
            )
            
            // Save to HealthKit
            Task {
                let success = await healthKitService.saveCardioWorkout(
                    activityType: session.workoutName,
                    duration: TimeInterval(session.totalDuration),
                    distance: session.totalDistance > 0 ? session.totalDistance : nil,
                    caloriesBurned: session.totalCaloriesBurned.map { Double($0) },
                    averageHeartRate: session.averageHeartRate.map { Double($0) },
                    maxHeartRate: session.maxHeartRate.map { Double($0) },
                    startDate: session.startDate,
                    endDate: session.completedAt ?? Date()
                )
                
                if success {
                    Logger.info("Cardio workout successfully synced to HealthKit")
                }
            }
            
            // Dismiss with callback
            if let onDismiss = onDismiss {
                onDismiss()
            } else {
                dismiss()
            }
        } catch {
            Logger.error("Failed to save cardio session: \(error)")
        }
    }
    
    private func discardSession() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
    
    private func createShareText() -> String {
        var text = "🏃 Antrenmanımı tamamladım!\n\n"
        text += "⏱ Süre: \(session.formattedDuration)\n"
        text += "📍 Mesafe: \(session.formattedDistance(using: unitSettings.unitSystem))\n"
        text += "🔥 Kalori: \(session.totalCaloriesBurned ?? 0) kcal\n"
        
        if let pace = session.formattedAveragePace(using: unitSettings.unitSystem) {
            text += "⚡ Tempo: \(pace)\n"
        }
        
        text += "\n#Thrustr #Fitness"
        
        return text
    }
    
    private func createShareImage() -> UIImage? {
        // TODO: Create a nice share image with stats
        return nil
    }
    
    // MARK: - Edit Methods
    private func initializeDurationEdit() {
        let totalSeconds = session.totalDuration
        editHours = totalSeconds / 3600
        editMinutes = (totalSeconds % 3600) / 60
        editSeconds = totalSeconds % 60
    }
    
    private func saveDurationEdit() {
        let originalDuration = session.totalDuration
        let newDuration = editHours * 3600 + editMinutes * 60 + editSeconds
        
        if newDuration != originalDuration {
            isDurationEdited = true
            
            // Update user stats with the change
            user.updateCardioSession(
                oldDuration: TimeInterval(originalDuration),
                oldDistance: 0,
                newDuration: TimeInterval(newDuration),
                newDistance: 0
            )
            
            session.totalDuration = newDuration
            
            // Save to database
            do {
                try modelContext.save()
                Logger.info("Cardio session duration updated successfully")
            } catch {
                Logger.error("Failed to save cardio session duration: \(error)")
            }
        }
        
        showingDurationEdit = false
    }
    
    private func initializeDistanceEdit() {
        // Convert meters to user's preferred unit for editing
        switch unitSettings.unitSystem {
        case .metric:
            editDistance = session.totalDistance / 1000.0 // Convert to km
        case .imperial:
            editDistance = session.totalDistance * 0.000621371 // Convert to miles
        }
    }
    
    private func saveDistanceEdit() {
        let originalDistance = session.totalDistance
        
        // Convert user input back to meters for storage
        let newDistanceMeters: Double
        switch unitSettings.unitSystem {
        case .metric:
            newDistanceMeters = editDistance * 1000.0 // km to meters
        case .imperial:
            newDistanceMeters = editDistance * 1609.34 // miles to meters
        }
        
        if abs(newDistanceMeters - originalDistance) > 0.1 { // Allow for minor floating point differences
            isDistanceEdited = true
            
            // Update user stats with the change
            user.updateCardioSession(
                oldDuration: 0,
                oldDistance: originalDistance,
                newDuration: 0,
                newDistance: newDistanceMeters
            )
            
            session.totalDistance = newDistanceMeters
            
            // Recalculate dependent metrics
            session.calculateTotals()
            
            // Save to database
            do {
                try modelContext.save()
                Logger.info("Cardio session distance updated successfully")
                
                // Force UI refresh by triggering objectWillChange
                DispatchQueue.main.async {
                    self.unitSettings.objectWillChange.send()
                }
            } catch {
                Logger.error("Failed to save cardio session distance: \(error)")
            }
        }
        
        showingDistanceEdit = false
    }
    
    private func initializeHeartRateEdit() {
        editAvgHeartRate = session.averageHeartRate ?? 0
        editMaxHeartRate = session.maxHeartRate ?? 0
    }
    
    private func saveHeartRateEdit() {
        let originalAvg = session.averageHeartRate ?? 0
        let originalMax = session.maxHeartRate ?? 0
        
        if editAvgHeartRate != originalAvg || editMaxHeartRate != originalMax {
            isHeartRateEdited = true
            session.averageHeartRate = editAvgHeartRate > 0 ? editAvgHeartRate : nil
            session.maxHeartRate = editMaxHeartRate > 0 ? editMaxHeartRate : nil
            
            // Save to database
            do {
                try modelContext.save()
                Logger.info("Cardio session heart rate updated successfully")
            } catch {
                Logger.error("Failed to save cardio session heart rate: \(error)")
            }
        }
        
        showingHeartRateEdit = false
    }
    
    private func initializeCaloriesEdit() {
        editCalories = session.totalCaloriesBurned ?? 0
    }
    
    private func saveCaloriesEdit() {
        let originalCalories = session.totalCaloriesBurned ?? 0
        
        if editCalories != originalCalories {
            isCaloriesEdited = true
            session.totalCaloriesBurned = editCalories > 0 ? editCalories : nil
            
            // Save to database
            do {
                try modelContext.save()
                Logger.info("Cardio session calories updated successfully")
            } catch {
                Logger.error("Failed to save cardio session calories: \(error)")
            }
        }
        
        showingCaloriesEdit = false
    }
}

// MARK: - Main Stat Card
struct MainStatCard: View {
    @Environment(\.theme) private var theme
    let icon: String
    let value: String
    let label: String
    let color: Color
    let onEdit: (() -> Void)?
    let isEdited: Bool
    
    init(icon: String, value: String, label: String, color: Color, onEdit: (() -> Void)? = nil, isEdited: Bool = false) {
        self.icon = icon
        self.value = value
        self.label = label
        self.color = color
        self.onEdit = onEdit
        self.isEdited = isEdited
    }
    
    var body: some View {
        VStack(spacing: theme.spacing.s) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                if let onEdit = onEdit {
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.caption)
                            .foregroundColor(theme.colors.accent)
                    }
                }
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(theme.colors.textPrimary)
            
            HStack(spacing: theme.spacing.xs) {
                Text(label)
                    .font(theme.typography.caption)
                    .foregroundColor(theme.colors.textSecondary)
                
                if isEdited {
                    Text("DÜZENLENDI")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.colors.accent)
                        .cornerRadius(4)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacing.m)
        .background(theme.colors.backgroundSecondary)
        .cornerRadius(theme.radius.m)
    }
}

// MARK: - Detail Stat Row
struct DetailStatRow: View {
    @Environment(\.theme) private var theme
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(theme.typography.body)
                .foregroundColor(theme.colors.textSecondary)
            Spacer()
            Text(value)
                .font(theme.typography.body)
                .fontWeight(.semibold)
                .foregroundColor(theme.colors.textPrimary)
        }
        .padding(.vertical, theme.spacing.xs)
    }
}

// MARK: - Duration Edit Sheet
struct DurationEditSheet: View {
    @Environment(\.theme) private var theme
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: theme.spacing.l) {
                // Header
                VStack(spacing: theme.spacing.s) {
                    Image(systemName: "timer")
                        .font(.system(size: 40))
                        .foregroundColor(theme.colors.accent)
                    
                    Text("Süre Düzenle")
                        .font(theme.typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.colors.textPrimary)
                    
                    Text("Antrenman sürenizi ayarlayın")
                        .font(theme.typography.body)
                        .foregroundColor(theme.colors.textSecondary)
                }
                .padding(.top, theme.spacing.l)
                
                // Time Picker
                VStack(spacing: theme.spacing.m) {
                    Text("Süre")
                        .font(theme.typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.colors.textPrimary)
                    
                    HStack(spacing: theme.spacing.m) {
                        // Hours
                        VStack(spacing: theme.spacing.xs) {
                            Text("Saat")
                                .font(theme.typography.caption)
                                .foregroundColor(theme.colors.textSecondary)
                            
                            Picker("Hours", selection: $hours) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text("\(hour)")
                                        .tag(hour)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 60, height: 120)
                        }
                        
                        Text(":")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(theme.colors.textPrimary)
                        
                        // Minutes
                        VStack(spacing: theme.spacing.xs) {
                            Text("Dakika")
                                .font(theme.typography.caption)
                                .foregroundColor(theme.colors.textSecondary)
                            
                            Picker("Minutes", selection: $minutes) {
                                ForEach(0..<60, id: \.self) { minute in
                                    Text(String(format: "%02d", minute))
                                        .tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 60, height: 120)
                        }
                        
                        Text(":")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(theme.colors.textPrimary)
                        
                        // Seconds
                        VStack(spacing: theme.spacing.xs) {
                            Text("Saniye")
                                .font(theme.typography.caption)
                                .foregroundColor(theme.colors.textSecondary)
                            
                            Picker("Seconds", selection: $seconds) {
                                ForEach(0..<60, id: \.self) { second in
                                    Text(String(format: "%02d", second))
                                        .tag(second)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 60, height: 120)
                        }
                    }
                }
                .cardStyle()
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: theme.spacing.m) {
                    Button(action: onSave) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                            Text("Kaydet")
                                .font(theme.typography.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(theme.spacing.l)
                        .background(theme.colors.accent)
                        .cornerRadius(theme.radius.m)
                    }
                    
                    Button(action: onCancel) {
                        Text("İptal")
                            .font(theme.typography.body)
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
            }
            .padding(theme.spacing.m)
            .navigationTitle("Süre Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("İptal", action: onCancel)
                }
            }
        }
    }
}

// MARK: - Distance Edit Sheet
struct DistanceEditSheet: View {
    @Environment(\.theme) private var theme
    @Binding var distance: Double
    let unitSystem: UnitSystem
    let onSave: () -> Void
    let onCancel: () -> Void
    
    private var unitLabel: String {
        unitSystem == .metric ? "km" : "mi"
    }
    
    private var unitDescription: String {
        unitSystem == .metric ? "kilometre" : "mil"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: theme.spacing.l) {
                // Header
                VStack(spacing: theme.spacing.s) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 40))
                        .foregroundColor(theme.colors.success)
                    
                    Text("Mesafe Düzenle")
                        .font(theme.typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.colors.textPrimary)
                    
                    Text("Antrenman mesafenizi \(unitDescription) cinsinden ayarlayın")
                        .font(theme.typography.body)
                        .foregroundColor(theme.colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, theme.spacing.l)
                
                // Distance Input
                VStack(spacing: theme.spacing.m) {
                    Text("Mesafe (\(unitLabel))")
                        .font(theme.typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.colors.textPrimary)
                    
                    VStack(spacing: theme.spacing.s) {
                        TextField("0.0", value: $distance, format: .number.precision(.fractionLength(1...2)))
                            .textFieldStyle(.plain)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(theme.colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                            .padding(theme.spacing.m)
                            .background(theme.colors.backgroundSecondary)
                            .cornerRadius(theme.radius.m)
                        
                        Text(unitLabel)
                            .font(theme.typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
                .cardStyle()
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: theme.spacing.m) {
                    Button(action: onSave) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                            Text("Kaydet")
                                .font(theme.typography.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(theme.spacing.l)
                        .background(theme.colors.success)
                        .cornerRadius(theme.radius.m)
                    }
                    
                    Button(action: onCancel) {
                        Text("İptal")
                            .font(theme.typography.body)
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
            }
            .padding(theme.spacing.m)
            .navigationTitle("Mesafe Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("İptal", action: onCancel)
                }
            }
        }
    }
}

// MARK: - Heart Rate Edit Sheet
struct HeartRateEditSheet: View {
    @Environment(\.theme) private var theme
    @Binding var avgHeartRate: Int
    @Binding var maxHeartRate: Int
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: theme.spacing.l) {
                // Header
                VStack(spacing: theme.spacing.s) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundColor(theme.colors.error)
                    
                    Text("Nabız Düzenle")
                        .font(theme.typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.colors.textPrimary)
                    
                    Text("Ortalama ve maksimum nabız değerlerinizi girin")
                        .font(theme.typography.body)
                        .foregroundColor(theme.colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, theme.spacing.l)
                
                // Heart Rate Inputs
                VStack(spacing: theme.spacing.xl) {
                    // Average Heart Rate
                    VStack(spacing: theme.spacing.s) {
                        Text("Ortalama Nabız (BPM)")
                            .font(theme.typography.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.colors.textPrimary)
                        
                        TextField("0", value: $avgHeartRate, format: .number)
                            .textFieldStyle(.plain)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(theme.colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .padding(theme.spacing.m)
                            .background(theme.colors.backgroundSecondary)
                            .cornerRadius(theme.radius.m)
                    }
                    
                    // Maximum Heart Rate
                    VStack(spacing: theme.spacing.s) {
                        Text("Maksimum Nabız (BPM)")
                            .font(theme.typography.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.colors.textPrimary)
                        
                        TextField("0", value: $maxHeartRate, format: .number)
                            .textFieldStyle(.plain)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(theme.colors.error)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .padding(theme.spacing.m)
                            .background(theme.colors.backgroundSecondary)
                            .cornerRadius(theme.radius.m)
                    }
                }
                .cardStyle()
                
                // Info
                VStack(spacing: theme.spacing.xs) {
                    Text("💡 İpucu")
                        .font(theme.typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.colors.accent)
                    
                    Text("Normal dinlenme nabzı 60-100 BPM, maksimum nabız yaklaşık (220 - yaş) formülü ile hesaplanır")
                        .font(theme.typography.caption)
                        .foregroundColor(theme.colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(theme.spacing.s)
                .background(theme.colors.accent.opacity(0.1))
                .cornerRadius(theme.radius.s)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: theme.spacing.m) {
                    Button(action: onSave) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                            Text("Kaydet")
                                .font(theme.typography.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(theme.spacing.l)
                        .background(theme.colors.error)
                        .cornerRadius(theme.radius.m)
                    }
                    
                    Button(action: onCancel) {
                        Text("İptal")
                            .font(theme.typography.body)
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
            }
            .padding(theme.spacing.m)
            .navigationTitle("Nabız Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("İptal", action: onCancel)
                }
            }
        }
    }
}

// MARK: - Calories Edit Sheet
struct CaloriesEditSheet: View {
    @Environment(\.theme) private var theme
    @Binding var calories: Int
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: theme.spacing.l) {
                // Header
                VStack(spacing: theme.spacing.s) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundColor(theme.colors.warning)
                    
                    Text("Kalori Düzenle")
                        .font(theme.typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.colors.textPrimary)
                    
                    Text("Yaktığınız kalori miktarını girin")
                        .font(theme.typography.body)
                        .foregroundColor(theme.colors.textSecondary)
                }
                .padding(.top, theme.spacing.l)
                
                // Calories Input
                VStack(spacing: theme.spacing.m) {
                    Text("Yakılan Kalori")
                        .font(theme.typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.colors.textPrimary)
                    
                    VStack(spacing: theme.spacing.s) {
                        TextField("0", value: $calories, format: .number)
                            .textFieldStyle(.plain)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(theme.colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .padding(theme.spacing.m)
                            .background(theme.colors.backgroundSecondary)
                            .cornerRadius(theme.radius.m)
                        
                        Text("kcal")
                            .font(theme.typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
                .cardStyle()
                
                // Info
                VStack(spacing: theme.spacing.xs) {
                    Text("💡 İpucu")
                        .font(theme.typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.colors.accent)
                    
                    Text("Ortalama olarak koşu 60-100 kcal/km, bisiklet 30-50 kcal/km yakar")
                        .font(theme.typography.caption)
                        .foregroundColor(theme.colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(theme.spacing.s)
                .background(theme.colors.accent.opacity(0.1))
                .cornerRadius(theme.radius.s)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: theme.spacing.m) {
                    Button(action: onSave) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                            Text("Kaydet")
                                .font(theme.typography.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(theme.spacing.l)
                        .background(theme.colors.warning)
                        .cornerRadius(theme.radius.m)
                    }
                    
                    Button(action: onCancel) {
                        Text("İptal")
                            .font(theme.typography.body)
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
            }
            .padding(theme.spacing.m)
            .navigationTitle("Kalori Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("İptal", action: onCancel)
                }
            }
        }
    }
}

// MARK: - Share Sheet
struct CardioShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}