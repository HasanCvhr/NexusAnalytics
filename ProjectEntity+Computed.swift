//
//  ProjectEntity+Computed.swift
//  NexusAnalytics
//
//  Created by HASAN  on 13.07.2026.
//

import CoreData
import Foundation

// ProjectEntity'de "actualHours" adında bir Core Data attribute'u yok.
// Bu değer, o projeye ait TimeEntryEntity kayıtlarının (durationHours) toplamıdır.
// Model'de doğrudan bir relationship tanımlanmadığı için (yalnızca projectId: UUID var),
// burada projectId eşleşmesine göre manuel bir fetch ile hesaplıyoruz.
extension ProjectEntity {
    var actualHours: Double {
        guard let context = managedObjectContext, let projectId = id else { return 0 }

        let request: NSFetchRequest<TimeEntryEntity> = TimeEntryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "projectId == %@", projectId as CVarArg)

        let entries = (try? context.fetch(request)) ?? []
        return entries.reduce(0) { $0 + $1.durationHours }
    }
}
