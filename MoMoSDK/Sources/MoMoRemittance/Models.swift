import Foundation
import MoMoCore
import MoMoDisbursements

public struct RemittanceTransferRequest: Codable, Sendable, Equatable {
    public let amount: String
    public let currency: String
    public let externalId: String?
    public let payee: Party
    public let payerMessage: String?
    public let payeeNote: String?
    public init(amount: String, currency: String, externalId: String? = nil, payee: Party, payerMessage: String? = nil, payeeNote: String? = nil) {
        self.amount = amount; self.currency = currency; self.externalId = externalId
        self.payee = payee; self.payerMessage = payerMessage; self.payeeNote = payeeNote
    }
}
public typealias RemittanceTransferStatus = TransferStatus

/// The API spells originatingCountry as `orginatingCountry` on the wire.
public struct CashTransferRequest: Codable, Sendable, Equatable {
    public let amount: String
    public let currency: String
    public let payee: Party
    public let externalId: String?
    public let originatingCountry: String?
    public let originalAmount: String?
    public let originalCurrency: String?
    public let payerMessage: String?
    public let payeeNote: String?
    public let payerIdentificationType: String?
    public let payerIdentificationNumber: String?
    public let payerIdentity: String?
    public let payerFirstName: String?
    public let payerSurname: String?
    public let payerLanguageCode: String?
    public let payerEmail: String?
    public let payerMsisdn: String?
    public let payerGender: String?
    enum CodingKeys: String, CodingKey { case amount, currency, payee, externalId, originalAmount, originalCurrency, payerMessage, payeeNote, payerIdentificationType, payerIdentificationNumber, payerIdentity, payerFirstName, payerLanguageCode, payerEmail, payerMsisdn, payerGender; case originatingCountry = "orginatingCountry", payerSurname = "payerSurName" }
    public init(amount: String, currency: String, payee: Party, externalId: String? = nil, originatingCountry: String? = nil, originalAmount: String? = nil, originalCurrency: String? = nil, payerMessage: String? = nil, payeeNote: String? = nil, payerIdentificationType: String? = nil, payerIdentificationNumber: String? = nil, payerIdentity: String? = nil, payerFirstName: String? = nil, payerSurname: String? = nil, payerLanguageCode: String? = nil, payerEmail: String? = nil, payerMsisdn: String? = nil, payerGender: String? = nil) {
        self.amount = amount; self.currency = currency; self.payee = payee
        self.externalId = externalId
        self.originatingCountry = originatingCountry
        self.originalAmount = originalAmount
        self.originalCurrency = originalCurrency
        self.payerMessage = payerMessage
        self.payeeNote = payeeNote
        self.payerIdentificationType = payerIdentificationType
        self.payerIdentificationNumber = payerIdentificationNumber
        self.payerIdentity = payerIdentity
        self.payerFirstName = payerFirstName
        self.payerSurname = payerSurname
        self.payerLanguageCode = payerLanguageCode
        self.payerEmail = payerEmail
        self.payerMsisdn = payerMsisdn
        self.payerGender = payerGender
    }
}
public struct CashTransferStatus: Codable, Sendable, Equatable {
    public let financialTransactionId: String?
    public let status: TransactionStatus?
    public let reason: String?
    public let amount: String?
    public let currency: String?
    public let payee: Party?
    public let externalId: String?
    public let originatingCountry: String?
    public let originalAmount: String?
    public let originalCurrency: String?
    public let payerMessage: String?
    public let payeeNote: String?
    public let payerIdentificationType: String?
    public let payerIdentificationNumber: String?
    public let payerIdentity: String?
    public let payerFirstName: String?
    public let payerSurname: String?
    public let payerLanguageCode: String?
    public let payerEmail: String?
    public let payerMsisdn: String?
    public let payerGender: String?
    enum CodingKeys: String, CodingKey { case financialTransactionId, status, reason, amount, currency, payee, externalId, originalAmount, originalCurrency, payerMessage, payeeNote, payerIdentificationType, payerIdentificationNumber, payerIdentity, payerFirstName, payerLanguageCode, payerEmail, payerMsisdn, payerGender; case originatingCountry = "orginatingCountry", payerSurname = "payerSurName" }
}
