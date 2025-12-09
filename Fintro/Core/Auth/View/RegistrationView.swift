//
//  RegistrationView.swift
//  Fintro
//
//  Created by Victor Saul Servin Martinez on 30/10/25.
//

import SwiftUI

struct RegistrationView: View {
    // Se conecta al ViewModel que le pasamos desde ContentView
    @EnvironmentObject var viewModel: AuthViewModel
    
    // Esta es una acción que le pasamos para que sepa cómo volver a la vista de login
    let navigateToLogin: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            
            // --- Título de la Vista ---
            Text("Crear Cuenta")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 20) // Un poco más de espacio debajo del título
            
            // --- Campo de Nombre Completo ---
            TextField("Nombre Completo", text: $viewModel.fullName)
                .autocapitalization(.words) // Pone en mayúscula la primera letra de cada palabra
                .padding()
                .background(Color(.systemGray6)) // Un fondo gris claro sutil
                .cornerRadius(10)
            
            // --- Campo de Email ---
            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress) // Muestra el teclado optimizado para emails
                .autocapitalization(.none) // No queremos mayúsculas en el email
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            
            // --- Campo de Contraseña ---
            SecureField("Contraseña", text: $viewModel.password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            
            // --- Mensaje de Error (si existe) ---
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center) // Centra el texto si ocupa varias líneas
            }
            
            // --- Botón de Registro ---
            Button {
                // Le dice al ViewModel que ejecute la lógica de registro
                viewModel.register()
            } label: {
                Text("Registrar")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 55)
                    .frame(maxWidth: .infinity) // Ocupa todo el ancho disponible
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.vertical)
            
            Spacer() // Empuja todo el contenido hacia arriba
            
            // --- Botón para Navegar a Login ---
            Button {
                // Ejecuta la acción que le pasamos para cambiar de vista
                navigateToLogin()
            } label: {
                HStack(spacing: 4) {
                    Text("¿Ya tienes cuenta?")
                    Text("Inicia Sesión")
                        .fontWeight(.bold)
                }
                .font(.system(size: 14)) // Tamaño de fuente explícito
            }
            .padding(.bottom, 20) // Un poco de espacio en la parte inferior
            
        }
        .padding(.horizontal, 30) // Espacio a los lados de la pantalla
    }
}

// --- PREVIEW (Para el Canvas de Xcode) ---
// Esto te permite ver cómo se ve la vista sin correr la app
#Preview {
    // Para que el preview funcione, necesita una función vacía y un ViewModel
    RegistrationView(navigateToLogin: {})
        .environmentObject(AuthViewModel())
}
