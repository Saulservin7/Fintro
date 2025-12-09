//
//  FixedExpense.swift
//  Fintro
//
//  Created by Victor Saul Servin Martinez on 30/10/25.
//

import Foundation
import FirebaseFirestore


struct FixedExpense: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var amount: Double
    var dayOfMonth: Int // El día del mes que se paga (ej. 1, 15, 25)
    var userId: String
}
