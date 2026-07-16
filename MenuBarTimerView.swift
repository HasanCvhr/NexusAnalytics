//
//  MenuBarTimerView.swift
//  NexusAnalytics
//
//  Created by HASAN  on 14.07.2026.
//
import SwiftUI
import CoreData

struct MenuBarTimerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var timerEngine = LiveTimerEngine.shared
    @AppStorage("appLang") private var lang = "tr"
    
    @FetchRequest(sortDescriptors: []) private var allProjects: FetchedResults<ProjectEntity>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.blue)
                Text("Nexus Live Timer")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 10) {
                if timerEngine.runningProjects.isEmpty {
                    Text(loc("Beklemede", lang))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 10)
                } else {
                    ForEach(Array(timerEngine.runningProjects), id: \.self) { uuid in
                        if let project = allProjects.first(where: { $0.id == uuid }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name ?? loc("İsimsiz", lang))
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(project.clientName ?? "")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(formatTimeString(time: timerEngine.elapsed(for: uuid)))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding()
            
            Divider()
            
            HStack {
                Button(loc("Çıkış Yap", lang)) {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
                
                Spacer()
                
                Button("Nexus'u Aç") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
        }
        .frame(width: 280)
    }
    
    private func formatTimeString(time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
