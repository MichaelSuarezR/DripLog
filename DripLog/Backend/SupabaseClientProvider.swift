//
//  SupabaseClientProvider.swift
//  DripLog
//
//  Created by Michael Suarez-Russell on 4/21/26.
//

import Foundation
import Supabase

enum SupabaseClientProvider {
    private static var sharedClient: SupabaseClient?

    static func makeClient(configuration: SupabaseConfiguration? = .current) throws -> SupabaseClient {
        if let sharedClient {
            return sharedClient
        }

        guard let configuration else {
            throw AuthError.missingSupabaseConfiguration
        }

        let client = SupabaseClient(
            supabaseURL: configuration.projectURL,
            supabaseKey: configuration.anonKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )

        sharedClient = client
        return client
    }
}
