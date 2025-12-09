//
//  Paycheck.swift
//  Fintro
//
//  Created by Victor Saul Servin Martinez on 30/10/25.
//
import Foundation
import FirebaseFirestore


struct Paycheck: Identifiable, Codable {
    @DocumentID var id: String? // Mapea el ID del documento de Firestore
    var amount: Double
    var date: Timestamp // Usa el tipo de dato Timestamp de Firebase
    
    // Asociamos esta quincena a un usuario específico
    var userId: String
}
