import SwiftUI

struct MonthlyBalanceDetailView: View {
    let summary: MonthlyBalance
    let paychecks: [Paycheck]
    let variableExpenses: [Expense]
    let fixedExpenses: [FixedExpense]
    let creditCards: [CreditCard]
    let savings: [Saving]

    private var expensesTotal: Double {
        summary.variableExpenses + summary.fixedExpenses
    }

    var body: some View {
        List {
            summarySection
            incomesSection
            variableExpensesSection
            fixedExpensesSection
            creditCardsSection
            savingsSection
        }
        .navigationTitle(summary.displayMonth.capitalized)
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
    }

    private var summarySection: some View {
        Section(header: Text("Resumen")) {
            LabeledContent("Ingresos") {
                Text(summary.income, format: .currency(code: "MXN"))
                    .fontWeight(.semibold)
            }

            LabeledContent("Gastos") {
                Text(expensesTotal, format: .currency(code: "MXN"))
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Balance final") {
                Text(summary.balance, format: .currency(code: "MXN"))
                    .foregroundStyle(summary.balance < 0 ? .red : .green)
                    .fontWeight(.bold)
            }
        }
    }

    private var incomesSection: some View {
        Section(header: Text("Ingresos")) {
            if paychecks.isEmpty {
                Text("Sin ingresos registrados en este mes.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(paychecks) { paycheck in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(paycheck.date.dateValue(), style: .date)
                            .font(.subheadline)
                        Text(paycheck.amount, format: .currency(code: "MXN"))
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var variableExpensesSection: some View {
        Section(header: Text("Gastos variables")) {
            if variableExpenses.isEmpty {
                Text("Sin gastos variables en este mes.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(variableExpenses) { expense in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.name)
                                .font(.headline)
                            Text(expense.date.dateValue(), style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(expense.amount, format: .currency(code: "MXN"))
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var fixedExpensesSection: some View {
        Section(header: Text("Gastos fijos")) {
            if fixedExpenses.isEmpty {
                Text("Sin gastos fijos en este mes.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(fixedExpenses, id: \.self) { expense in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.name)
                                .font(.headline)
                            Text("Día \(expense.dayOfMonth)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(expense.amount, format: .currency(code: "MXN"))
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var creditCardsSection: some View {
        Section(header: Text("Tarjetas de crédito")) {
            if creditCards.isEmpty {
                Text("Sin pagos de tarjeta para este mes.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(creditCards, id: \.self) { card in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(card.name)
                                .font(.headline)
                            Spacer()
                            Text(card.currentDebt, format: .currency(code: "MXN"))
                                .foregroundStyle(card.currentDebt > 0 ? .red : .primary)
                                .fontWeight(.semibold)
                        }
                        HStack(spacing: 12) {
                            Label("Corte: día \(card.closingDate)", systemImage: "scissors")
                            Label("Pago: día \(card.paymentDueDate)", systemImage: "calendar")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var savingsSection: some View {
        Section(header: Text("Ahorros")) {
            if savings.isEmpty {
                Text("Sin movimientos de ahorro en este mes.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(savings) { saving in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Actualización")
                                .font(.headline)
                            Text(saving.date.dateValue(), style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(saving.amount, format: .currency(code: "MXN"))
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

#Preview {
    MonthlyBalanceDetailView(
        summary: MonthlyBalance(month: Date(), income: 25000, variableExpenses: 5000, fixedExpenses: 8000),
        paychecks: [],
        variableExpenses: [],
        fixedExpenses: [],
        creditCards: [],
        savings: []
    )
}
