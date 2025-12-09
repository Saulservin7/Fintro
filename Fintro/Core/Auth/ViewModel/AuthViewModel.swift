//
//  AuthViewModel.swift
//  Fintro
//
//  Created by Victor Saul Servin Martinez on 30/10/25.
//

import Foundation
import Combine // Para manejar @Published
import FirebaseAuth

// @MainActor asegura que todas las actualizaciones de UI
// se hagan en el hilo principal.
@MainActor
class AuthViewModel: ObservableObject {
    
    // Inputs del usuario (publicados para que la Vista se enlace)
    @Published var email = ""
    @Published var password = ""
    @Published var fullName = "" // Para el registro
    
    // Estado de la sesión
    @Published var userSession: User? // El usuario de Firebase
    
    // Manejo de errores
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let authService = AuthService.shared

    init() {
        listenToAuthState()
    }
    
    // 1. Escuchar el estado de autenticación del AuthService
    private func listenToAuthState() {
        Task {
            // El stream de AuthService nos enviará el usuario (o nil)
            // cada vez que cambie.
            for await user in await authService.listenToAuthState() {
                // Actualizamos nuestra variable @Published
                self.userSession = user
            }
        }
    }
    
    // 2. Función de Inicio de Sesión
    func login() {
        Task {
            do {
                // Llama al servicio
                try await authService.signIn(withEmail: email, password: password)
                // El 'listener' (arriba) detectará el cambio y actualizará
                // 'userSession' automáticamente.
                print("DEBUG: Usuario logueado: \(email)")
                clearInputs()
            } catch {
                // Publica el error para que la Vista lo muestre
                self.errorMessage = error.localizedDescription
                print("DEBUG: Error al loguear - \(error.localizedDescription)")
            }
        }
    }
    
    // 3. Función de Registro
    func register() {
        Task {
            do {
                // Llama al servicio
                try await authService.createUser(withEmail: email, password: password, fullName: fullName)
                // El 'listener' detectará el cambio.
                print("DEBUG: Usuario registrado: \(email)")
                clearInputs()
            } catch {
                self.errorMessage = error.localizedDescription
                print("DEBUG: Error al registrar - \(error.localizedDescription)")
            }
        }
    }
    
    // 4. Función de Cerrar Sesión
    // 4. Función de Cerrar Sesión (CORREGIDA)
    func logout() {
        // 👇 Añadimos el Task para crear un contexto asíncrono
        Task {
            do {
                // 👇 Y ahora podemos usar 'try await'
                try await authService.signOut()
                print("DEBUG: Usuario deslogueado.")
                clearInputs()
            } catch {
                self.errorMessage = error.localizedDescription
                print("DEBUG: Error al desloguear - \(error.localizedDescription)")
            }
        }
    }
    
    // Función helper para limpiar los campos
    private func clearInputs() {
        email = ""
        password = ""
        fullName = ""
        errorMessage = nil
    }
}
