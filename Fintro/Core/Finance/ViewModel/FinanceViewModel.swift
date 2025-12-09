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
    @Published var allSavings: [Saving] = []
    
    // --- Estado de la App ---
    @Published var currentPeriod: Period = .first // <-- CAMBIO AQUÍ
    @Published var expenseToEdit: Expense? // Para la hoja de edición de gastos variables
    @Published var fixedExpenseToEdit: FixedExpense? // Para la hoja de edición de gastos fijos
    @Published var cardToEdit: CreditCard?
    
    // --- Campos para Formularios ---
    @Published var expenseName: String = ""
    @Published var expenseAmount: String = ""
    @Published var expenseDate: Date = Date()
    @Published var paycheckAmount: String = ""
    @Published var fixedExpenseName: String = ""
    @Published var fixedExpenseAmount: String = ""
    @Published var fixedExpenseDay: String = ""
    @Published var cardName = ""; @Published var cardDebt = ""; @Published var cardClosingDate = ""; @Published var cardPaymentDate = "" // <-- NUEVO
    @Published var savingAmount: String = ""
    
    // MARK: - Propiedades Calculadas (El Cerebro)
    
    // Título para la UI
    var periodName: String {
        currentPeriod == .first ? "Primera Quincena" : "Segunda Quincena"
    }
    
    // Ingreso de la quincena más reciente
    var currentPaycheckAmount: Double {
        allPaychecks.first?.amount ?? 0
    }

    var currentSavingsAmount: Double {
        allSavings.first?.amount ?? 0
    }
    
    // Filtra los gastos fijos que corresponden a la quincena actual
    var fixedExpensesForCurrentPeriod: [FixedExpense] {
        allFixedExpenses.filter { currentPeriod.contains(day: $0.dayOfMonth) }
    }
    
    // Filtra los gastos variables que corresponden a la quincena actual
    var variableExpensesForCurrentPeriod: [Expense] {
        guard let range = dateRange(for: currentPeriod) else { return [] }

        return allVariableExpenses.filter { expense in
            let expenseDate = expense.date.dateValue()
            return expenseDate >= range.start && expenseDate <= range.end
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
        creditCardsForCurrentPeriod.reduce(0) { $0 + $1.currentDebt }
    }

    // Filtra las tarjetas cuya fecha de pago pertenece a la quincena actual
    var creditCardsForCurrentPeriod: [CreditCard] {
        allCreditCards.filter { currentPeriod.contains(day: $0.paymentDueDate) }
    }
    
    // El balance restante para la quincena
    var remainingBalance: Double {
            currentPaycheckAmount - totalPeriodExpenses - totalCreditCardDebt
        }

    // Historial mensual de balances
    var monthlyBalanceHistory: [MonthlyBalance] {
        let calendar = Calendar.current

        let monthComponents = allVariableExpenses.map { calendar.dateComponents([.year, .month], from: $0.date.dateValue()) } +
        allPaychecks.map { calendar.dateComponents([.year, .month], from: $0.date.dateValue()) }

        let monthStarts = Set(monthComponents.compactMap { calendar.date(from: $0) })
        let fixedTotal = allFixedExpenses.reduce(0) { $0 + $1.amount }

        let summaries: [MonthlyBalance] = monthStarts.compactMap { monthStart in
            let income = allPaychecks
                .filter { calendar.isDate($0.date.dateValue(), equalTo: monthStart, toGranularity: .month) }
                .reduce(0) { $0 + $1.amount }

            let variableExpenses = allVariableExpenses
                .filter { calendar.isDate($0.date.dateValue(), equalTo: monthStart, toGranularity: .month) }
                .reduce(0) { $0 + $1.amount }

            return MonthlyBalance(month: monthStart, income: income, variableExpenses: variableExpenses, fixedExpenses: fixedTotal)
        }

        return summaries.sorted { $0.month > $1.month }
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
            listenForSavings()
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
            let cardsToDelete = offsets.map { creditCardsForCurrentPeriod[$0] }
            Task {
                for card in cardsToDelete where card.id != nil {
                    try? await firestoreService.deleteCreditCard(cardId: card.id!)
                }
            }
        }
    
    func clearCardFields() {
            cardName = ""; cardDebt = ""; cardClosingDate = ""; cardPaymentDate = ""
        }

    func prefillSavingAmount() {
        savingAmount = currentSavingsAmount > 0 ? String(currentSavingsAmount) : ""
    }

        func clearAndDismissEditing() {
            clearVariableExpenseFields()
            clearFixedExpenseFields()
            clearCardFields()
            expenseToEdit = nil
            fixedExpenseToEdit = nil
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

    private func dateRange(for period: Period, referenceDate: Date = Date()) -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        guard let day = components.day else { return nil }

        var startComponents = components
        var endComponents = components

        switch period {
        case .first:
            if day >= 14 {
                startComponents.day = 14
                endComponents.day = 28
            } else {
                guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: referenceDate) else { return nil }
                startComponents = calendar.dateComponents([.year, .month], from: previousMonth)
                endComponents = startComponents
                startComponents.day = 14
                endComponents.day = 28
            }
        case .second:
            if day >= 29 {
                startComponents.day = 29
                guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: referenceDate) else { return nil }
                endComponents = calendar.dateComponents([.year, .month], from: nextMonth)
                endComponents.day = 13
            } else {
                guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: referenceDate) else { return nil }
                startComponents = calendar.dateComponents([.year, .month], from: previousMonth)
                startComponents.day = 29
                endComponents.day = 13
            }
        }

        guard let startDateBase = calendar.date(from: startComponents),
              let endDateBase = calendar.date(from: endComponents) else { return nil }

        let startDate = calendar.startOfDay(for: startDateBase)
        let endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDateBase) ?? endDateBase
        return (start: startDate, end: endDate)
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

    private func listenForSavings() {
        Task {
            for try await savings in await firestoreService.listenForSavings() {
                self.allSavings = savings
            }
        }
    }
    
    // MARK: - Acciones del Usuario
    
    func addPaycheck() {
        guard let amount = Double(paycheckAmount), let userId = Auth.auth().currentUser?.uid else { return }
        let newPaycheck = Paycheck(amount: amount, date: Timestamp(date: Date()), userId: userId)
        Task { try? await firestoreService.savePaycheck(newPaycheck); paycheckAmount = "" }
    }

    func prefillPaycheckAmount() {
        paycheckAmount = currentPaycheckAmount > 0 ? String(currentPaycheckAmount) : ""
    }
    
    func addVariableExpense() {
        guard let amount = Double(expenseAmount) else { return }
        let selectedDate = expenseDate
        Task {
            try? await firestoreService.saveExpense(name: expenseName, amount: amount, date: selectedDate)
            clearVariableExpenseFields()
        }
    }

    func addOrUpdateSaving() {
        guard let amount = Double(savingAmount), let userId = Auth.auth().currentUser?.uid else { return }

        if var existingSaving = allSavings.first {
            existingSaving.amount = amount
            existingSaving.date = Timestamp(date: Date())
            Task { try? await firestoreService.updateSaving(existingSaving); savingAmount = "" }
        } else {
            let newSaving = Saving(amount: amount, date: Timestamp(date: Date()), userId: userId)
            Task { try? await firestoreService.saveSaving(newSaving); savingAmount = "" }
        }
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
            expenseDate = expense.date.dateValue()
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
            expense.date = Timestamp(date: expenseDate)
            
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
            expenseDate = Date()
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

struct MonthlyBalance: Identifiable {
    let month: Date
    let income: Double
    let variableExpenses: Double
    let fixedExpenses: Double

    var balance: Double { income - variableExpenses - fixedExpenses }
    var id: String { DateFormatter.monthIdentifier.string(from: month) }
    var displayMonth: String { DateFormatter.monthAndYear.string(from: month) }
}

private extension DateFormatter {
    static let monthAndYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    static let monthIdentifier: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()
}
