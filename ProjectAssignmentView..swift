import SwiftUI
import CoreData

struct ProjectAssignmentView: View {
    @ObservedObject var project: ProjectEntity
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("appLang") private var lang = "tr"
    
    // Uygulamadaki personel listesi
    let staffList = ["Ahmet", "Ayşe", "Mehmet", "Can", "Zeynep"]
    
    var body: some View {
        VStack(spacing: 16) {
            
            Form {
                Section(header: Text(loc("Personel Atama", lang))) {
                    Picker(
                        loc("Sorumlu Personel:", lang),
                        selection: Binding(
                            get: {
                                project.assignedUser ?? ""
                            },
                            set: { newValue in
                                project.assignedUser = newValue
                                try? viewContext.save()
                            }
                        )
                    ) {
                        Text(loc("Atanmamış", lang))
                            .tag("")
                        
                        ForEach(staffList, id: \.self) { staff in
                            Text(staff)
                                .tag(staff)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            Divider()
            
            HStack {
                Spacer()
                
                Button(loc("Tamam", lang)) {
                    try? viewContext.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 320, height: 210)
    }
}
