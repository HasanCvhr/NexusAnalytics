//
//  TimeEntry.swift
//  NexusAnalytics
//
//  Created by HASAN  on 10.07.2026.
//

import Foundation

struct TimeEntry: Identifiable, Codable {
    let id: UUID
    let projectId: UUID // Hangi projeye ait olduğu
    var employeeName: String // İşlemi yapan personel
    var taskDescription: String // Yapılan işin detayı
    var durationHours: Double // Harcanan saat (Örn: 2.5 saat)
    var date: Date
}
