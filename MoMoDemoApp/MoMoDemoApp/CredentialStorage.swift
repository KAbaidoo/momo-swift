//
//  CredentialStorage.swift
//  MoMoDemoApp
//
//  Created by kobby on 03/10/2026.
//

import Foundation
import Security
import MoMoCore

/// A secure storage utility for persisting MoMoCredentials in the iOS Keychain.
public class CredentialStorage {
    public static let shared = CredentialStorage()
    private let service = "com.momo.demoapp.credentials"
    
    private init() {} // Prevent external initialization
    
    // Internal struct to make encoding/decoding easy
    private struct StorableCredentials: Codable {
        let apiUser: String
        let apiKey: String
        let subscriptionKey: String
    }
    
    public func saveCredentials(_ credentials: MoMoCredentials) throws {
        let storable = StorableCredentials(
            apiUser: credentials.apiUser,
            apiKey: credentials.apiKey,
            subscriptionKey: credentials.subscriptionKey
        )
        
        let data = try JSONEncoder().encode(storable)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "momo-sandbox-account"
        ]
        
        // Delete existing item if it exists
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainError", code: Int(status), userInfo: nil)
        }
    }
    
    public func loadCredentials() -> MoMoCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "momo-sandbox-account",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }
        
        do {
            let decoded = try JSONDecoder().decode(StorableCredentials.self, from: data)
            return MoMoCredentials(
                apiUser: decoded.apiUser,
                apiKey: decoded.apiKey,
                subscriptionKey: decoded.subscriptionKey
            )
        } catch {
            return nil
        }
    }
}
