//
//  LoginView.swift
//  Fintro
//
//  Created by Victor Saul Servin Martinez on 30/10/25.
//

import SwiftUI

struct LoginView: View {
    // La Vista "observa" al ViewModel
    @EnvironmentObject var viewModel: AuthViewModel
    
    // Propiedad para navegar al registro (la pasaremos en el ContentView)
    let navigateToRegister: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                Text("Iniciar Sesión")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Campo de Email
                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                // Campo de Contraseña
                SecureField("Contraseña", text: $viewModel.password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                // Mostrar error si existe
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                // Botón de Iniciar Sesión
                Button {
                    // Le dice al ViewModel que intente loguear
                    viewModel.login()
                } label: {
                    Text("Entrar")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                Spacer()
                
                // Botón para ir a Registro
                Button {
                    navigateToRegister() // Llama a la función de navegación
                } label: {
                    HStack {
                        Text("¿No tienes cuenta?")
                        Text("Regístrate")
                            .fontWeight(.bold)
                    }
                }
                .padding(.bottom, 20)
                
            }
            .padding(.horizontal, 30)
        }
    }
}
