import SwiftUI
import CoreData

struct AddProjectView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var projectName: String = ""
    @State private var clientName: String = ""
    @State private var assignedUser: String = ""
    @State private var budgetHours: String = ""
    @State private var notes: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Proje Bilgileri")) {
                    TextField("Proje Adı", text: $projectName)
                    TextField("Müşteri Adı", text: $clientName)
                    TextField("Atanan Personel (Kullanıcı Adı)", text: $assignedUser)
                }
                
                Section(header: Text("Bütçe ve Detaylar")) {
                    TextField("Bütçe Süresi (Saat)", text: $budgetHours)
                    
                    // TextEditor'ün macOS formlarında taşmasını engellemek için dikey hizaladık
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notlar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    }
                }
            }
            .formStyle(.grouped) // 🌟 REİS! macOS'teki o üst üste binme ve orantısızlığı çözen sihirli satır budur. Etiketleri kutuların üstüne alır.
            .padding()
            .navigationTitle("Yeni Proje Ekle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        saveProject()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(projectName.isEmpty || clientName.isEmpty)
                }
            }
            .frame(width: 450, height: 400) // Pencere boyutunu tam ideal ölçülere sabitledik
        }
    }
    
    private func saveProject() {
        let newProject = ProjectEntity(context: viewContext)
        newProject.id = UUID()
        newProject.name = projectName
        newProject.clientName = clientName
        newProject.assignedUser = assignedUser
        newProject.budgetHours = Double(budgetHours) ?? 0.0
        newProject.createdAt = Date()
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Veritabanına kayıt hatası: \(error)")
        }
    }
}
