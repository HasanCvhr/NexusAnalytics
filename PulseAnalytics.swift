import SwiftUI
import Charts
import CoreData
import AppKit // YENİ: Panoya kopyalama işlemi (Google Sheets) için gerekli

struct DriftPoint: Identifiable {
    let id = UUID()
    let date: Date
    let actualHours: Double
    let expectedHours: Double
    var isForecast: Bool = false
    var drift: Double { actualHours - expectedHours }
}

enum PulseAnalytics {
    static func driftSeries(for project: ProjectEntity, entries: [TimeEntryEntity], days: Int = 30) -> [DriftPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today

        let totalProjectDays = max(calendar.dateComponents([.day], from: project.createdAt ?? today, to: Date()).day ?? 1, 1)
        let dailyExpected = project.budgetHours / Double(totalProjectDays)

        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.recordDate ?? today) }

        var points: [DriftPoint] = []
        var day = startDay
        var recent7DaysBurn: [Double] = []

        // 1. GERÇEKLEŞEN ZAMAN
        while day <= today {
            let dayActual = (grouped[day] ?? []).reduce(0) { $0 + $1.durationHours }
            points.append(DriftPoint(date: day, actualHours: dayActual, expectedHours: dailyExpected, isForecast: false))
            
            if day >= calendar.date(byAdding: .day, value: -7, to: today)! {
                recent7DaysBurn.append(dayActual)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        
        // 2. GELECEK TAHMİNİ (Artık hız sıfır olsa bile 14 gün ileriye zorunlu çiziyor)
        let avgBurnRate = recent7DaysBurn.isEmpty ? 0 : (recent7DaysBurn.reduce(0, +) / Double(recent7DaysBurn.count))
        
        var forecastDay = calendar.date(byAdding: .day, value: 1, to: today)!
        let endForecastDay = calendar.date(byAdding: .day, value: 14, to: today)!
        
        while forecastDay <= endForecastDay {
            points.append(DriftPoint(
                date: forecastDay,
                actualHours: avgBurnRate,
                expectedHours: dailyExpected,
                isForecast: true
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: forecastDay) else { break }
            forecastDay = next
        }
        return points
    }

    static func aggregateDriftSeries(for projects: [ProjectEntity], allEntries: [TimeEntryEntity], days: Int = 30) -> [DriftPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        let endForecastDay = calendar.date(byAdding: .day, value: 14, to: today) ?? today

        var dailyActual: [Date: Double] = [:]
        var dailyExpected: [Date: Double] = [:]

        for project in projects {
            let projectEntries = allEntries.filter { $0.projectId == project.id }
            for point in driftSeries(for: project, entries: projectEntries, days: days) {
                dailyActual[point.date, default: 0] += point.actualHours
                dailyExpected[point.date, default: 0] += point.expectedHours
            }
        }

        var points: [DriftPoint] = []
        var day = startDay
        
        while day <= endForecastDay {
            let isForecast = day > today
            points.append(DriftPoint(
                date: day,
                actualHours: dailyActual[day] ?? 0,
                expectedHours: dailyExpected[day] ?? 0,
                isForecast: isForecast
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return points
    }
}

// MARK: - GRAFİK VE DIŞA AKTARIM (GOOGLE SHEETS) ARAYÜZÜ
struct PulseChartView: View {
    let points: [DriftPoint]
    @State private var showCopiedFeedback = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // ÜST BAR: GOOGLE SHEETS AKTARIM BUTONU
            HStack {
                Text("Bütçe Sapma Analizi & Tahmin")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                
                Button(action: copyToGoogleSheets) {
                    HStack(spacing: 4) {
                        Image(systemName: showCopiedFeedback ? "checkmark.circle.fill" : "tablecells.fill")
                        Text(showCopiedFeedback ? "Kopyalandı!" : "Google Sheets'e Aktar")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(showCopiedFeedback ? .green : .blue)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(showCopiedFeedback ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            // GRAFİK ALANI
            Chart(points) { point in
                if !point.isForecast {
                    AreaMark(x: .value("Tarih", point.date), y: .value("Sapma", point.drift))
                        .foregroundStyle(
                            LinearGradient(
                                colors: point.drift >= 0 ? [.red.opacity(0.35), .red.opacity(0.02)] : [.green.opacity(0.35), .green.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom)
                        )
                }
                
                LineMark(x: .value("Tarih", point.date), y: .value("Sapma", point.drift))
                    .foregroundStyle(point.isForecast ? Color.orange : (point.drift >= 0 ? Color.red : Color.green))
                    .lineStyle(StrokeStyle(lineWidth: point.isForecast ? 2.5 : 2, dash: point.isForecast ? [6, 4] : []))
                    .interpolationMethod(.catmullRom)
                
                RuleMark(y: .value("Sıfır Hattı", 0))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .frame(height: 200)

            HStack(spacing: 16) {
                Label("Bütçe Üstü Sapma", systemImage: "circle.fill").foregroundColor(.red).font(.system(size: 10))
                Label("Bütçe Altı / Tasarruf", systemImage: "circle.fill").foregroundColor(.green).font(.system(size: 10))
                Label("14 Günlük Tahmin", systemImage: "arrow.up.forward").foregroundColor(.orange).font(.system(size: 10, weight: .bold))
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
        .cornerRadius(16)
    }
    
    // MARK: - GOOGLE SHEETS & EXCEL KOPYALAMA MOTORU (TSV Formatı)
    private func copyToGoogleSheets() {
        var tsvString = "Tarih\tHarcanan Saat\tHedeflenen Saat\tBütçe Sapması\tVeri Tipi\n"
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        
        for point in points {
            let dateStr = formatter.string(from: point.date)
            let status = point.isForecast ? "Yapay Zeka Tahmini" : "Gerçekleşen Veri"
            // \t karakteri Google Sheets ve Excel tarafından "yeni sütuna geç" olarak algılanır
            tsvString += "\(dateStr)\t\(String(format: "%.1f", point.actualHours))\t\(String(format: "%.1f", point.expectedHours))\t\(String(format: "%.1f", point.drift))\t\(status)\n"
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(tsvString, forType: .string)
        
        withAnimation { showCopiedFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopiedFeedback = false }
        }
    }
}
