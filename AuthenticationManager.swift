//
//  AuthenticationManager.swift
//  NexusAnalytics
//
//  Created by HASAN  on 16.07.2026.
//

import Foundation
import LocalAuthentication
import SwiftUI
import Combine
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isUnlocked = false
    @Published var authError: String? = nil
    
    private init() {}
    
    func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        // Touch ID'nin kullanılabilir olup olmadığını kontrol ediyoruz
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Hassas yönetici (Admin) verilerine erişmek için Touch ID kullanın."
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                    } else {
                        self.authError = authenticationError?.localizedDescription ?? "Kimlik doğrulama başarısız."
                    }
                }
            }
        } else {
            // Cihazda Touch ID yoksa (veya kapak kapalıysa) Mac parolasını sor (Fallback)
            let reason = "Yönetici verilerine erişmek için sistem parolanızı girin."
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                    } else {
                        self.authError = authenticationError?.localizedDescription ?? "Parola doğrulama başarısız."
                    }
                }
            }
        }
    }
    
    func lock() {
        isUnlocked = false
    }
    // AuthenticationManager.swift içindeki lock() fonksiyonunun altına ekle:
    func authenticateForLogin(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Nexus Analytics sistemine güvenli giriş yapmak için Touch ID kullanın."
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            // Touch ID yoksa Mac şifresini sor (Fallback)
            let reason = "Sisteme giriş yapmak için kullanıcı şifrenizi doğrulayın."
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        }
    }
}
