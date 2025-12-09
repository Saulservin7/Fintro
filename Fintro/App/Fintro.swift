//
//  Fintro.swift
//  Fintro
//
//  Created by Victor Saul Servin Martinez on 30/10/25.
//

import SwiftUI
import FirebaseCore // Importar FirebaseCore

// Creamos un AppDelegate para configurar Firebase
// Esta es la forma recomendada y más robusta.
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure() // Configura Firebase
    return true
  }
}

@main
struct TuAppApp: App {
    // Registramos el AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            // Iniciamos en el ContentView, que manejará toda la lógica.
            ContentView()
        }
    }
}
