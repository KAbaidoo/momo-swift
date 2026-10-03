//
//  AppDependencyContainer.swift
//  MoMoDemoApp
//
//  Created by kobby on 03/10/2026.
//

import Foundation
import MoMoCore
import MoMoCollections
import Combine

/// A centralized factory and dependency container for the MoMo Demo App.
/// This holds the session state (credentials) and acts as a factory for SDK clients.
@MainActor
class AppDependencyContainer: ObservableObject {
    @Published var credentials: MoMoCredentials?
    
    // MARK: - Client Factories
    
    /// Creates a MoMoCollectionClient if credentials are available.
    func makeCollectionClient() -> MoMoCollectionClient? {
        guard let creds = credentials else { return nil }
        // In a real app, environment might also be configurable.
        return MoMoCollectionClient(credentials: creds, environment: .sandbox)
    }
    
    // Note: Future expansions can add makeDisbursementClient() and makeRemittanceClient() here.
}
