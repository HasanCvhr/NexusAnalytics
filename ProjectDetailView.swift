import SwiftUI
import CoreData
import UserNotifications
import AppKit // YENİ: PDF Kaydetme Penceresi için gerekli
import UniformTypeIdentifiers
import Combine
struct ProjectDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.usernameKey) private var username
    @Environment(\.userRole) private var role
    @ObservedObject var project: ProjectEntity
    @ObservedObject private var timerEngine = LiveTimerEngine.shared
    
    @AppStorage("appLang") private var lang = "tr"
    
    private var projectId: UUID { project.id ?? UUID() }
    private var isTimerRunning: Bool { timerEngine.isRunning(projectId) }
    private var elapsedTime: TimeInterval { timerEngine.elapsed(for: projectId) }
    @State private var showingFilePicker = false
    @State private var inputHourlyRate: Double = 0.0
    @State private var inputCurrency: String = "TRY"
    @State private var isEditingFinance = false
    @State private var selectedTabIndex = 0
    @State private var showingManualEntrySheet = false
    @State private var manualHours: Double = 1.0
    @State private var manualDate = Date()
    @State private var manualNote = ""
    @State private var showingAssignmentSheet = false
    
    private var budgetRatio: Double {
        guard project.budgetHours > 0 else { return 0 }
        return project.actualHours / project.budgetHours
    }
    
    private var isCritical: Bool { budgetRatio >= 0.90 }
    
    var body: some View {
        VStack(spacing: 0) {
            if isCritical {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("\(loc("Kritik Proje — Bütçenin %", lang))\(Int(budgetRatio * 100))\(loc("'i kullanıldı", lang))")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .font(.system(size: 12))
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 8)
                .background(Color.red)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: isCritical)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.name ?? loc("Bilinmeyen Proje", lang))
                        .font(.system(size: 24, weight: .bold))
                    Text("\(loc("Müşteri/Departman:", lang)) \(project.clientName ?? loc("Bilinmeyen", lang))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // ADMIN İSE PERSONEL ATAMA BUTONU
                if role == .admin {
                    Button(action: { showingAssignmentSheet = true }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text(
                                project.assignedUser?.isEmpty ?? true
                                ? loc("Personel Ata", lang)
                                : (project.assignedUser ?? "")
                            )
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showingAssignmentSheet) {
                        ProjectAssignmentView(project: project)
                    }
                    .padding(.trailing, 10)
                }

                Button(action: { showingManualEntrySheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(loc("Manuel Zaman Ekle", lang))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 10)
                ProjectProgressBar(actual: project.actualHours, budget: project.budgetHours)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
                Text(isTimerRunning ? loc("Şu An Çalışıyor", lang) : loc("Beklemede", lang))
                    .font(.caption).fontWeight(.bold)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(isTimerRunning ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                    .foregroundColor(isTimerRunning ? .green : .secondary)
                    .cornerRadius(8)
                    .animation(.easeInOut, value: isTimerRunning)
            }
            .padding(.horizontal, 30)
            .padding(.top, 25)
            .padding(.bottom, 15)
            
            Divider().padding(.horizontal, 30)
            
            HStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text(loc(" AKTİF ÇALIŞMA SÜRESİ", lang))
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.secondary)
                        .tracking(1)
                    
                    Text(formatTimeString(time: elapsedTime))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(isTimerRunning ? .blue : .primary)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.2), value: elapsedTime)
                    
                    Button(action: isTimerRunning ? stopAndSaveTimer : startTimer) {
                        HStack {
                            Image(systemName: isTimerRunning ? "stop.fill" : "play.fill")
                            Text(isTimerRunning ? loc("Mesaiyi Bitir", lang) : loc("Mesaiyi Başlat", lang))
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(isTimerRunning ? Color.red : Color.blue)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(12)
                
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(loc("Hedeflenen Bütçe", lang)).font(.caption).foregroundColor(.secondary)
                            Text("\(project.budgetHours, specifier: "%.1f")\(loc(" sa", lang))").font(.title3).fontWeight(.bold)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(loc("Toplam Harcanan", lang)).font(.caption).foregroundColor(.secondary)
                            Text("\(project.actualHours, specifier: "%.2f")\(loc(" sa", lang))").font(.title3).fontWeight(.bold).foregroundColor(.blue)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.05)).cornerRadius(8)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 30)
            .padding(.top, 20)
            
            FinancialSummaryCard(
                project: project,
                lang: lang,
                showingFilePicker: $showingFilePicker,
                inputHourlyRate: $inputHourlyRate,
                inputCurrency: $inputCurrency,
                isEditingFinance: $isEditingFinance
            )
           
            if let projectId = project.id {
                TabView {
                    // 1. SEKME: MESAI KAYITLARI
                    VStack(alignment: .leading, spacing: 5) {
                        List {
                            TimeEntryHistoryView(projectId: projectId)
                        }
                        .listStyle(.inset)
                    }
                    .tabItem {
                        Label(loc("Mesai Kayıtları", lang), systemImage: "clock.arrow.circlepath")
                    }
                    
                    // 2. SEKME: PULSE ANALIZ (GRAFIK)
                    ProjectPulseTabView(project: project)
                        .tabItem {
                            Label(loc("Pulse Analiz", lang), systemImage: "waveform.path.ecg")
                        }
                    
                    // 3. SEKME: YAPAY ZEKA / TAHMINLEME (YENİ)
                    ScrollView {
                        ProjectPredictionCardView(project: project)
                            .padding()
                    }
                    .tabItem {
                        Label(loc("Akıllı Tahminler", lang), systemImage: "brain.head.profile.fill")
                    }
                    
                    // 4. SEKME: BELGE ARŞİVİ (YENİ)
                    ScrollView {
                        ProjectDocumentSectionView(project: project)
                            .padding()
                    }
                    .tabItem {
                        Label(loc("Belge Arşivi", lang), systemImage: "doc.on.doc.fill")
                    }
                    
                    // 5. SEKME: AKTIVITE GÜNLÜĞÜ (SADECE ADMIN)
                    // 5. SEKME: AKTIVITE GÜNLÜĞÜ (SADECE ADMIN)
                    if role == .admin {
                        SecureAuditLogView(projectId: projectId)
                            .tabItem {
                                Label(loc("Aktivite Günlüğü", lang), systemImage: "shield.lefthalf.filled")
                            }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 15)
                .padding(.bottom, 15)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            NotificationManager.shared.requestPermission()
            inputHourlyRate = project.hourlyRate
            inputCurrency = project.currency ?? "TRY"
        }
        .sheet(isPresented: $showingManualEntrySheet) {
            VStack(spacing: 20) {
                Text(loc("Manuel Zaman Kaydı Girişi", lang))
                    .font(.headline)
                    .padding(.top, 15)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(loc("Çalışılan Süre (Saat):", lang)).font(.subheadline)
                        Spacer()
                        Stepper(value: $manualHours, in: 0.5...24.0, step: 0.5) {
                            Text(String(format: "%.1f sa", manualHours))
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                    DatePicker(loc("Çalışma Tarihi:", lang), selection: $manualDate, displayedComponents: [.date])
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc("Yapılan İşin Açıklaması / Notu:", lang)).font(.subheadline)
                        TextEditor(text: $manualNote)
                            .frame(height: 60)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                Divider()
                HStack(spacing: 15) {
                    Button(loc("İptal", lang)) {
                        showingManualEntrySheet = false
                        manualNote = ""
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button(loc("Veritabanına İşle", lang)) {
                        if manualHours > 0 {
                            let entry = TimeEntryEntity(context: viewContext)
                            entry.id = UUID()
                            entry.projectId = project.id
                            entry.durationHours = manualHours
                            entry.workerName = username
                            entry.recordDate = manualDate
                            
                            let log = AuditLogEntity(context: viewContext)
                            log.id = UUID()
                            log.projectId = project.id
                            log.workerName = username
                            log.actionType = "Manuel Giriş"
                            log.details = "Takvimden seçilen \(manualDate.formatted(date: .numeric, time: .omitted)) tarihine +\(manualHours) saat manuel giriş ekledi. Not: \(manualNote.isEmpty ? "Yok" : manualNote)"
                            log.timestamp = Date()
                            try? viewContext.save()
                        }
                        showingManualEntrySheet = false
                        manualNote = ""
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
                .padding(.bottom, 15)
            }
            .frame(width: 380, height: 320)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
    
    private func startTimer() { LiveTimerEngine.shared.start(projectId: projectId) }
    private func stopAndSaveTimer() {
        let elapsedSeconds = LiveTimerEngine.shared.stopAndReset(projectId: projectId)
        let workedHours = elapsedSeconds / 3600.0
        if workedHours > 0 {
            let newTimeEntry = TimeEntryEntity(context: viewContext)
            newTimeEntry.id = UUID()
            newTimeEntry.projectId = project.id
            newTimeEntry.durationHours = workedHours
            newTimeEntry.workerName = username
            newTimeEntry.recordDate = Date()
            try? viewContext.save()
        }
    }
    private func formatTimeString(time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - YENİ: Finansal Hakediş & Maliyet Analizi Kartı (ayrı View olarak çıkarıldı — type-checker hatasını önler)

struct FinancialSummaryCard: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.usernameKey) private var username
    @Environment(\.userRole) private var role

    @ObservedObject var project: ProjectEntity
    let lang: String

    @Binding var showingFilePicker: Bool
    @Binding var inputHourlyRate: Double
    @Binding var inputCurrency: String
    @Binding var isEditingFinance: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                Text(loc("Finansal Hakediş & Maliyet Analizi", lang))
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                
                // YENİ: PDF İNDİR BUTONU
                Button(action: {
                    exportProjectInvoiceToPDF(project: project, lang: lang)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                        Text(loc("PDF İndir", lang))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                
                if role == .admin {
                    Button(action: {
                        if isEditingFinance {
                            let log = AuditLogEntity(context: viewContext)
                            log.id = UUID()
                            log.projectId = project.id
                            log.workerName = username
                            log.actionType = "Finans Güncellendi"
                            log.details = "Saatlik ücret \(inputHourlyRate) \(inputCurrency) olarak değiştirildi."
                            log.timestamp = Date()
                            project.hourlyRate = inputHourlyRate
                            project.currency = inputCurrency
                            try? viewContext.save()
                        } else {
                            inputHourlyRate = project.hourlyRate
                            inputCurrency = project.currency ?? "TRY"
                        }
                        isEditingFinance.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isEditingFinance ? "checkmark.circle.fill" : "slider.horizontal.3")
                            Text(isEditingFinance ? loc("Kaydet", lang) : loc("Finansı Ayarla", lang))
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isEditingFinance ? .green : .blue)
                    }
                    .buttonStyle(.plain)
                }
                
                if !isEditingFinance {
                    Text("\(loc("Saatlik Ücret:", lang)) \(String(format: "%.2f %@", project.hourlyRate, project.currency ?? "TRY"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .cornerRadius(4)
                }
            }
            Divider()
            
            if isEditingFinance {
                HStack(spacing: 20) {
                    HourlyRateEditRow(inputHourlyRate: $inputHourlyRate, lang: lang)
                    CurrencyPickerRow(inputCurrency: $inputCurrency, lang: lang)
                    Spacer()
                }
                .padding(10)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
            Button(action: { showingFilePicker = true }) {
                HStack {
                    Image(systemName: "paperclip")
                    Text(loc("Dosya Yükle", lang))
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.pdf, .png, .jpeg],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let selectedFile: URL = try result.get().first else { return }
                    if selectedFile.startAccessingSecurityScopedResource() {
                        let data = try Data(contentsOf: selectedFile)
                        project.fileData = data // Core Data'da bu alanı oluşturduğundan emin ol
                        try viewContext.save()
                        selectedFile.stopAccessingSecurityScopedResource()
                    }
                } catch {
                    print("Dosya yükleme hatası: \(error.localizedDescription)")
                }
            }
            HStack(spacing: 12) {
                let earnedRevenue = project.actualHours * project.hourlyRate
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("TOPLAM HAKEDİŞ", lang)).font(.system(size: 8, weight: .black)).foregroundColor(.secondary)
                    Text(String(format: "%.2f %@", earnedRevenue, project.currency ?? "TRY"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.green.opacity(0.06))
                .cornerRadius(8)
                
                let totalBudgetCost = project.budgetHours * project.hourlyRate
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("PLANLANAN BÜTÇE", lang)).font(.system(size: 8, weight: .black)).foregroundColor(.secondary)
                    Text(String(format: "%.2f %@", totalBudgetCost, project.currency ?? "TRY"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(8)
                
                let remainingBudgetFinance = totalBudgetCost - earnedRevenue
                let isFinancialRisk = remainingBudgetFinance < 0
                VStack(alignment: .leading, spacing: 4) {
                    Text(isFinancialRisk ? loc("BÜTÇE ZARARI", lang) : loc("KALAN MARJ", lang)).font(.system(size: 8, weight: .black)).foregroundColor(.secondary)
                    Text(String(format: "%.2f %@", abs(remainingBudgetFinance), project.currency ?? "TRY"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isFinancialRisk ? .red : .blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(isFinancialRisk ? Color.red.opacity(0.06) : Color.blue.opacity(0.06))
                .cornerRadius(8)
            }
        }
        .padding(15)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .padding(.horizontal, 30)
        .padding(.top, 20)
    }
}

// MARK: - YENİ: Saatlik Ücret Düzenleme Satırı (ayrı View olarak çıkarıldı — type-checker hatasını önler)

struct HourlyRateEditRow: View {
    @Binding var inputHourlyRate: Double
    let lang: String

    private var hourlyRateFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }

    var body: some View {
        HStack {
            Text(loc("Saatlik Ücret:", lang))
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("0.00", value: $inputHourlyRate, formatter: hourlyRateFormatter)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
        }
    }
}

// MARK: - YENİ: Para Birimi Seçim Satırı (ayrı View olarak çıkarıldı — type-checker hatasını önler)

struct CurrencyPickerRow: View {
    @Binding var inputCurrency: String
    let lang: String

    var body: some View {
        HStack {
            Text(loc("Para Birimi:", lang))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Picker("", selection: $inputCurrency) {
                Text("₺ TRY").tag("TRY")
                Text("$ USD").tag("USD")
                Text("€ EUR").tag("EUR")
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
        }
    }
}

struct ProjectPulseTabView: View {
    @ObservedObject var project: ProjectEntity
    @FetchRequest var entries: FetchedResults<TimeEntryEntity>
    @AppStorage("appLang") private var lang = "tr"
    
    init(project: ProjectEntity) {
        self.project = project
        let pid = project.id ?? UUID()
        _entries = FetchRequest<TimeEntryEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \TimeEntryEntity.recordDate, ascending: true)],
            predicate: NSPredicate(format: "projectId == %@", pid as CVarArg)
        )
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(loc("Zaman Sapması (Drift) — Son 30 Gün", lang)).font(.headline)
                PulseChartView(points: PulseAnalytics.driftSeries(for: project, entries: Array(entries)))
            }.padding()
        }
    }
}

struct TimeEntryHistoryView: View {
    @FetchRequest var entries: FetchedResults<TimeEntryEntity>
    @AppStorage("appLang") private var lang = "tr"
    
    init(projectId: UUID) {
        _entries = FetchRequest<TimeEntryEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \TimeEntryEntity.recordDate, ascending: false)],
            predicate: NSPredicate(format: "projectId == %@", projectId as CVarArg)
        )
    }
    var body: some View {
        if entries.isEmpty {
            Text(loc("Henüz kaydedilmiş bir mesai bulunmuyor.", lang)).foregroundColor(.secondary).font(.subheadline)
        } else {
            ForEach(entries, id: \.self) { entry in
                HStack {
                    Image(systemName: "person.circle.fill").foregroundColor(.secondary).font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.workerName ?? loc("Sistem Personeli", lang)).font(.system(size: 13, weight: .semibold))
                        if let date = entry.recordDate {
                            Text(date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Text(String(format: "+%.1f sa", entry.durationHours)).font(.system(size: 12, weight: .bold)).foregroundColor(.green)
                }.padding(.vertical, 2)
            }
        }
    }
}

struct AuditLogHistoryView: View {
    @FetchRequest var logs: FetchedResults<AuditLogEntity>
    @AppStorage("appLang") private var lang = "tr"
    
    init(projectId: UUID) {
        _logs = FetchRequest<AuditLogEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \AuditLogEntity.timestamp, ascending: false)],
            predicate: NSPredicate(format: "projectId == %@", projectId as CVarArg)
        )
    }
    var body: some View {
        if logs.isEmpty {
            Text(loc("Bu projeye ait aktivite günlüğü temiz.", lang)).foregroundColor(.secondary).font(.subheadline)
        } else {
            ForEach(logs, id: \.self) { log in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.shield.fill").foregroundColor(.blue).font(.system(size: 14)).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(log.workerName ?? loc("Bilinmeyen", lang)).fontWeight(.bold)
                            Text("[\(log.actionType ?? "İşlem")]").foregroundColor(.secondary).font(.system(size: 10, weight: .heavy))
                            Spacer()
                            if let date = log.timestamp { Text(date.formatted(date: .numeric, time: .shortened)).font(.system(size: 10)).foregroundColor(.secondary) }
                        }.font(.system(size: 12))
                        Text(log.details ?? "").font(.system(size: 11)).foregroundColor(.primary.opacity(0.8))
                    }
                }.padding(.vertical, 4)
            }
        }
    }
}

// MARK: - YENİ: PDF FATURA ŞABLONU VE MOTORU

@MainActor
func exportProjectInvoiceToPDF(project: ProjectEntity, lang: String) {
    let invoiceView = InvoiceDocumentView(project: project, lang: lang)
    let renderer = ImageRenderer(content: invoiceView)
    
    // A4 Boyutu
    let a4Size = CGSize(width: 595, height: 842)
    renderer.proposedSize = .init(a4Size)
    
    let savePanel = NSSavePanel()
    savePanel.allowedContentTypes = [.pdf]
    savePanel.nameFieldStringValue = "Fatura_\(project.name ?? "Proje").pdf"
    
    savePanel.begin { response in
        if response == .OK, let url = savePanel.url {
            renderer.render { size, context in
                var box = CGRect(origin: .zero, size: size)
                guard let cgContext = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
                cgContext.beginPDFPage(nil)
                context(cgContext)
                cgContext.endPDFPage()
                cgContext.closePDF()
            }
        }
    }
}



struct ProjectProgressBar: View {
    let actual: Double
    let budget: Double
    
    var progress: Double {
        guard budget > 0 else { return 0 }
        return min(actual / budget, 1.0)
    }
    
    var color: Color {
        if progress >= 0.9 { return .red }
        if progress >= 0.7 { return .orange }
        return .blue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(loc("İlerleme", "tr")) // Dil desteğine göre düzenlenebilir
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("%\(Int(progress * 100))")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
            .cornerRadius(3)
        }
    }
}
// MARK: - YENİ MODÜL 1: Akıllı Bütçe Tahminleme Bileşeni
struct ProjectPredictionCardView: View {
    @ObservedObject var project: ProjectEntity
    @FetchRequest var entries: FetchedResults<TimeEntryEntity>
    @AppStorage("appLang") private var lang = "tr"
    
    init(project: ProjectEntity) {
        self.project = project
        let pid = project.id ?? UUID()
        _entries = FetchRequest<TimeEntryEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \TimeEntryEntity.recordDate, ascending: true)],
            predicate: NSPredicate(format: "projectId == %@", pid as CVarArg)
        )
    }
    
    var status: (text: String, isRisk: Bool, icon: String, color: Color) {
        let budget = project.budgetHours
        let actual = project.actualHours
        
        guard budget > 0 else { return (loc("Analiz için bütçe tanımlanması gerekiyor.", lang), false, "brain", .secondary) }
        if actual >= budget { return (loc("🚨 Bütçe limiti tamamen aşılmış! Acil aksiyon alınmalı.", lang), true, "exclamationmark.triangle.fill", .red) }
        
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentEntries = entries.filter { ($0.recordDate ?? Date()) >= sevenDaysAgo }
        let totalRecentHours = recentEntries.reduce(0.0) { $0 + $1.durationHours }
        let dailyBurnRate = totalRecentHours / 7.0
        
        if dailyBurnRate > 0 {
            let remainingHours = budget - actual
            let daysLeft = remainingHours / dailyBurnRate
            if daysLeft <= 4 {
                return (String(format: loc("⚠️ Yüksek Harcama Hızı: Bütçeniz %.1f gün içinde tükenecektir!", lang), daysLeft), true, "flame.fill", .orange)
            }
        }
        return (loc("Mevcut harcama hızı dengeli, bütçe aşım riski öngörülmüyor.", lang), false, "checkmark.shield.fill", .green)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // İkon Alanı
            Image(systemName: status.icon)
                .font(.system(size: 24))
                .foregroundColor(status.color)
                .frame(width: 44, height: 44)
                .background(status.color.opacity(0.1))
                .cornerRadius(12)
            
            // Bilgi Alanı
            VStack(alignment: .leading, spacing: 4) {
                Text(loc("AI PREDICTIVE ANALYTICS", lang))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.secondary)
                
                Text(status.text)
                    .font(.system(size: 12, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(16)
        .glassCard() // 🌟 Senin o şık cam efekti burada devrede
    }
}
struct ProjectDocumentSectionView: View {
    @ObservedObject var project: ProjectEntity
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("appLang") private var lang = "tr"
    @State private var showingFilePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(loc("Proje Belge Arşivi", lang), systemImage: "folder.fill")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                
                Button(action: { showingFilePicker = true }) {
                    Label(loc("Dosya Ekle", lang), systemImage: "paperclip")
                }
                .buttonStyle(.plain)
                .fileImporter(
                    isPresented: $showingFilePicker,
                    allowedContentTypes: [.pdf, .png, .jpeg],
                    allowsMultipleSelection: false // Derleyiciyi rahatlatmak için eklendi
                ) { result in
                    // 🌟 DERLEYİCİYİ ÇÖKERTEN KISIM DÜZELTİLDİ: Açık do-catch bloğu kullanıldı
                    do {
                        let urls = try result.get()
                        guard let url = urls.first else { return }
                        
                        if url.startAccessingSecurityScopedResource() {
                            let data = try Data(contentsOf: url)
                            project.fileData = data
                            try viewContext.save()
                            url.stopAccessingSecurityScopedResource()
                        }
                    } catch {
                        print("Dosya yükleme hatası: \(error.localizedDescription)")
                    }
                }
            }
            
            if let fileData = project.fileData {
                HStack(spacing: 12) {
                    if let nsImage = NSImage(data: fileData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .cornerRadius(6)
                    } else {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                            .frame(width: 40, height: 40)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc("Yüklenen Teknik Kanıt / Sözleşme", lang)).font(.system(size: 12, weight: .medium))
                        Text("\(Double(fileData.count) / 1024.0 / 1024.0, specifier: "%.2f") MB").font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button(action: { exportFile(data: fileData) }) {
                        Image(systemName: "square.and.arrow.down").foregroundColor(.blue)
                    }.buttonStyle(.plain).help(loc("Bilgisayara Kaydet", lang))
                    
                    Button(action: {
                        project.fileData = nil
                        try? viewContext.save()
                    }) {
                        Image(systemName: "trash").foregroundColor(.red)
                    }.buttonStyle(.plain)
                }
                .padding(10)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(8)
            } else {
                Text(loc("Bu projeye ait yüklenmiş teknik döküman bulunmuyor.", lang))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
    
    private func exportFile(data: Data) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf, .png, .jpeg]
        savePanel.nameFieldStringValue = "Nexus_Belge_\(project.name ?? "Proje")"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? data.write(to: url)
            }
        }
    }
}
// MARK: - TOUCH ID KORUMALI ADMİN EKRANI
struct SecureAuditLogView: View {
    let projectId: UUID
    @StateObject private var authManager = AuthenticationManager.shared
    @AppStorage("appLang") private var lang = "tr"
    
    var body: some View {
        ZStack {
            if authManager.isUnlocked {
                // Şifre çözüldüyse gerçek verileri göster
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Spacer()
                        Button(action: { authManager.lock() }) {
                            Label(loc("Kitle", lang), systemImage: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }.buttonStyle(.plain)
                    }.padding(.horizontal).padding(.top, 5)
                    
                    List {
                        AuditLogHistoryView(projectId: projectId)
                    }
                    .listStyle(.inset)
                }
            } else {
                // Şifre çözülmediyse Kilit Ekranını göster
                VStack(spacing: 20) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text(loc("Bu alana erişim kısıtlanmıştır.", lang))
                        .font(.headline)
                    
                    Text(loc("Aktivite günlüklerini görüntülemek için kimliğinizi doğrulayın.", lang))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: { authManager.authenticate() }) {
                        HStack {
                            Image(systemName: "touchid") // Touch ID ikonu
                                .font(.title2)
                            Text(loc("Touch ID ile Kilidi Aç", lang))
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    if let error = authManager.authError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
            }
        }
        // Sekme her açıldığında kilidi aktif et
        .onDisappear {
            authManager.lock()
        }
    }
}
    
struct InvoiceDocumentView: View {
    let project: ProjectEntity
    let lang: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            // --- HEADER: ŞİRKET BİLGİLERİ ---
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NEXUS ANALYTICS").font(.system(size: 32, weight: .black))
                    Text(loc("Hakediş ve Maliyet Raporu", lang)).font(.title3).foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(loc("TARİH", lang)).font(.caption).bold().foregroundColor(.gray)
                    Text(Date().formatted(date: .long, time: .omitted)).font(.headline)
                }
            }
            
            Divider().padding(.vertical, 10)
            
            // --- MÜŞTERİ & PROJE BİLGİLERİ ---
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc("MÜŞTERİ / DEPARTMAN", lang)).font(.caption).bold().foregroundColor(.gray)
                    Text(project.clientName ?? loc("Bilinmeyen", lang)).font(.title2).bold()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(loc("PROJE ADI", lang)).font(.caption).bold().foregroundColor(.gray)
                    Text(project.name ?? loc("İsimsiz", lang)).font(.title2).bold()
                }
            }
            
            // --- TABLO: HİZMET DÖKÜMÜ ---
            // Tablo kısmını bununla değiştir
            VStack(spacing: 0) {
                // Tablo Başlığı
                HStack {
                    Text(loc("AÇIKLAMA", lang)).bold().frame(maxWidth: .infinity, alignment: .leading)
                    Text(loc("SÜRE", lang)).bold().frame(width: 80, alignment: .trailing)
                    Text(loc("BİRİM", lang)).bold().frame(width: 80, alignment: .trailing)
                    Text(loc("TUTAR", lang)).bold().frame(width: 100, alignment: .trailing)
                }
                .padding(10)
                .background(Color.black.opacity(0.05))
                .cornerRadius(4)
                
                // Tablo Satırı
                HStack {
                    Text(loc("Proje Geliştirme ve Analiz Hizmeti", lang))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(String(format: "%.1f sa", project.actualHours))
                        .frame(width: 80, alignment: .trailing)
                    
                    Text(String(format: "%.0f %@", project.hourlyRate, project.currency ?? "TRY"))
                        .frame(width: 80, alignment: .trailing)
                    
                    Text(String(format: "%.2f %@", project.actualHours * project.hourlyRate, project.currency ?? "TRY"))
                        .bold()
                        .frame(width: 100, alignment: .trailing)
                }
                .padding(10)
                .overlay(Rectangle().frame(height: 1).foregroundColor(.black.opacity(0.1)), alignment: .bottom)
            }
            .border(Color.gray.opacity(0.3))
            
            Spacer()
            // --- GENEL TOPLAMDAN SONRAKİ KISIM ---
             // PDF'in alt kısmına itmek için

            // 1. Banka Bilgileri & Notlar
            VStack(alignment: .leading, spacing: 10) {
                Text(loc("Banka Bilgileri", lang)).font(.headline)
                Text("Nexus Analytics A.Ş. | IBAN: TR00 0000 0000 0000 0000 00").font(.caption)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.03))
            .cornerRadius(8)

            // 2. İmza Alanı (Sağ tarafa yaslı)
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text(loc("Yetkili İmza / Kaşe", lang)).font(.caption)
                    Rectangle().frame(width: 150, height: 1).foregroundColor(.black)
                }
            }
            .padding(.top, 20)

            // 3. Sayfa Numarası ve Alt Bilgi
            HStack {
                Text(loc("Bu belge Nexus Analytics sistemi tarafından otomatik olarak oluşturulmuştur.", lang))
                Spacer()
                Text("Sayfa 1 / 1")
            }
            .font(.system(size: 8))
            .foregroundColor(.gray)
            .padding(.top, 20)
            // --- FOOTER: GENEL TOPLAM ---
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text(loc("GENEL TOPLAM", lang)).font(.subheadline).bold().foregroundColor(.gray)
                    Text(String(format: "%.2f %@", project.actualHours * project.hourlyRate, project.currency ?? "TRY"))
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.blue)
                }
                .padding(20)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .padding(50)
        .frame(width: 595, height: 842) // Standart A4
        .background(Color.white)
        .foregroundColor(.black)
    }
    // --- GENEL TOPLAMDAN SONRAKİ KISIM ---
}
