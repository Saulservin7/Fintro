//
//  AuthServices.swift
//  Fintro
//
//  Created by Victor Saul Servin Martinez on 30/10/25.
//

import Foundation
import Firebase
import FirebaseAuth

// Usamos un 'actor' para asegurar que las operaciones
// de autenticación sean seguras en concurrencia (thread-safe).
actor AuthService {
    
    // Compartimos una única instancia para toda la app (Singleton)
    static let shared = AuthService()
    private init() {}

    // MARK: - Estado de Autenticación
    
    // Esta función nos permite "escuchar" los cambios de estado (login/logout)
    // en tiempo real.
    func listenToAuthState() -> AsyncStream<User?> {
        return AsyncStream { continuation in
            // El 'listener' se activa cada vez que el usuario inicia o cierra sesión
            let handle = Auth.auth().addStateDidChangeListener { _, user in
                continuation.yield(user) // Envía el usuario actual (o nil)
            }
            
            // Esto se llama cuando el stream se termina
            continuation.onTermination = { _ in
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }
    
    // Función para obtener el usuario actual de Firebase
    func getCurrentUser() -> User? {
        return Auth.auth().currentUser
    }

    // MARK: - Operaciones de Autenticación
    
    // Iniciar Sesión
    func signIn(withEmail email: String, password: String) async throws {
        do {
            // Usamos 'await' para esperar la respuesta de Firebase
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            // Si hay un error, lo lanzamos para que el ViewModel lo maneje
            throw error
        }
    }
    
    // Registrar un nuevo usuario
    func createUser(withEmail email: String, password: String, fullName: String) async throws {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Opcional: Actualizar el perfil del usuario con su nombre
            let changeRequest = authResult.user.createProfileChangeRequest()
            changeRequest.displayName = fullName
            try await changeRequest.commitChanges()
            
            // Aquí también podrías guardar info adicional en Firestore, por ejemplo:
            // try await Firestore.firestore().collection("users").document(authResult.user.uid).setData([...])

        } catch {
            throw error
        }
    }
    
    // Cerrar Sesión
    func signOut() throws {
        do {
            try Auth.auth().signOut()
        } catch {
            throw error
        }
    }
}
