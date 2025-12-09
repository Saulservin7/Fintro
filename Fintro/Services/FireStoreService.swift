//
//  FireStoreService.swift
//  Fintro
//
//  Created by Victor Saul Servin Martinez on 30/10/25.
//
import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth


actor FirestoreService {
    
    static let shared = FirestoreService()
    private init() {}
    
    private let db = Firestore.firestore()
    
    // Referencia a la colección principal de usuarios
    private var usersCollection: CollectionReference {
        return db.collection("users")
    }
    
    // MARK: - Helper Functions
    
    // Función para obtener el ID del usuario actual de forma segura
    private func getCurrentUserID() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuario no autenticado."])
        }
        return uid
    }
    
    // MARK: - Public API
    
    // Función para guardar un gasto
    func saveExpense(name: String, amount: Double) async throws {
        // 1. Obtenemos el ID del usuario aquí, en el servicio.
        let userId = try getCurrentUserID()
        
        // 2. Creamos el objeto Expense completo aquí.
        let newExpense = Expense(
            name: name,
            amount: amount,
            date: Timestamp(date: Date()), // El servicio también asigna la fecha.
            userId: userId
        )
        
        // 3. Lo guardamos en la subcolección correcta.
        let expenseRef = usersCollection.document(userId).collection("expenses").document()
        try expenseRef.setData(from: newExpense)
    }

    // Función para guardar ahorros
    func saveSaving(_ saving: Saving) async throws {
        let userId = try getCurrentUserID()
        let savingRef = usersCollection.document(userId).collection("savings").document()
        try savingRef.setData(from: saving)
    }
    
    // Función para guardar una quincena
    func savePaycheck(_ paycheck: Paycheck) async throws {
        let userId = try getCurrentUserID()
        let paycheckRef = usersCollection.document(userId).collection("paychecks").document()
        try paycheckRef.setData(from: paycheck)
    }
    
    // Función para escuchar los gastos en tiempo real
    func listenForExpenses() -> AsyncThrowingStream<[Expense], Error> {
        return AsyncThrowingStream { continuation in
            do {
                let userId = try getCurrentUserID()
                let listener = usersCollection.document(userId).collection("expenses")
                    .order(by: "date", descending: true)
                    .addSnapshotListener { querySnapshot, error in
                        
                        if let error = error {
                            continuation.finish(throwing: error)
                            return
                        }
                        
                        guard let documents = querySnapshot?.documents else {
                            continuation.yield([])
                            return
                        }
                        
                        let expenses = documents.compactMap { try? $0.data(as: Expense.self) }
                        continuation.yield(expenses)
                    }
                
                continuation.onTermination = { @Sendable _ in
                    listener.remove()
                }
                
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    func listenForSavings() -> AsyncThrowingStream<[Saving], Error> {
        return AsyncThrowingStream { continuation in
            do {
                let userId = try getCurrentUserID()
                let listener = usersCollection.document(userId).collection("savings")
                    .order(by: "date", descending: true)
                    .addSnapshotListener { querySnapshot, error in
                        if let error = error {
                            continuation.finish(throwing: error)
                            return
                        }
                        guard let documents = querySnapshot?.documents else {
                            continuation.yield([])
                            return
                        }

                        let savings = documents.compactMap { try? $0.data(as: Saving.self) }
                        continuation.yield(savings)
                    }

                continuation.onTermination = { @Sendable _ in listener.remove() }
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
    
    func listenForPaychecks() -> AsyncThrowingStream<[Paycheck], Error> {
        return AsyncThrowingStream { continuation in
            do {
                let userId = try getCurrentUserID()
                // Escuchamos la colección 'paychecks', ordenando por fecha para obtener la más reciente primero.
                let listener = usersCollection.document(userId).collection("paychecks")
                    .order(by: "date", descending: true)
                    .addSnapshotListener { querySnapshot, error in
                        
                        if let error = error {
                            continuation.finish(throwing: error)
                            return
                        }
                        
                        guard let documents = querySnapshot?.documents else {
                            continuation.yield([])
                            return
                        }
                        
                        // Convertimos los documentos de Firestore a nuestro modelo [Paycheck]
                        let paychecks = documents.compactMap { try? $0.data(as: Paycheck.self) }
                        continuation.yield(paychecks)
                    }
                
                // Nos aseguramos de detener el 'listener' cuando ya no se necesite para evitar fugas de memoria.
                continuation.onTermination = { @Sendable _ in
                    listener.remove()
                }
                
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
    
    
    // ... (código existente del servicio)

    // MARK: - Fixed Expenses API

    func saveFixedExpense(_ expense: FixedExpense) async throws {
        let userId = try getCurrentUserID()
        // Guardamos en una nueva sub-colección llamada "fixed_expenses"
        let expenseRef = usersCollection.document(userId).collection("fixed_expenses").document()
        try expenseRef.setData(from: expense)
    }

    func listenForFixedExpenses() -> AsyncThrowingStream<[FixedExpense], Error> {
        return AsyncThrowingStream { continuation in
            do {
                let userId = try getCurrentUserID()
                let listener = usersCollection.document(userId).collection("fixed_expenses")
                    .order(by: "dayOfMonth") // Ordenamos por el día
                    .addSnapshotListener { querySnapshot, error in
                        if let error = error {
                            continuation.finish(throwing: error)
                            return
                        }
                        guard let documents = querySnapshot?.documents else {
                            continuation.yield([])
                            return
                        }
                        let fixedExpenses = documents.compactMap { try? $0.data(as: FixedExpense.self) }
                        continuation.yield(fixedExpenses)
                    }
                
                continuation.onTermination = { @Sendable _ in
                    listener.remove()
                }
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
    
    func deleteVariableExpense(expenseId: String) async throws {
        let userId = try getCurrentUserID()
        try await usersCollection.document(userId).collection("expenses").document(expenseId).delete()
    }

    func deleteFixedExpense(expenseId: String) async throws {
        let userId = try getCurrentUserID()
        try await usersCollection.document(userId).collection("fixed_expenses").document(expenseId).delete()
    }

    // MARK: - Update API

    // Usamos setData con merge: true para actualizar, o simplemente setData para sobrescribir.
    // Sobrescribir es más simple y seguro para este caso de uso.
    func updateVariableExpense(_ expense: Expense) async throws {
        guard let expenseId = expense.id else {
            throw NSError(domain: "AppError", code: 500, userInfo: [NSLocalizedDescriptionKey: "ID de gasto no encontrado."])
        }
        let userId = try getCurrentUserID()
        let documentRef = usersCollection.document(userId).collection("expenses").document(expenseId)
        try documentRef.setData(from: expense)
    }

    func updateFixedExpense(_ expense: FixedExpense) async throws {
        guard let expenseId = expense.id else {
            throw NSError(domain: "AppError", code: 500, userInfo: [NSLocalizedDescriptionKey: "ID de gasto fijo no encontrado."])
        }
        let userId = try getCurrentUserID()
        let documentRef = usersCollection.document(userId).collection("fixed_expenses").document(expenseId)
        try documentRef.setData(from: expense)
    }

    func updateSaving(_ saving: Saving) async throws {
        guard let savingId = saving.id else { throw URLError(.badServerResponse) }
        let userId = try getCurrentUserID()
        let documentRef = usersCollection.document(userId).collection("savings").document(savingId)
        try documentRef.setData(from: saving)
    }
    

    // MARK: - Credit Card API

    func saveCreditCard(_ card: CreditCard) async throws {
        let userId = try getCurrentUserID()
        let cardRef = usersCollection.document(userId).collection("credit_cards").document()
        try cardRef.setData(from: card)
    }

    func listenForCreditCards() -> AsyncThrowingStream<[CreditCard], Error> {
        return AsyncThrowingStream { continuation in
            do {
                let userId = try getCurrentUserID()
                let listener = usersCollection.document(userId).collection("credit_cards")
                    .addSnapshotListener { querySnapshot, error in
                        if let error = error {
                            continuation.finish(throwing: error)
                            return
                        }
                        guard let documents = querySnapshot?.documents else {
                            continuation.yield([])
                            return
                        }
                        let cards = documents.compactMap { try? $0.data(as: CreditCard.self) }
                        continuation.yield(cards)
                    }
                
                continuation.onTermination = { @Sendable _ in
                    listener.remove()
                }
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    func updateCreditCard(_ card: CreditCard) async throws {
        guard let cardId = card.id else { throw URLError(.badServerResponse) }
        let userId = try getCurrentUserID()
        let documentRef = usersCollection.document(userId).collection("credit_cards").document(cardId)
        try documentRef.setData(from: card)
    }

    func deleteCreditCard(cardId: String) async throws {
        let userId = try getCurrentUserID()
        try await usersCollection.document(userId).collection("credit_cards").document(cardId).delete()
    }
}
