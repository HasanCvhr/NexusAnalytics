import Foundation
import UserNotifications
import SwiftUI
import Combine
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var showInAppBanner = false
    @Published var bannerTitle = ""
    @Published var bannerBody = ""
    @Published var bannerType: BannerType = .warning
    
    enum BannerType {
        case warning, success, alert
        
        var color: Color {
            switch self {
            case .warning: return Color.orange
            case .success: return Color.green
            case .alert: return Color.red
            }
        }
        
        var icon: String {
            switch self {
            case .warning: return "exclamationmark.triangle.fill"
            case .success: return "checkmark.circle.fill"
            case .alert: return "bell.badge.fill"
            }
        }
    }
    
    private init() {}
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Bildirim izni verildi.")
            }
        }
    }
    
    func triggerBudgetWarning(projectName: String, ratio: Double) {
        let isOverHundred = ratio >= 1.0
        let percentString = String(format: "%.0f%%", ratio * 100)
        
        let title = isOverHundred ? "🚨 Bütçe Aşımı Tespiti!" : "⚠️ Kritik Bütçe Eşiği!"
        let body = "'\(projectName)' projesinin zaman bütçesi \(percentString) oranında tüketildi!"
        
        DispatchQueue.main.async {
            self.bannerTitle = title
            self.bannerBody = body
            self.bannerType = isOverHundred ? .alert : .warning
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                self.showInAppBanner = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.spring()) {
                    self.showInAppBanner = false
                }
            }
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
