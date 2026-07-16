//
//  ProjectChartData.swift
//  NexusAnalytics
//
//  Created by HASAN  on 14.07.2026.
//

import Foundation
struct ProjectChartData: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let type: String // "Bütçe" veya "Gerçekleşen"
}
