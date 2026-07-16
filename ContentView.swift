import SwiftUI
import CoreData
import Charts
import UniformTypeIdentifiers

// --- Gelişmiş ve Eksiksiz Çeviri Motoru ---
func loc(_ trText: String, _ lang: String) -> String {
    if lang == "tr" { return trText }
    let enDict: [String: String] = [
        // Ana Sayfa & Dashboard
        "Şirket Genel Paneli": "Company Dashboard",
        "Dinamik Rapor Sihirbazı": "Report Wizard",
        "Proje Ara": "Search Projects",
        "Nexus Paneli": "Nexus Dashboard",
        "Güvenli Çıkış": "Secure Logout",
        "Oturumu kapatmak istediğinize emin misiniz?": "Are you sure you want to log out?",
        "Çıkış Yap": "Logout",
        "İptal": "Cancel",
        "Kullanıcı Profili": "User Profile",
        "Kullanıcı Adı": "Username",
        "Yetki Seviyesi": "Role Level",
        "Oturum Durumu": "Session Status",
        "Aktif": "Active",
        "Tam Yönetici Erişimi": "Full Admin Access",
        "Standart Personel Erişimi": "Standard Staff Access",
        "Yönetici (Admin)": "Admin",
        "Personel": "Employee",
        "Personel:": "Employee:",
        "Sadece Kritik Projeler": "Critical Projects Only",
        "Aktif Projeler": "Active Projects",
        "Toplam Harcanan": "Total Spent",
        "Kritik Projeler": "Critical Projects",
        "Ort. Bütçe Tüketimi": "Avg. Budget Use",
        "Proje Performans Grafiği": "Project Performance Chart",
        "Grafik Türü": "Chart Type",
        "Acil Dikkat Gereken Projeler": "Urgent Projects",
        "Personel Verimlilik Sıralaması": "Employee Leaderboard",
        "Yeni Proje": "New Project",
        "Şirket Genel Performans Analizi": "Company Performance Analysis",
        "Filtrelenmiş verilere göre anlık KPI ve bütçe durumu": "Real-time KPI and budget status based on filters",
        "Tümü": "All",
        "İsimsiz": "Unnamed",
        "Proje": "Project",
        "Saat": "Hours",
        "Aydınlık Moda Geç": "Switch to Light Mode",
        "Karanlık Moda Geç": "Switch to Dark Mode",
        "Bilinmeyen": "Unknown",
        "Bildirim Merkezi": "Notification Center",
        "Aktivite geçmişi temiz.": "Activity history is clean.",
        "Kritik · %": "Critical · %",
        " bütçe kullanımı": " budget used",
        " Proje": " Projects",
        " sa": " hrs",
        
        // Rapor Sihirbazı
        "Rapor Dışa Aktarma Merkezi": "Export Report Center",
        "Format:": "Format:",
        "Excel / CSV": "Excel / CSV",
        "Metin Belgesi (.txt)": "Text Document (.txt)",
        "Zaman Aralığı:": "Time Range:",
        "Son 7 Gün": "Last 7 Days",
        "Son 30 Gün": "Last 30 Days",
        "Tüm Zamanlar": "All Time",
        "Çalışan:": "Employee:",
        "Vazgeç": "Cancel",
        "Raporu Üret": "Generate Report",
        "Proje Adı": "Project Name",
        "Çalışan": "Employee",
        "Bütçe": "Budget",
        "Harcanan Saat": "Spent Hours",
        "NEXUS ANALYTICS RAPOR": "NEXUS ANALYTICS REPORT",
        "PDF İndir": "Download PDF",
        "Personel Ata": "Assign Staff",
        "Personel Atama": "Staff Assignment",
        "Sorumlu Personel:": "Assigned Staff:",
        "Atanmamış": "Unassigned",
        "Akıllı Tahminler": "Smart Predictions",
        "Belge Arşivi": "Document Archive",
        "Tamam": "OK"
    ]
    return enDict[trText] ?? trText
}

enum TimeFilter: String, CaseIterable {
    case all = "Tüm Zamanlar", month = "Bu Ay", week = "Son 7 Gün"
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.userRole) private var role
    @Environment(\.usernameKey) private var username
    @Binding var isLoggedIn: Bool

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ProjectEntity.createdAt, ascending: false)],
        animation: .default)
    private var projects: FetchedResults<ProjectEntity>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TimeEntryEntity.recordDate, ascending: true)])
    private var allTimeEntries: FetchedResults<TimeEntryEntity>

    @ObservedObject private var notificationState = NotificationManager.shared

    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("projectSortOrder") private var projectSortOrderData: Data = Data()
    @AppStorage("appLang") private var lang = "tr"

    @State private var selectedChartType: ChartType = .bar
    @State private var showingExportSheet = false
    @State private var selectedProject: ProjectEntity?
    @State private var searchText = ""
    @State private var selectedWorkerFilter: String = "Tümü"
    @State private var showOnlyCritical: Bool = false
    
    // YENİ: Bildirim Merkezi Tetikleyicisi
    @State private var showingNotifications = false
    @State private var showingAddProjectGlobal = false

    private var allWorkers: [String] {
        ["Tümü"] + Array(Set(projects.compactMap { $0.assignedUser?.lowercased() })).sorted()
    }

    private var filteredProjects: [ProjectEntity] {
        let base = projects.filter { project in
            // ADMIN İSE: Her şeyi görür, ama filtreleme (çalışan seçme) yapabilir.
            if role == .admin {
                if selectedWorkerFilter != "Tümü" && project.assignedUser?.lowercased() != selectedWorkerFilter.lowercased() {
                    return false
                }
            }
            // PERSONEL İSE: Sadece kendine atanmış olanları görür.
            else {
                if project.assignedUser?.lowercased() != username.lowercased() {
                    return false
                }
            }
            
            // Kritik proje filtresi ortak
            if showOnlyCritical {
                let budget = project.budgetHours
                let actual = project.actualHours
                if budget == 0 || (actual / budget) < 0.90 { return false }
            }
            
            return true
        }
        
        // Arama kutusu filtresi
        return searchText.isEmpty ? base : base.filter {
            ($0.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.clientName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var sortedProjects: [ProjectEntity] {
        let base = filteredProjects
        guard let savedIDs = try? JSONDecoder().decode([UUID].self, from: projectSortOrderData) else { return base }
        return base.sorted { p1, p2 in
            let id1 = p1.id ?? UUID()
            let id2 = p2.id ?? UUID()
            let index1 = savedIDs.firstIndex(of: id1) ?? Int.max
            let index2 = savedIDs.firstIndex(of: id2) ?? Int.max
            if index1 == index2 { return (p1.createdAt ?? Date()) > (p2.createdAt ?? Date()) }
            return index1 < index2
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedProject) {
                Button(action: { withAnimation { selectedProject = nil } }) {
                    HStack(spacing: 10) {
                        Image(systemName: "chart.pie.fill")
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.blue)
                            .cornerRadius(7)
                        Text(loc("Şirket Genel Paneli", lang))
                            .foregroundColor(.primary)
                    }
                }.buttonStyle(.plain)

                if role == .admin {
                    Button(action: { showingExportSheet = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.badge.gearshape.fill")
                                .foregroundColor(.white)
                                .frame(width: 26, height: 26)
                                .background(Color.green)
                                .cornerRadius(7)
                            Text(loc("Dinamik Rapor Sihirbazı", lang))
                                .foregroundColor(.primary)
                        }
                    }.buttonStyle(.plain)
                }

                Divider()

                ForEach(sortedProjects, id: \.self) { project in
                    NavigationLink(value: project) {
                        ProjectRowView(project: project, isSelected: selectedProject == project)
                    }
                }
                .onMove(perform: moveProject)
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, prompt: loc("Proje Ara", lang))
            .safeAreaInset(edge: .bottom) {
                SidebarProfileFooter(isLoggedIn: $isLoggedIn)
            }
            .navigationTitle(loc("Nexus Paneli", lang))
        } detail: {
            Group {
                if let project = selectedProject {
                    ProjectDetailView(project: project)
                        .id(project.id)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    DashboardView(
                        role: role,
                        filteredProjects: Array(filteredProjects),
                        allEntries: Array(allTimeEntries),
                        selectedChartType: $selectedChartType,
                        selectedWorkerFilter: $selectedWorkerFilter,
                        showOnlyCritical: $showOnlyCritical,
                        allWorkers: allWorkers
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: selectedProject)
            // YENİ: SAĞ ÜST BİLDİRİM ÇANI
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingNotifications.toggle()
                    }) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.red)
                    }
                    .popover(isPresented: $showingNotifications, arrowEdge: .top) {
                        NotificationCenterView()
                            .frame(width: 320, height: 400)
                    }
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $showingExportSheet) { ExportReportView() }
        .sheet(isPresented: $showingAddProjectGlobal) { AddProjectView() }
        .overlay(BannerOverlayView(notificationState: notificationState))
        .background(
            Button("") { showingAddProjectGlobal = true }
                .keyboardShortcut("n", modifiers: .command)
                .opacity(0)
        )
    }

    private func moveProject(from source: IndexSet, to destination: Int) {
        var updatedList = sortedProjects
        updatedList.move(fromOffsets: source, toOffset: destination)
        let ids = updatedList.compactMap { $0.id }
        if let encoded = try? JSONEncoder().encode(ids) { projectSortOrderData = encoded }
    }
}

// --- YENİ: BİLDİRİM MERKEZİ GÖRÜNÜMÜ ---
struct NotificationCenterView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("appLang") private var lang = "tr"
    
    // Tüm sistemdeki aktivite loglarını tarihe göre en yeniden eskiye çeker
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AuditLogEntity.timestamp, ascending: false)],
        animation: .default
    ) private var logs: FetchedResults<AuditLogEntity>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(loc("Bildirim Merkezi", lang))
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            if logs.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(loc("Aktivite geçmişi temiz.", lang))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(logs, id: \.self) { log in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: icon(for: log.actionType ?? ""))
                                        .foregroundColor(.blue)
                                        .font(.system(size: 14))
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(log.actionType ?? "İşlem")
                                        .font(.system(size: 12, weight: .bold))
                                    Spacer()
                                    if let date = log.timestamp {
                                        Text(date.formatted(date: .omitted, time: .shortened))
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Text(log.details ?? "")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // İşlem tipine göre dinamik ikon atama
    private func icon(for type: String) -> String {
        let t = type.lowercased()
        if t.contains("finans") { return "dollarsign.circle.fill" }
        if t.contains("manuel") { return "hand.tap.fill" }
        if t.contains("sil") { return "trash.fill" }
        return "bell.fill"
    }
}

// --- SOL ALT KULLANICI/ÇIKIŞ KUTUSU ---
struct SidebarProfileFooter: View {
    @Environment(\.usernameKey) private var envUsername
    @Environment(\.userRole) private var role
    @Binding var isLoggedIn: Bool
    @State private var showingLogoutConfirm = false
    @State private var showingProfileInfo = false
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("appLang") private var lang = "tr"
    
    // YENİ: Fotoğraf ve Özel İsim Hafızası
    @AppStorage("profileImageData") private var profileImageData: Data = Data()
    @AppStorage("customUsername") private var customUsername: String = ""

    // Eğer özel isim girildiyse onu, yoksa sistem ismini, o da yoksa "Yönetici"yi gösterir.
    private var displayUsername: String {
        let name = customUsername.isEmpty ? envUsername : customUsername
        return name.isEmpty ? "Yönetici" : name
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: { showingProfileInfo.toggle() }) {
                HStack(spacing: 10) {
                    
                    // FOTOĞRAF VEYA HARF GÖSTERİMİ
                    if let nsImage = NSImage(data: profileImageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(String(displayUsername.prefix(1)).uppercased())
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.accentColor)
                            )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayUsername.capitalized)
                            .font(.system(size: 13, weight: .semibold))
                        Text(role == .admin ? loc("Yönetici (Admin)", lang) : loc("Personel", lang))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingProfileInfo, arrowEdge: .top) {
                ProfileInfoCard(originalUsername: envUsername, role: role)
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { lang = (lang == "tr") ? "en" : "tr" }
            }) {
                Text(lang == "tr" ? "EN" : "TR")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(lang == "tr" ? .blue : .red)
                    .frame(width: 28, height: 28)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(lang == "tr" ? "Switch to English" : "Türkçe'ye Geç")

            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isDarkMode.toggle() }
            }) {
                Image(systemName: isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isDarkMode ? .yellow : .orange)
            }
            .buttonStyle(.plain)
            .help(isDarkMode ? loc("Aydınlık Moda Geç", lang) : loc("Karanlık Moda Geç", lang))

            Button(action: { showingLogoutConfirm = true }) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help(loc("Güvenli Çıkış", lang))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
        .confirmationDialog(loc("Güvenli Çıkış", lang), isPresented: $showingLogoutConfirm, titleVisibility: .visible) {
            Button("Çıkış Yap", role: .destructive) {
                LiveTimerEngine.shared.stopAll()
                withAnimation { isLoggedIn = false }
            }
            Button(loc("İptal", lang), role: .cancel) {}
        } message: {
            Text(loc("Oturumu kapatmak istediğinize emin misiniz?", lang))
        }
    }
}

// --- PROFİL BİLGİ KARTI (DÜZENLENEBİLİR) ---
struct ProfileInfoCard: View {
    let originalUsername: String
    let role: UserRole
    
    @AppStorage("appLang") private var lang = "tr"
    @AppStorage("profileImageData") private var profileImageData: Data = Data()
    @AppStorage("customUsername") private var customUsername: String = ""
    
    @State private var isEditing = false
    @State private var tempName = ""
    @State private var showingImagePicker = false

    private var displayUsername: String {
        let name = customUsername.isEmpty ? originalUsername : customUsername
        return name.isEmpty ? "Yönetici" : name
    }

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            
            // FOTOĞRAF ALANI (Artık daha sade ve derlenebilir)
            profileImageStack
            
            // DÜZENLENEBİLİR İSİM ALANI
            if isEditing {
                VStack(spacing: 8) {
                    TextField("Yeni İsim", text: $tempName)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 180)
                    HStack {
                        Button("İptal") { isEditing = false }
                        Button("Kaydet") {
                            customUsername = tempName
                            isEditing = false
                        }.buttonStyle(.borderedProminent)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    HStack {
                        Text(displayUsername.capitalized).font(.system(size: 16, weight: .bold))
                        Button(action: { tempName = displayUsername; isEditing = true }) {
                            Image(systemName: "pencil").font(.system(size: 12))
                        }.buttonStyle(.plain).help("İsmi Düzenle")
                    }
                    Text(role == .admin ? loc("Yönetici (Admin)", lang) : loc("Personel", lang))
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
            
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                InfoRow(icon: "checkmark.seal.fill", label: loc("Yetki Seviyesi", lang), value: role == .admin ? loc("Tam Yönetici Erişimi", lang) : loc("Standart Personel Erişimi", lang))
                InfoRow(icon: "clock.fill", label: loc("Oturum Durumu", lang), value: loc("Aktif", lang))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(width: 260)
        // FOTOĞRAF SEÇİCİ (MAC DOSYA SİSTEMİ)
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.png, .jpeg],
            allowsMultipleSelection: false
        ) { result in

            switch result {

            case .success(let urls):
                guard let url = urls.first else { return }

                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }

                profileImageData = (try? Data(contentsOf: url)) ?? Data()

            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }

    // 🌟 SİHİRLİ ÇÖZÜM: Karmaşık ZStack'i ayrı bir değişken/view yaptım
    private var profileImageStack: some View {
        ZStack(alignment: .bottomTrailing) {
            if let nsImage = NSImage(data: profileImageData), !profileImageData.isEmpty {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 70, height: 70)
                    .overlay(Text(String(displayUsername.prefix(1)).uppercased()).font(.system(size: 30, weight: .bold)).foregroundColor(.accentColor))
            }
            
            Button(action: { showingImagePicker = true }) {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                    .background(Color.white.clipShape(Circle()))
            }
            .buttonStyle(.plain)
            .offset(x: 5, y: 5)
        }
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.accentColor).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 10)).foregroundColor(.secondary)
                Text(value).font(.system(size: 12, weight: .medium))
            }
            Spacer()
        }
    }
}

// --- VERİMLİLİK SKOR MODELİ ---
struct WorkerStats: Identifiable {
    let id = UUID()
    let name: String
    let totalHours: Double
    let projectCount: Int
}

// --- DASHBOARD ---
struct DashboardView: View {
    var role: UserRole
    var filteredProjects: [ProjectEntity]
    var allEntries: [TimeEntryEntity]
    @Binding var selectedChartType: ChartType
    @Binding var selectedWorkerFilter: String
    @Binding var showOnlyCritical: Bool
    var allWorkers: [String]
    @State private var isShowingAddProject = false
    @AppStorage("appLang") private var lang = "tr"

    private var totalHours: Double { filteredProjects.reduce(0) { $0 + $1.actualHours } }
    private var totalCritical: Int { filteredProjects.filter { $0.budgetHours > 0 && ($0.actualHours / $0.budgetHours) >= 0.90 }.count }
    private var averageConsumption: Double {
        let ratios = filteredProjects.compactMap { p -> Double? in guard p.budgetHours > 0 else { return nil }; return p.actualHours / p.budgetHours }
        guard !ratios.isEmpty else { return 0 }
        return (ratios.reduce(0, +) / Double(ratios.count)) * 100
    }
    
    private var workerLeaderboard: [WorkerStats] {
        let grouped = Dictionary(grouping: allEntries) { $0.workerName ?? loc("Bilinmeyen", lang) }
        return grouped.map { (name, entries) in
            let hours = entries.reduce(0.0) { $0 + $1.durationHours }
            let distinctProjects = Set(entries.compactMap { $0.projectId }).count
            return WorkerStats(name: name, totalHours: hours, projectCount: distinctProjects)
        }.sorted { $0.totalHours > $1.totalHours }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                DashboardHeader(isShowingAddProject: $isShowingAddProject)
                FilterBar(role: role, selectedWorkerFilter: $selectedWorkerFilter, showOnlyCritical: $showOnlyCritical, allWorkers: allWorkers)

                HStack(spacing: 16) {
                    StatCard(title: loc("Aktif Projeler", lang), value: "\(filteredProjects.count)", icon: "folder.badge.gearshape", color: .blue)
                    StatCard(title: loc("Toplam Harcanan", lang), value: String(format: "%.1f%@", totalHours, loc(" sa", lang)), icon: "clock.fill", color: .purple)
                    StatCard(title: loc("Kritik Projeler", lang), value: "\(totalCritical)", icon: "exclamationmark.triangle.fill", color: .red)
                    StatCard(title: loc("Ort. Bütçe Tüketimi", lang), value: String(format: "%%%.0f", averageConsumption), icon: "gauge.with.dots.needle.67percent", color: .orange)
                }.padding(.horizontal)

                VStack(spacing: 20) {
                    HStack {
                        Text(loc("Proje Performans Grafiği", lang)).font(.headline).foregroundColor(.secondary)
                        Spacer()
                        Picker(loc("Grafik Türü", lang), selection: $selectedChartType.animation()) {
                            ForEach(ChartType.allCases, id: \.self) { type in
                                switch type {
                                case .bar: Image(systemName: "chart.bar.fill").tag(type)
                                case .line: Image(systemName: "chart.line.uptrend.xyaxis").tag(type)
                                case .pulse: Image(systemName: "waveform.path.ecg").tag(type)
                                }
                            }
                        }.pickerStyle(.segmented).frame(width: 150)
                    }

                    switch selectedChartType {
                    case .bar: ProjectBarChartView(projects: filteredProjects)
                    case .line: TrendLineChartView(projects: filteredProjects)
                    case .pulse: PulseChartView(points: PulseAnalytics.aggregateDriftSeries(for: filteredProjects, allEntries: allEntries))
                    }
                }.padding().background(Color(NSColor.windowBackgroundColor).opacity(0.4)).cornerRadius(16).padding(.horizontal)

                HStack(alignment: .top, spacing: 16) {
                    if totalCritical > 0 { CriticalProjectsList(projects: filteredProjects).frame(maxWidth: .infinity) }
                    if !workerLeaderboard.isEmpty { WorkerLeaderboardView(stats: workerLeaderboard).frame(maxWidth: .infinity) }
                }.padding(.horizontal)
            }.padding(.bottom, 30)
        }
        .background(Color.black.opacity(0.05))
        .sheet(isPresented: $isShowingAddProject) { AddProjectView() }
    }
    
}
   // .background(Color.black.opacity(0.05))
struct DashboardHeader: View {
    @Binding var isShowingAddProject: Bool
    @AppStorage("appLang") private var lang = "tr"
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc("Şirket Genel Performans Analizi", lang)).font(.title).fontWeight(.bold)
                Text(loc("Filtrelenmiş verilere göre anlık KPI ve bütçe durumu", lang)).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { isShowingAddProject = true }) { Label(loc("Yeni Proje", lang), systemImage: "plus.circle.fill") }.buttonStyle(.borderedProminent)
        }.padding(.horizontal).padding(.top)
    }
}

struct FilterBar: View {
    var role: UserRole
    @Binding var selectedWorkerFilter: String
    @Binding var showOnlyCritical: Bool
    var allWorkers: [String]
    @AppStorage("appLang") private var lang = "tr"

    var body: some View {
        HStack(spacing: 20) {
            if role == .admin {
                HStack(spacing: 6) {
                    Text(loc("Personel:", lang)).foregroundColor(.secondary).font(.subheadline)
                    Picker("", selection: $selectedWorkerFilter) {
                        ForEach(allWorkers, id: \.self) { worker in Text(worker == "Tümü" ? loc("Tümü", lang) : worker.capitalized).tag(worker) }
                    }.pickerStyle(.menu).frame(width: 150)
                }
            }
            Toggle(isOn: $showOnlyCritical.animation()) {
                Label(loc("Sadece Kritik Projeler", lang), systemImage: "exclamationmark.triangle.fill").font(.subheadline).foregroundColor(.red)
            }.toggleStyle(.switch)
            Spacer()
        }.padding(12).background(Color(NSColor.controlBackgroundColor).opacity(0.6)).cornerRadius(10).padding(.horizontal)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(value).font(.system(size: 20, weight: .bold))
            }
            Spacer()
        }
        // BURAYA DİKKAT: .padding ve .glassCard() dışında başka bir background/overlay OLMAMALI
        .padding(14)
        .glassCard()
    }
}
struct CriticalProjectsList: View {
    let projects: [ProjectEntity]
    @AppStorage("appLang") private var lang = "tr"

    private var criticalOnes: [ProjectEntity] {
        projects.filter { $0.budgetHours > 0 && ($0.actualHours / $0.budgetHours) >= 0.90 }.sorted { ($0.actualHours / $0.budgetHours) > ($1.actualHours / $1.budgetHours) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(loc("Acil Dikkat Gereken Projeler", lang), systemImage: "flame.fill").font(.headline).foregroundColor(.red)
            ForEach(criticalOnes, id: \.self) { project in
                let ratio = project.actualHours / project.budgetHours
                HStack {
                    VStack(alignment: .leading, spacing: 3) { Text(project.name ?? loc("İsimsiz", lang)).fontWeight(.semibold); Text(project.clientName ?? "").font(.caption).foregroundColor(.secondary) }
                    Spacer()
                    Text("%\(Int(ratio * 100))").font(.system(size: 15, weight: .bold)).foregroundColor(.white).padding(.horizontal, 10).padding(.vertical, 4).background(Color.red).cornerRadius(8)
                }.padding(12).background(Color.red.opacity(0.06)).cornerRadius(10)
            }
        }.padding().background(Color(NSColor.windowBackgroundColor).opacity(0.4)).cornerRadius(16)
    }
}

struct WorkerLeaderboardView: View {
    let stats: [WorkerStats]
    @AppStorage("appLang") private var lang = "tr"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(loc("Personel Verimlilik Sıralaması", lang), systemImage: "crown.fill").font(.headline).foregroundColor(.yellow)
            VStack(spacing: 8) {
                ForEach(Array(stats.prefix(5).enumerated()), id: \.element.id) { index, worker in
                    HStack {
                        ZStack {
                            Circle().fill(index == 0 ? Color.yellow : (index == 1 ? Color.gray : (index == 2 ? Color.orange : Color.blue.opacity(0.15)))).frame(width: 24, height: 24)
                            Text("\(index + 1)").font(.caption).fontWeight(.bold).foregroundColor(index < 3 ? .black : .primary)
                        }
                        Text(worker.name.capitalized).fontWeight(.semibold)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(String(format: "%.1f%@", worker.totalHours, loc(" sa", lang))).font(.system(size: 13, weight: .bold)).foregroundColor(.blue)
                            Text("\(worker.projectCount)\(loc(" Proje", lang))").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }.padding(8).background(Color.gray.opacity(0.05)).cornerRadius(8)
                }
            }
        }.padding().background(Color(NSColor.windowBackgroundColor).opacity(0.4)).cornerRadius(16)
    }
}

struct ProjectRowView: View {
    let project: ProjectEntity
    let isSelected: Bool
    @State private var pulseAnim = false
    @AppStorage("appLang") private var lang = "tr"
    
    private var projectId: UUID { project.id ?? UUID() }
    private var budgetRatio: Double { guard project.budgetHours > 0 else { return 0 }; return project.actualHours / project.budgetHours }
    private var isCritical: Bool { budgetRatio >= 0.90 }
    private var isRunning: Bool { LiveTimerEngine.shared.isRunning(projectId) }
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(isCritical ? Color.red : Color.green.opacity(0.6)).frame(width: 7, height: 7).scaleEffect(isCritical && pulseAnim ? 1.7 : 1.0).opacity(isCritical && pulseAnim ? 0.35 : 1.0)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name ?? loc("İsimsiz", lang)).fontWeight(isSelected ? .bold : .regular)
                if isCritical { Text("\(loc("Kritik · %", lang))\(Int(budgetRatio * 100))\(loc(" bütçe kullanımı", lang))").font(.system(size: 10, weight: .semibold)).foregroundColor(.red) }
                
                // İlerleme çubuğunu VSTACK'in içine, yani metinlerin altına aldık:
                ProjectProgressBar(actual: project.actualHours, budget: project.budgetHours)
                    .frame(width: 100) // Liste elemanına sığması için genişliği sınırladık
            }
            
            Spacer()
            if isRunning { Image(systemName: "waveform").foregroundColor(.blue).opacity(pulseAnim ? 0.4 : 1.0) }
        }
        .padding(.vertical, 4)
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulseAnim = true } }
    }
}

// ProjectRowView burada kapanır; yardımcı view'lar global scope'ta.
struct ProjectBarChartView: View {
    let projects: [ProjectEntity]
    @AppStorage("appLang") private var lang = "tr"
    var body: some View { Chart(projects, id: \.self) { p in BarMark(x: .value(loc("Proje", lang), p.name ?? ""), y: .value(loc("Saat", lang), p.actualHours)) }.frame(height: 200) }
}

struct TrendLineChartView: View {
    let projects: [ProjectEntity]
    @AppStorage("appLang") private var lang = "tr"
    var body: some View { Chart(projects, id: \.self) { p in LineMark(x: .value(loc("Proje", lang), p.name ?? ""), y: .value(loc("Saat", lang), p.actualHours)) }.frame(height: 200) }
}

struct BannerOverlayView: View {
    @ObservedObject var notificationState: NotificationManager
    var body: some View { EmptyView() }
}

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial.opacity(0.8)) // Opaklığı artırdık
            .cornerRadius(16)
            // Kenar çizgisini biraz daha parlak yapalım ki kartlar birbirinden ayrılsın
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func glassCard() -> some View {
        self.modifier(GlassCardModifier())
    }
}
