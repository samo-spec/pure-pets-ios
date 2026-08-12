//
//  PPProviderProfileHeroStore.swift
//  Pure Pets Pro
//
//  State management for Provider Profile Hero component
//

import Foundation
import SwiftUI
import Combine

@available(iOS 16.0, *)
@MainActor
final class PPProviderProfileHeroStore: ObservableObject {
    enum Location {
        case phone
        case video
    }
    
    @Published var providerName: String = ""
    @Published var avatarURL: URL?
    @Published var status: String?
    @Published var subtitle: String?
    @Published var description: String?
    @Published var location: Location = .phone
    
    @Published var isLive: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    var canMessage: Bool { true }
    var canCall: Bool { location == .phone }
    var canRate: Bool { true }
    
    init(provider: UserModel? = nil) {
        configure(from: provider)
    }
    
    func configure(from provider: UserModel?) {
        guard let provider = provider else { return }
        
        self.providerName = provider.bestDisplayName()
        self.avatarURL = provider.userImageUrl.flatMap { URL(string: $0) }
        self.location = provider.hasPhone ? .phone : .video
        
        self.status = provider.isVerified ? "Verified" : nil
        
        let skills = [provider.primarySkill, provider.secondarySkill].compactMap { $0 }.filter { !$0.isEmpty }
        self.subtitle = skills.joined(separator: " • ")
        
        self.description = provider.bio?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isLive = provider.isOnline
    }
    
    func asyncLoad(from provider: UserModel?) async {
        isLoading = true
        error = nil
        
        await Task.yield()
        
        configure(from: provider)
        
        isLoading = false
    }
    
    func refresh() async {
        // Implement refresh logic if needed
    }
    
    @discardableResult
    func report() async -> Bool {
        guard let providerID = try? await fetchProviderID() else { return false }
        
        // Report logic would go here
        return true
    }
    
    func onMessage() {
        // Handle message action
    }
    
    func onCall() {
        // Handle call action
    }
    
    func onRate() {
        // Handle rate action
    }
    
    private func fetchProviderID() async throws -> String {
        // Return provider ID if needed
        return UUID().uuidString
    }
}

fileprivate extension UserModel {
    var hasPhone: Bool {
        !mobileNo?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
    }
}