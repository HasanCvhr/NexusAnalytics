import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ExportReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \ProjectEntity.name, ascending: true)])
    private var allProjects: FetchedResults<ProjectEntity>
    
    // Dil değişkenimiz burada (Tetikleyici)
    @AppStorage("appLang") private var lang = "tr"
    
    // --- Kullanıcı Seçenekleri ---
    @State private var selectedFormat = 0 // 0: CSV, 1: TXT
    @State private var timeRange = 1      // 0: Son 7 gün, 1: Son 30 gün, 2: Tüm Zamanlar
    @State private var selectedWorker : String = "Tümü"
    @State private var isExporting = false
    
    private var allWorkers: [String] {
        let workers = allProjects.compactMap { $0.assignedUser }
        return ["Tümü"] + Array(Set(workers)).sorted()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // YENİ: Başlık Çevirisi
            Text(loc("Rapor Dışa Aktarma Merkezi", lang))
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 10)
            
            Form {
                // YENİ: Format Çevirileri
                Picker(loc("Format:", lang), selection: $selectedFormat) {
                    Text(loc("Excel / CSV", lang)).tag(0)
                    Text(loc("Metin Belgesi (.txt)", lang)).tag(1)
                }
                
                // YENİ: Zaman Aralığı Çevirileri
                Picker(loc("Zaman Aralığı:", lang), selection: $timeRange) {
                    Text(loc("Son 7 Gün", lang)).tag(0)
                    Text(loc("Son 30 Gün", lang)).tag(1)
                    Text(loc("Tüm Zamanlar", lang)).tag(2)
                }
                
                // YENİ: Çalışan Çevirisi
                Picker(loc("Çalışan:", lang), selection: $selectedWorker) {
                    ForEach(allWorkers, id: \.self) { worker in
                        Text(worker == "Tümü" ? loc("Tümü", lang) : worker).tag(worker)
                    }
                }
            }.padding()
            
            Divider()
            
            HStack {
                // YENİ: Buton Çevirileri
                Button(loc("Vazgeç", lang)) { dismiss() }
                Spacer()
                Button(loc("Raporu Üret", lang)) { generateReport() }
                    .disabled(isExporting)
                    .buttonStyle(.borderedProminent)
            }.padding()
        }
        .frame(width: 400, height: 350)
    }
    
    private func generateReport() {
        isExporting = true
        
        let fetchEntries: NSFetchRequest<TimeEntryEntity> = TimeEntryEntity.fetchRequest()
        let allEntries = (try? viewContext.fetch(fetchEntries)) ?? []
        let entryMap = Dictionary(grouping: allEntries, by: { $0.projectId })
        
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date? = timeRange == 0 ? calendar.date(byAdding: .day, value: -7, to: now) :
                               (timeRange == 1 ? calendar.date(byAdding: .day, value: -30, to: now) : nil)
        
        let filtered = allProjects.filter { project in
            let workerMatch = (selectedWorker == "Tümü" || project.assignedUser == selectedWorker)
            let dateMatch = (startDate == nil || (project.createdAt != nil && project.createdAt! >= startDate!))
            return workerMatch && dateMatch
        }
        
        let isCSV = (selectedFormat == 0)
        
        // YENİ: Dışa aktarılan dosyanın içindeki başlıkların çevirisi
        var content = isCSV ? "\(loc("Proje Adı", lang));\(loc("Çalışan", lang));\(loc("Bütçe", lang));\(loc("Harcanan Saat", lang))\n" : "\(loc("NEXUS ANALYTICS RAPOR", lang))\n--------------------\n"
        
        for project in filtered {
            let projectId = project.id
            let totalHours = entryMap[projectId]?.reduce(0) { $0 + $1.durationHours } ?? 0.0
            
            if isCSV {
                content += "\"\(project.name ?? "")\";\"\(project.assignedUser ?? "")\";\"\(project.budgetHours)\";\"\(String(format: "%.2f", totalHours))\"\n"
            } else {
                content += "\(loc("Proje", lang)): \(project.name ?? "")\n\(loc("Çalışan:", lang)) \(project.assignedUser ?? "")\n\(loc("Bütçe", lang)): \(project.budgetHours) \(loc(" sa", lang))\n\(loc("Harcanan", lang)): \(String(format: "%.2f", totalHours)) \(loc(" sa", lang))\n--------------------\n"
            }
        }
        
        let dateString = Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = isCSV ? [.commaSeparatedText] : [.plainText]
        
        // Dosya isminin İngilizce/Türkçe dinamik olması
        let fileNamePrefix = lang == "tr" ? "Nexus_Rapor_" : "Nexus_Report_"
        savePanel.nameFieldStringValue = "\(fileNamePrefix)\(dateString).\(isCSV ? "csv" : "txt")"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    let data = content.data(using: .utf8) ?? Data()
                    let bom = Data([0xEF, 0xBB, 0xBF])
                    var finalData = bom
                    finalData.append(data)
                    
                    try finalData.write(to: url, options: .atomic)
                    dismiss()
                } catch {
                    print("Hata: \(error)")
                }
            }
            isExporting = false
        }
    }
}
