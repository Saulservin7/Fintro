import SwiftUI

struct DashboardView: View {
    
    @StateObject private var viewModel = FinanceViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var showingAddPaycheckSheet = false
    @State private var showingSavingsSheet = false
    @State private var sheetToShow: SheetType? // Estado único para todas las hojas
    @State private var selectedSection: DashboardSection = .overview

    // Enum para gestionar las hojas de forma limpia
    enum SheetType: Identifiable {
        case addVariable, addFixed, editVariable(Expense), editFixed(FixedExpense)
        case addCard, editCard(CreditCard) // Casos para tarjetas
        
        // IDs únicos para cada caso
        var id: String {
            switch self {
            case .addVariable: return "addVar"
            case .addFixed: return "addFixed"
            case .editVariable(let expense): return "editVar-\(expense.id ?? "")"
            case .editFixed(let expense): return "editFixed-\(expense.id ?? "")"
            case .addCard: return "addCard" // <-- CÓDIGO COMPLETADO
            case .editCard(let card): return "editCard-\(card.id ?? "")" // <-- CÓDIGO COMPLETADO
            }
        }
    }

    enum DashboardSection: String, CaseIterable, Identifiable {
        case overview
        case savings
        case history

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview: return "Resumen"
            case .savings: return "Ahorros"
            case .history: return "Historial"
            }
        }
    }

     var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryCard
                    .padding()
                    .onTapGesture {
                        viewModel.prefillPaycheckAmount()
                        showingAddPaycheckSheet = true
                    }

                periodPicker // Selector de quincena

                sectionPicker
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                sectionContent
            }
            .navigationTitle("Dashboard")
            .toolbar {
                 ToolbarItem(placement: .navigationBarLeading) { Button("Salir") { authViewModel.logout() }.tint(.red) }
                 
                // MENÚ DE AÑADIR CON 3 OPCIONES
                ToolbarItem(placement: .navigationBarTrailing) {
                     Menu {
                        Button("Agregar Tarjeta", systemImage: "creditcard.fill") { sheetToShow = .addCard } // <-- OPCIÓN AÑADIDA
                        Button("Agregar Gasto Fijo", systemImage: "pin.fill") { sheetToShow = .addFixed }
                        Button("Agregar Gasto Variable", systemImage: "cart.fill") { sheetToShow = .addVariable }
                     } label: { Image(systemName: "plus.circle.fill").font(.headline) }
                 }
            }
            .sheet(isPresented: $showingAddPaycheckSheet) { addPaycheckSheet }
            .sheet(isPresented: $showingSavingsSheet) { savingsSheet }
            // HOJA ÚNICA QUE REACCIONA A TODOS LOS CASOS
            .sheet(item: $sheetToShow) { sheet in
                 switch sheet {
                 case .addVariable:
                     expenseEditSheet(isEditing: false, type: .variable)
                 case .addFixed:
                     expenseEditSheet(isEditing: false, type: .fixed)
                 case .editVariable:
                     expenseEditSheet(isEditing: true, type: .variable)
                 case .editFixed:
                     expenseEditSheet(isEditing: true, type: .fixed)
                 case .addCard: // <-- CASO AÑADIDO
                     creditCardEditSheet(isEditing: false)
                 case .editCard: // <-- CASO AÑADIDO
                     creditCardEditSheet(isEditing: true)
                 }
            }
        }
     }

    private var sectionPicker: some View {
        Picker("Sección del dashboard", selection: $selectedSection) {
            ForEach(DashboardSection.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .overview:
            overviewList
        case .savings:
            savingsList
        case .history:
            historyList
        }
    }

    private var overviewList: some View {
        List {
            // SECCIÓN PARA TARJETAS DE CRÉDITO
            Section(header: Text("Tarjetas de Crédito")) {
                if viewModel.creditCardsForCurrentPeriod.isEmpty {
                    Text("Sin tarjetas con pago en esta quincena.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.creditCardsForCurrentPeriod) { card in
                        Button(action: {
                            viewModel.setupEditing(card: card)
                            sheetToShow = .editCard(card)
                        }) {
                            creditCardRow(for: card) // <-- VISTA AÑADIDA
                        }
                    }
                    .onDelete(perform: viewModel.deleteCreditCard)
                }
            }

            // SECCIÓN DE GASTOS FIJOS
            Section(header: Text("Gastos Fijos de este Periodo")) {
                if viewModel.fixedExpensesForCurrentPeriod.isEmpty {
                    Text("Sin gastos fijos para esta quincena.").foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.fixedExpensesForCurrentPeriod) { expense in
                        Button(action: {
                            viewModel.setupEditing(fixedExpense: expense)
                            sheetToShow = .editFixed(expense)
                        }) {
                            expenseRow(name: expense.name, amount: expense.amount, day: expense.dayOfMonth)
                        }
                    }
                    .onDelete(perform: viewModel.deleteFixedExpense)
                }
            }

            // SECCIÓN DE GASTOS VARIABLES
            Section(header: Text("Gastos Variables de este Periodo")) {
                if viewModel.variableExpensesForCurrentPeriod.isEmpty {
                   Text("Sin gastos variables en esta quincena.").foregroundStyle(.secondary)
               } else {
                    ForEach(viewModel.variableExpensesForCurrentPeriod) { expense in
                        Button(action: {
                            viewModel.setupEditing(variableExpense: expense)
                            sheetToShow = .editVariable(expense)
                        }) {
                            expenseRow(name: expense.name, amount: expense.amount, date: expense.date.dateValue())
                        }
                    }
                    .onDelete(perform: viewModel.deleteVariableExpense)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var savingsList: some View {
        List {
            Section(header: Text("Ahorros")) {
                Button(action: {
                    viewModel.prefillSavingAmount()
                    showingSavingsSheet = true
                }) {
                    savingsCard
                }
                .buttonStyle(.plain)

                Text("Administra tus ahorros desde aquí para no saturar el resumen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var historyList: some View {
        List {
            monthlyHistorySection
        }
        .listStyle(.insetGrouped)
    }
    
    // --- Sub-vistas y Componentes ---
    
    // Tarjeta de resumen actualizada con 3 columnas
    private var summaryCard: some View {
        VStack(spacing: 10) {
            Text("Balance Final Estimado") // Título actualizado
                .font(.headline).foregroundStyle(.white.opacity(0.8))
            
            Text(viewModel.remainingBalance, format: .currency(code: "MXN"))
                .font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(.white)
            
            // Layout de 3 columnas
            HStack {
                VStack(alignment: .leading) {
                    Text("Ingreso")
                    Text(viewModel.currentPaycheckAmount, format: .currency(code: "MXN"))
                }
                Spacer()
                VStack(alignment: .center) {
                    Text("Gastos (Periodo)")
                    Text(viewModel.totalPeriodExpenses, format: .currency(code: "MXN"))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("TDC a Pagar (Periodo)") // <-- TÍTULO NUEVO
                        Text(viewModel.totalCreditCardDebt, format: .currency(code: "MXN"))
                        .foregroundStyle(viewModel.totalCreditCardDebt > 0 ? Color.red.opacity(0.9) : .white) // Deuda en rojo
                        .fontWeight(.semibold)
                }
            }
            .font(.caption).fontWeight(.semibold).foregroundStyle(.white)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(Color.blue.gradient)
        .cornerRadius(20)
        .shadow(radius: 10)
    }

    private var savingsCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ahorros actuales")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(viewModel.currentSavingsAmount, format: .currency(code: "MXN"))
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            Spacer()
            Image(systemName: "arrow.up.arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // Selector de periodo extraído
    private var periodPicker: some View {
        Picker("Seleccionar Periodo", selection: $viewModel.currentPeriod) {
            ForEach(Period.allCases) { period in
                Text(period.displayName)
                    .tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 10)
    }

    // Fila para Tarjeta de Crédito (faltaba)
    private func creditCardRow(for card: CreditCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(card.name).font(.headline).foregroundStyle(.primary)
                Spacer()
                Text(card.currentDebt, format: .currency(code: "MXN")).font(.headline)
                    .foregroundStyle(card.currentDebt > 0 ? .red : .primary)
            }
            HStack {
                Image(systemName: "scissors")
                Text("Corte: Día \(card.closingDate)")
                Spacer()
                Image(systemName: "calendar")
                Text("Pago: Día \(card.paymentDueDate)")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // Fila para Gasto (sin cambios, pero se incluye)
      private func expenseRow(name: String, amount: Double, day: Int? = nil, date: Date? = nil) -> some View {
          HStack {
              Text(name).foregroundStyle(.primary) // Color primario para el texto
              if let day = day {
                  Text("Día \(day)")
                      .font(.caption)
                      .padding(.horizontal, 8)
                      .background(Color.gray.opacity(0.2))
                      .clipShape(Capsule())
              } else if let date = date {
                  Text(date, style: .date)
                      .font(.caption)
                      .padding(.horizontal, 8)
                      .background(Color.gray.opacity(0.2))
                      .clipShape(Capsule())
              }
              Spacer()
              Text(amount, format: .currency(code: "MXN")).foregroundStyle(.secondary)
          }
      }

      private var monthlyHistorySection: some View {
          Section(header: Text("Historial mensual de balances")) {
              if viewModel.monthlyBalanceHistory.isEmpty {
                  Text("Sin movimientos registrados.").foregroundStyle(.secondary)
              } else {
                  ForEach(viewModel.monthlyBalanceHistory) { summary in
                      NavigationLink {
                          MonthlyBalanceDetailView(
                              summary: summary,
                              paychecks: viewModel.paychecks(forMonth: summary.month),
                              variableExpenses: viewModel.variableExpenses(forMonth: summary.month),
                              fixedExpenses: viewModel.fixedExpenses(forMonth: summary.month),
                              creditCards: viewModel.creditCards(forMonth: summary.month),
                              savings: viewModel.savings(forMonth: summary.month)
                          )
                      } label: {
                          monthlyHistoryRow(summary)
                      }
                  }
              }
          }
      }

      private func monthlyHistoryRow(_ summary: MonthlyBalance) -> some View {
          VStack(alignment: .leading, spacing: 8) {
              HStack {
                  Text(summary.displayMonth.capitalized)
                      .font(.headline)
                  Spacer()
                  Text(summary.balance, format: .currency(code: "MXN"))
                      .font(.headline)
                      .foregroundStyle(summary.balance < 0 ? .red : .green)
              }

              HStack(spacing: 16) {
                  Label {
                      Text(summary.income, format: .currency(code: "MXN"))
                  } icon: {
                      Image(systemName: "arrow.down.circle")
                  }
                  .foregroundStyle(.primary)

                  Label {
                      Text(summary.variableExpenses + summary.fixedExpenses, format: .currency(code: "MXN"))
                  } icon: {
                      Image(systemName: "arrow.up.circle")
                  }
                  .foregroundStyle(.secondary)
              }
              .font(.caption)
          }
          .padding(.vertical, 4)
      }
    
    // Hoja para Ingreso (sin cambios, pero se incluye)
    private var addPaycheckSheet: some View {
         NavigationStack {
             Form {
                 Section("Monto de la Quincena") {
                     TextField("Ej. 10000.00", text: $viewModel.paycheckAmount).keyboardType(.decimalPad)
                 }
             }
             .navigationTitle("Actualizar Ingreso").navigationBarTitleDisplayMode(.inline)
             .toolbar {
                 ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showingAddPaycheckSheet = false } }
                 ToolbarItem(placement: .confirmationAction) {
                     Button("Guardar") { viewModel.addPaycheck(); showingAddPaycheckSheet = false }
                         .disabled(viewModel.paycheckAmount.isEmpty)
                 }
             }
         }
     }

    private var savingsSheet: some View {
        NavigationStack {
            Form {
                Section("Monto de ahorros") {
                    TextField("Ej. 5000.00", text: $viewModel.savingAmount)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Actualizar Ahorros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showingSavingsSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        viewModel.addOrUpdateSaving()
                        showingSavingsSheet = false
                    }
                    .disabled(viewModel.savingAmount.isEmpty)
                }
            }
        }
    }
    
    // Hoja reutilizable para Gastos (sin cambios, pero se incluye)
    enum ExpenseType { case variable, fixed }

    @ViewBuilder
    private func expenseEditSheet(isEditing: Bool, type: ExpenseType) -> some View {
         NavigationStack {
             Form {
                   Section(header: Text(isEditing ? "Editar Gasto" : (type == .variable ? "Nuevo Gasto Variable" : "Nuevo Gasto Fijo"))) {
                       TextField("Nombre", text: type == .variable ? $viewModel.expenseName : $viewModel.fixedExpenseName)
                       TextField("Monto", text: type == .variable ? $viewModel.expenseAmount : $viewModel.fixedExpenseAmount)
                           .keyboardType(.decimalPad)

                        if type == .variable {
                            DatePicker("Fecha", selection: $viewModel.expenseDate, displayedComponents: .date)
                        }

                       if type == .fixed {
                           TextField("Día del mes (1-31)", text: $viewModel.fixedExpenseDay)
                               .keyboardType(.numberPad)
                       }
                 }
             }
             .navigationTitle(isEditing ? "Editar Gasto" : "Nuevo Gasto")
             .navigationBarTitleDisplayMode(.inline)
             .toolbar {
                 ToolbarItem(placement: .cancellationAction) {
                     Button("Cancelar") {
                         viewModel.clearAndDismissEditing()
                         sheetToShow = nil
                     }
                 }
                 ToolbarItem(placement: .confirmationAction) {
                     Button("Guardar") {
                         if isEditing {
                             type == .variable ? viewModel.updateVariableExpense() : viewModel.updateFixedExpense()
                         } else {
                             type == .variable ? viewModel.addVariableExpense() : viewModel.addFixedExpense()
                         }
                         sheetToShow = nil
                     }
                     .disabled(
                         (type == .variable && (viewModel.expenseName.isEmpty || viewModel.expenseAmount.isEmpty)) ||
                         (type == .fixed && (viewModel.fixedExpenseName.isEmpty || viewModel.fixedExpenseAmount.isEmpty || viewModel.fixedExpenseDay.isEmpty))
                     )
                 }
             }
         }
     }

    // Hoja reutilizable para Tarjetas de Crédito (faltaba)
    @ViewBuilder
    private func creditCardEditSheet(isEditing: Bool) -> some View {
        NavigationStack {
            Form {
                Section("Detalles de la Tarjeta") {
                    TextField("Nombre (ej. BBVA Azul)", text: $viewModel.cardName)
                    TextField("Deuda del mes", text: $viewModel.cardDebt).keyboardType(.decimalPad)
                    TextField("Día de corte (ej. 25)", text: $viewModel.cardClosingDate).keyboardType(.numberPad)
                    TextField("Día límite de pago (ej. 15)", text: $viewModel.cardPaymentDate).keyboardType(.numberPad)
                }
            }
            .navigationTitle(isEditing ? "Editar Tarjeta" : "Nueva Tarjeta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        viewModel.clearAndDismissEditing()
                        sheetToShow = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        isEditing ? viewModel.updateCreditCard() : viewModel.addCreditCard()
                        sheetToShow = nil
                    }
                    .disabled(
                        viewModel.cardName.isEmpty || viewModel.cardDebt.isEmpty || viewModel.cardClosingDate.isEmpty || viewModel.cardPaymentDate.isEmpty
                    )
                }
            }
        }
    }
}
