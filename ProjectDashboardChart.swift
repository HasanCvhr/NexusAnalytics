//
//  ProjectDashboardChart.swift
//  NexusAnalytics
//
//  Created by HASAN  on 14.07.2026.
//

import SwiftUI
import Charts

struct ProjectDashboardChart: View {
    let data: [ProjectChartData]
    
    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Proje", item.name),
                y: .value("Saat", item.value)
            )
            .foregroundStyle(by: .value("Tip", item.type))
        }
        .chartLegend(position: .bottom)
        .frame(height: 200)
        .padding()
    }
}
