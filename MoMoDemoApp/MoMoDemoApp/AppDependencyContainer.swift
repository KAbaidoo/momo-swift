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
    private var collectionClient: MoMoCollectionClient?
    private var disbursementClient: MoMoDisbursementClient?
    
    var isReady: Bool { collectionCredentials != nil && disbursementCredentials != nil }
    
    init() {
        if let storable = CredentialStorage.shared.loadCredentials() {
            self.collectionCredentials = storable.collection
            self.disbursementCredentials = storable.disbursement
            self.collectionClient = MoMoCollectionClient(credentials: storable.collection, environment: .sandbox)
            self.disbursementClient = MoMoDisbursementClient(credentials: storable.disbursement, environment: .sandbox)
        }
    }
    
    func saveCredentials(collection: MoMoCredentials, disbursement: MoMoCredentials) throws {
        try CredentialStorage.shared.saveCredentials(collection: collection, disbursement: disbursement)
        self.collectionClient = MoMoCollectionClient(credentials: collection, environment: .sandbox)
        self.disbursementClient = MoMoDisbursementClient(credentials: disbursement, environment: .sandbox)
        self.collectionCredentials = collection
        self.disbursementCredentials = disbursement
    }
    
    // MARK: - Client Factories
    
    /// Creates a MoMoCollectionClient if credentials are available.
    func makeCollectionClient() -> MoMoCollectionClient? {
        collectionClient
    }
    
    /// Creates a MoMoDisbursementClient if credentials are available.
    func makeDisbursementClient() -> MoMoDisbursementClient? {
        disbursementClient
    }
}
