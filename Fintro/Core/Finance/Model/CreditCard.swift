//
//  CreditCard.swift
//  Fintro
//
//  Created by Victor Saul Servin Martinez on 03/11/25.
//


import Foundation
import FirebaseFirestore

struct CreditCard: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String // Ej. "BBVA Azul"
    var currentDebt: Double // La deuda del mes actual
    var closingDate: Int // Día del mes (ej. 25)
    var paymentDueDate: Int // Día del mes (ej. 15 del siguiente)
    var userId: String
}

