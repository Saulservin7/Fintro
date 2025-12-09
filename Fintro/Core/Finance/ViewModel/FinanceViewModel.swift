import Foundation
import Combine
import Firebase
import FirebaseAuth

@MainActor
class FinanceViewModel: ObservableObject {
    
    // --- Fuentes de Datos de Firestore ---
    @Published var allPaychecks: [Paycheck] = []
    @Published var allVariableExpenses: [Expense] = []
    @Published var allFixedExpenses: [FixedExpense] = []
    @Published var allCreditCards: [CreditCard] = [] // <-- NUEVO
    
    // --- Estado de la App ---
    @Published var currentPeriod: Period = .first // <-- CAMBIO AQUÍ
    @Published var expenseToEdit: Expense? // Para la hoja de edición de gastos variables
    @Published var fixedExpenseToEdit: FixedExpense? // Para la hoja de edición de gastos fijos
    @Published var cardToEdit: CreditCard?
    
    // --- Campos para Formularios ---
    @Published var expenseName: String = ""
    @Published var expenseAmount: String = ""
    @Published var paycheckAmount: String = ""
    @Published var fixedExpenseName: String = ""
    @Published var fixedExpenseAmount: String = ""
    @Published var fixedExpenseDay: String = ""
    @Published var cardName = ""; @Published var cardDebt = ""; @Published var cardClosingDate = ""; @Published var cardPaymentDate = "" // <-- NUEVO
    
    // MARK: - Propiedades Calculadas (El Cerebro)
    
    // Título para la UI
    var periodName: String {
        currentPeriod == .first ? "Primera Quincena" : "Segunda Quincena"
    }
    
    // Ingreso de la quincena más reciente
    var currentPaycheckAmount: Double {
        allPaychecks.first?.amount ?? 0
    }
    
    // Filtra los gastos fijos que corresponden a la quincena actual
    var fixedExpensesForCurrentPeriod: [FixedExpense] {
        allFixedExpenses.filter { currentPeriod.contains(day: $0.dayOfMonth) }
    }
    
    // Filtra los gastos variables que corresponden a la quincena actual
    var variableExpensesForCurrentPeriod: [Expense] {
        let now = Date()
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        return allVariableExpenses.filter { expense in
            let expenseDate = expense.date.dateValue()
            let expenseMonth = calendar.component(.month, from: expenseDate)
            let expenseYear = calendar.component(.year, from: expenseDate)
            let expenseDay = calendar.component(.day, from: expenseDate)
            
            // Debe ser del mismo mes/año y pertenecer al periodo actual
            return expenseMonth == currentMonth && expenseYear == currentYear && currentPeriod.contains(day: expenseDay)
        }
    }
    
    // Suma total de TODOS los gastos de este periodo
    var totalPeriodExpenses: Double {
            let fixedTotal = fixedExpensesForCurrentPeriod.reduce(0) { $0 + $1.amount }
            let variableTotal = variableExpensesForCurrentPeriod.reduce(0) { $0 + $1.amount }
            return fixedTotal + variableTotal
        }
    
    // Suma de las deudas de tarjetas de crédito CON FECHA DE PAGO en este periodo.
    var totalCreditCardDebt: Double {
        // 1. Filtramos las tarjetas
        let cardsDueThisPeriod = allCreditCards.filter { card in
            // 2. Usamos la misma lógica del enum Period para ver si la fecha de pago cae en el periodo actual
            currentPeriod.contains(day: card.paymentDueDate)
        }
        
        // 3. Sumamos solo la deuda de esas tarjetas filtradas
        return cardsDueThisPeriod.reduce(0) { $0 + $1.currentDebt }
    }
    
    // El balance restante para la quincena
    var remainingBalance: Double {
            currentPaycheckAmount - totalPeriodExpenses - totalCreditCardDebt
        }
    
    private let firestoreService = FirestoreService.shared
    
    init() {
        // Determinamos la quincena actual al iniciar
        setDefaultPeriod()
                listenForAllData()
    }
    
    private func listenForAllData() {
            listenForPaychecks()
            listenForExpenses()
            listenForFixedExpenses()
            listenForCreditCards() // <-- NUEVO
        }
    
    private func listenForCreditCards() {
            Task {
                for try await cards in await firestoreService.listenForCreditCards() {
                    self.allCreditCards = cards
                }
            }
        }
    
    
    func addCreditCard() {
            guard let debt = Double(cardDebt),
                  let closingDay = Int(cardClosingDate),
                  let paymentDay = Int(cardPaymentDate),
                  let userId = Auth.auth().currentUser?.uid else { return }
            
            let newCard = CreditCard(name: cardName, currentDebt: debt, closingDate: closingDay, paymentDueDate: paymentDay, userId: userId)
            Task { try? await firestoreService.saveCreditCard(newCard); clearCardFields() }
        }

        func setupEditing(card: CreditCard) {
            cardToEdit = card
            cardName = card.name
            cardDebt = String(card.currentDebt)
            cardClosingDate = String(card.closingDate)
            cardPaymentDate = String(card.paymentDueDate)
        }
        
        func updateCreditCard() {
            guard var card = cardToEdit,
                  let debt = Double(cardDebt),
                  let closingDay = Int(cardClosingDate),
                  let paymentDay = Int(cardPaymentDate) else { return }
            
            card.name = cardName
            card.currentDebt = debt
            card.closingDate = closingDay
            card.paymentDueDate = paymentDay
            
            Task { try? await firestoreService.updateCreditCard(card); clearAndDismissEditing() }
        }
        
        func deleteCreditCard(at offsets: IndexSet) {
            let cardsToDelete = offsets.map { allCreditCards[$0] }
            Task {
                for card in cardsToDelete where card.id != nil {
                    try? await firestoreService.deleteCreditCard(cardId: card.id!)
                }
            }
        }
    
    func clearCardFields() {
            cardName = ""; cardDebt = ""; cardClosingDate = ""; cardPaymentDate = ""
        }

        func clearAndDismissEditing() {
            // ... (código existente)
            clearCardFields()
            cardToEdit = nil
        }
    
    // MARK: - Lógica Interna
    
    // Esta función ahora usa la nueva lógica del enum
    private func setDefaultPeriod() {
        let dayOfMonth = Calendar.current.component(.day, from: Date())
        
        // Usamos nuestra propia lógica para ver en qué "ventana de gasto" estamos
        if Period.first.contains(day: dayOfMonth) {
            // Si hoy es día 18, estamos en la ventana de gasto del "Pago 1"
            self.currentPeriod = .first
        } else {
            // Si hoy es día 5, estamos en la ventana de gasto del "Pago 2"
            self.currentPeriod = .second
        }
    }
    
    // --- Lógica de "Escucha" ---
    private func listenForPaychecks() {
        Task {
            for try await paychecks in await firestoreService.listenForPaychecks() { self.allPaychecks = paychecks }
        }
    }
    
    private func listenForExpenses() {
        Task {
            for try await expenses in await firestoreService.listenForExpenses() { self.allVariableExpenses = expenses }
        }
    }
    
    private func listenForFixedExpenses() {
        Task {
            for try await fixedExpenses in await firestoreService.listenForFixedExpenses() { self.allFixedExpenses = fixedExpenses }
        }
    }
    
    // MARK: - Acciones del Usuario
    
    func addPaycheck() {
        guard let amount = Double(paycheckAmount), let userId = Auth.auth().currentUser?.uid else { return }
        let newPaycheck = Paycheck(amount: amount, date: Timestamp(date: Date()), userId: userId)
        Task { try? await firestoreService.savePaycheck(newPaycheck); paycheckAmount = "" }
    }
    
    func addVariableExpense() {
        guard let amount = Double(expenseAmount) else { return }
        Task { try? await firestoreService.saveExpense(name: expenseName, amount: amount); expenseName = ""; expenseAmount = "" }
    }
    
    func addFixedExpense() {
        guard let amount = Double(fixedExpenseAmount),
              let day = Int(fixedExpenseDay),
              (1...31).contains(day), // Validación simple del día
              let userId = Auth.auth().currentUser?.uid else { return }
        
        let newFixedExpense = FixedExpense(name: fixedExpenseName, amount: amount, dayOfMonth: day, userId: userId)
        Task {
            try? await firestoreService.saveFixedExpense(newFixedExpense)
            fixedExpenseName = ""
            fixedExpenseAmount = ""
            fixedExpenseDay = ""
        }
    }
    
    
    func setupEditing(variableExpense expense: Expense) {
            expenseToEdit = expense
            expenseName = expense.name
            expenseAmount = String(expense.amount)
        }

        func setupEditing(fixedExpense expense: FixedExpense) {
            fixedExpenseToEdit = expense
            fixedExpenseName = expense.name
            fixedExpenseAmount = String(expense.amount)
            fixedExpenseDay = String(expense.dayOfMonth)
        }
        
        func updateVariableExpense() {
            guard var expense = expenseToEdit, let amount = Double(expenseAmount) else { return }
            
            expense.name = expenseName
            expense.amount = amount
            
            Task {
                try? await firestoreService.updateVariableExpense(expense)
                clearAndDismissEditing()
            }
        }

        func updateFixedExpense() {
            guard var expense = fixedExpenseToEdit,
                  let amount = Double(fixedExpenseAmount),
                  let day = Int(fixedExpenseDay),
                  (1...31).contains(day) else { return }

            expense.name = fixedExpenseName
            expense.amount = amount
            expense.dayOfMonth = day

            Task {
                try? await firestoreService.updateFixedExpense(expense)
                clearAndDismissEditing()
            }
        }

        // --- ELIMINACIÓN (DELETE) ---

        func deleteVariableExpense(at offsets: IndexSet) {
            let expensesToDelete = offsets.map { variableExpensesForCurrentPeriod[$0] }
            Task {
                for expense in expensesToDelete {
                    if let id = expense.id {
                        try? await firestoreService.deleteVariableExpense(expenseId: id)
                    }
                }
            }
        }

        func deleteFixedExpense(at offsets: IndexSet) {
            let expensesToDelete = offsets.map { fixedExpensesForCurrentPeriod[$0] }
            Task {
                for expense in expensesToDelete {
                    if let id = expense.id {
                        try? await firestoreService.deleteFixedExpense(expenseId: id)
                    }
                }
            }
        }
        
        // --- Helpers ---
        
        func clearVariableExpenseFields() {
            expenseName = ""
            expenseAmount = ""
        }

        func clearFixedExpenseFields() {
            fixedExpenseName = ""
            fixedExpenseAmount = ""
            fixedExpenseDay = ""
        }
        
      
    
    
    }


// Pequeño enum para hacer el código más legible
// Pequeño enum para hacer el código más legible
// Pequeño enum para hacer el código más legible
enum Period: CaseIterable, Identifiable {
    case first
    case second
    
    var id: Self { self }
    
    // Nombres actualizados para ser más claros
    var displayName: String {
        switch self {
        case .first:
            // Este es el dinero del pago del 14
            return "Pago 1 (Gastos 15-28)"
        case .second:
            // Este es el dinero del pago del 29
            return "Pago 2 (Gastos 29-14)"
        }
    }
    
    // --- ESTA ES LA LÓGICA CLAVE ACTUALIZADA ---
    // Define qué días "pertenecen" a este periodo de pago
    func contains(day: Int) -> Bool {
        switch self {
        case .first:
            // El Pago 1 (día 14) cubre las deudas del 15 al 28
            return day >= 14 && day <= 28
        case .second:
            // El Pago 2 (día 29) cubre las deudas del 29 hasta el 14
            return day >= 29 || day <= 13
        }
    }
}
