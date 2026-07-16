//
//  PersistenceController.swift
//  NexusAnalytics
//
//  Created by HASAN  on 10.07.2026.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "NexusDataModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // Şirket içi kurumsal uygulamalarda loglama kritiktir
                fatalError("Core Data yüklenirken kritik hata oluştu: \(error), \(error.userInfo)")
            }
        }
        
        // Veri tutarlılığı için otomatik birleştirme ayarı
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
