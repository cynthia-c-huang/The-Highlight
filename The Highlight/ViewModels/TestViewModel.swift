import Foundation

@MainActor
class TestViewModel: ObservableObject {
    
    @Published var message: String = "Loading..."
    
    func fetchMessage() async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("test_messages")
                .select()
                .limit(1)
                .execute()
            
            let data = try JSONDecoder().decode([TestMessage].self, from: response.data)
            
            message = data.first?.message ?? "No data found"
            
        } catch {
            message = "Error: \(error.localizedDescription)"
        }
    }
}
