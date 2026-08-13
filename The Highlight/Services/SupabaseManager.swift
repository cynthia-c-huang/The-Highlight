import Foundation
import Supabase

final class SupabaseManager {
    
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://bzlnaaajwsqsrevfcymk.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ6bG5hYWFqd3Nxc3JldmZjeW1rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI3NDQyOTUsImV4cCI6MjA5ODMyMDI5NX0.h-rG-xHBWPl08M9atFQOrOd8mwEaLBXP6QcRCxAsHJo"
        )
    }
}
