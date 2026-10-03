//
//  AppDependencyContainer.swift
//  MoMoDemoApp
//
//  Created by kobby on 03/10/2026.
//

import Foundation
import MoMoCore
import MoMoCollections
import MoMoDisbursements
import Combine

/// A centralized factory and dependency container for the MoMo Demo App.
/// This holds the session state (credentials) and acts as a factory for SDK clients.
@MainActor
class AppDependencyContainer: ObservableObject {
    @Published var collectionCredentials: MoMoCredentials?
    @Published var disbursementCredentials: MoMoCredentials?
    
    var isReady: Bool { collectionCredentials != nil && disbursementCredentials != nil }
    
    init() {
        if let storable = CredentialStorage.shared.loadCredentials() {
            self.collectionCredentials = storable.collection
            self.disbursementCredentials = storable.disbursement
        }
    }
    
    func saveCredentials(collection: MoMoCredentials, disbursement: MoMoCredentials) {
        self.collectionCredentials = collection
        self.disbursementCredentials = disbursement
        try? CredentialStorage.shared.saveCredentials(collection: collection, disbursement: disbursement)
    }
    
    // MARK: - Client Factories
    
    /// Creates a MoMoCollectionClient if credentials are available.
    func makeCollectionClient() -> MoMoCollectionClient? {
        guard let creds = collectionCredentials else { return nil }
        // In a real app, environment might also be configurable.
        return MoMoCollectionClient(credentials: creds, environment: .sandbox)
    }
    
    /// Creates a MoMoDisbursementClient if credentials are available.
    func makeDisbursementClient() -> MoMoDisbursementClient? {
        guard let creds = disbursementCredentials else { return nil }
        return MoMoDisbursementClient(credentials: creds, environment: .sandbox)
    }
}
