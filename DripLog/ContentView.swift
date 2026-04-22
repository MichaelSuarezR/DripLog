//
//  ContentView.swift
//  DripLog
//
//  Created by Michael Suarez-Russell on 4/21/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if let user = authViewModel.currentUser {
                HomeView(user: user, onLogOut: authViewModel.logOut)
            } else {
                AuthView(viewModel: authViewModel)
            }
        }
        .task {
            authViewModel.loadCurrentUserIfNeeded()
        }
    }
}

#Preview {
    ContentView()
}
