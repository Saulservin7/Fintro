//
//  Expense.swift
//  Fintro
//
//  Created by Victor Saul Servin Martinez on 30/10/25.
//

import Foundation
import FirebaseFirestore


struct Expense: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var amount: Double
    var date: Timestamp
    var userId: String
}
