//
//  LiveTimerEngine.swift
//  NexusAnalytics
//
//  Created by HASAN  on 14.07.2026.
//

import Foundation
import Combine

final class LiveTimerEngine: ObservableObject {
    static let shared = LiveTimerEngine()

    @Published private(set) var elapsedByProject: [UUID: TimeInterval] = [:]
    @Published private(set) var runningProjects: Set<UUID> = []

    private var startDates: [UUID: Date] = [:]
    private var cancellable: AnyCancellable?
    private let defaultsKey = "LiveTimerEngine.activeTimers"

    private init() {
        loadPersistedState()
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func isRunning(_ projectId: UUID) -> Bool {
        runningProjects.contains(projectId)
    }

    func elapsed(for projectId: UUID) -> TimeInterval {
        elapsedByProject[projectId] ?? 0
    }

    func start(projectId: UUID) {
        guard !runningProjects.contains(projectId) else { return }
        startDates[projectId] = Date()
        runningProjects.insert(projectId)
        elapsedByProject[projectId] = 0
        persistState()
    }

    /// Timer'ı durdurur, kaydedilecek toplam saniyeyi döner ve state'i temizler.
    @discardableResult
    func stopAndReset(projectId: UUID) -> TimeInterval {
        let total = elapsed(for: projectId)
        runningProjects.remove(projectId)
        startDates.removeValue(forKey: projectId)
        elapsedByProject.removeValue(forKey: projectId)
        persistState()
        return total
    }

    private func tick() {
        guard !runningProjects.isEmpty else { return }
        for id in runningProjects {
            if let start = startDates[id] {
                elapsedByProject[id] = Date().timeIntervalSince(start)
            }
        }
    }

    private func persistState() {
        let encoded = startDates.reduce(into: [String: Double]()) { result, pair in
            result[pair.key.uuidString] = pair.value.timeIntervalSince1970
        }
        UserDefaults.standard.set(encoded, forKey: defaultsKey)
    }

    private func loadPersistedState() {
        guard let saved = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Double] else { return }
        for (key, value) in saved {
            guard let uuid = UUID(uuidString: key) else { continue }
            let start = Date(timeIntervalSince1970: value)
            startDates[uuid] = start
            runningProjects.insert(uuid)
            elapsedByProject[uuid] = Date().timeIntervalSince(start)
        }
    }
public func stopAll() {
        runningProjects.removeAll()
        // Varsa timer'ları invalidade et
    }
}
