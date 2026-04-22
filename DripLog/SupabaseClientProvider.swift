//
//  SupabaseClientProvider.swift
//  DripLog
//
//  Created by Michael Suarez-Russell on 4/21/26.
//

import Foundation
import Supabase

enum SupabaseClientProvider {
    static func makeClient(configuration: SupabaseConfiguration? = .current) throws -> SupabaseClient {
        guard let configuration else {
            throw AuthError.missingSupabaseConfiguration
        }

        return SupabaseClient(
            supabaseURL: configuration.projectURL,
            supabaseKey: configuration.anonKey
        )
    }
}
