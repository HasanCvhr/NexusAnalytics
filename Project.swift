//
//  Project.swift
//  NexusAnalytics
//
//  Created by HASAN  on 10.07.2026.
//

import Foundation

struct Project: Identifiable, Codable {
    let id: UUID
    var name: String
    var clientName: String // Şirketin iş yaptığı müşteri/departman adı
    var budgetHours: Double // Bu proje için ayrılan toplam hedef saat
    var createdAt: Date
}
