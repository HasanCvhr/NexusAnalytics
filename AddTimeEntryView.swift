import SwiftUI
import CoreData

struct AddTimeEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let project: ProjectEntity
    var prefilledHours: Double? = nil // YENİ: Dışarıdan otomatik saat gelirse buraya düşecek
    
    @State private var employeeName: String = ""
    @State private var taskDescription: String = ""
    @State private var durationHours: String = ""
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("\(project.name ?? "Proje") - Mesai Ekle")
                .font(.headline)
            
            Form {
                TextField("Personel Adı:", text: $employeeName)
                    .textFieldStyle(.roundedBorder)
                TextField("Yapılan İş (Görev):", text: $taskDescription)
                    .textFieldStyle(.roundedBorder)
                TextField("Harcanan Süre (Saat):", text: $durationHours)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            
            HStack(spacing: 15) {
                Button("İptal") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Mesaiyi Kaydet") { saveTimeEntry() }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 250)
        // YENİ: Ekran açıldığında kronometre verisi varsa, saati otomatik doldur!
        .onAppear {
            if let hours = prefilledHours, hours > 0 {
                durationHours = String(format: "%.4f", hours) // Saat küsuratını yazar
                taskDescription = "Canlı Zamanlayıcı Kaydı" // Görevi otomatik isimlendirir
            }
        }
        .alert("Eksik veya Hatalı Giriş", isPresented: $showingAlert) {
            Button("Anladım", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveTimeEntry() {
        let trimmedEmployee = employeeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTask = taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmployee.isEmpty else { alertMessage = "Personel adı boş bırakılamaz."; showingAlert = true; return }
        guard !trimmedTask.isEmpty else { alertMessage = "Lütfen yapılan işi açıklayın."; showingAlert = true; return }
        guard let hours = Double(durationHours), hours > 0 else { alertMessage = "Lütfen geçerli bir süre girin."; showingAlert = true; return }
        
        let newEntry = TimeEntryEntity(context: viewContext)
        newEntry.id = UUID()
        newEntry.projectId = project.id
        newEntry.employeeName = trimmedEmployee
        newEntry.taskDescription = trimmedTask
        newEntry.durationHours = hours
        newEntry.date = Date()
        
        do {
            try viewContext.save()
            // Kayıt başarılı olduğunda çalışacak cila:
            NSSound(named: "Glass")?.play() // Mac'in ikonik cam sesini çalar
            dismiss()
        } catch { print("Kayıt hatası: \(error)") }
    }
}
