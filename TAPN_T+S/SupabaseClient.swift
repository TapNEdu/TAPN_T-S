import Foundation
import Supabase

// MARK: - Supabase Client Configuration
// Credentials are loaded from SupabaseConfig.swift (not committed to git)
// See SupabaseConfig.swift.example for setup instructions

let supabaseURL = URL(string: SupabaseConfig.url)!
let supabaseAnonKey = SupabaseConfig.anonKey

// Shared Supabase client instance
let supabase = SupabaseClient(
    supabaseURL: supabaseURL,
    supabaseKey: supabaseAnonKey
)

// MARK: - Configuration Instructions
/*
 To configure Supabase for your project:

 1. Go to https://database.new to create a new Supabase project
 2. Once created, go to Settings > API
 3. Copy your project URL and anon/public key
 4. Replace the placeholders above with your actual values
 5. Run the SQL migration from supabase-migration.sql in your Supabase SQL Editor

 Example:
 let supabaseURL = URL(string: "https://abcdefghijk.supabase.co")!
 let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
 */
