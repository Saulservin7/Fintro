import SwiftUI

// ASEGÚRATE DE QUE ESTA ES LA ÚNICA STRUCT ContentView EN EL ARCHIVO
struct ContentView: View {
    // Observamos el ViewModel principal
    @StateObject private var viewModel = AuthViewModel()
    
    // Estado para controlar qué vista de Auth mostrar
    @State private var showLogin = true
    
    var body: some View {
            if viewModel.userSession != nil {
                // El usuario SÍ está logueado
                // 👇 CAMBIA ESTA LÍNEA
                DashboardView()
                    .environmentObject(viewModel) // Pasamos el AuthViewModel
            } else {
                // El usuario NO está logueado
                AuthFlowView
            }
        }
    
    // Vista "Contenedora" para el flujo de Login/Registro
    @ViewBuilder
    private var AuthFlowView: some View {
        if showLogin {
            LoginView(navigateToRegister: {
                showLogin = false // Cambia a la vista de registro
            })
            .environmentObject(viewModel) // Inyectamos el ViewModel
        } else {
            // AQUÍ LLAMAMOS A REGISTRATIONVIEW
            RegistrationView(navigateToLogin: {
                showLogin = true // Cambia a la vista de login
            })
            .environmentObject(viewModel) // Inyectamos el ViewModel
        }
    }
}


// ----- VISTA TEMPORAL (Tu app principal) -----
// Puedes crear este archivo por separado luego.
struct MainAppView: View {
    
    // Recibimos el ViewModel para poder cerrar sesión
    @EnvironmentObject var viewModel: AuthViewModel
    

    var body: some View {
        VStack(spacing: 20) {
            Text("¡Bienvenido!")
                .font(.largeTitle)
            
            // Usamos la info del viewModel
            if let user = viewModel.userSession {
                 Text("Email: \(user.email ?? "N/A")")
                 Text("Nombre: \(user.displayName ?? "N/A")")
            }
           
            
            Button {
                viewModel.logout() // Botón para cerrar sesión
            } label: {
                Text("Cerrar Sesión")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
        }
    }
}
