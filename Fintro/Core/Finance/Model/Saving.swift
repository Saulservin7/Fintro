import Foundation
import FirebaseFirestore

struct Saving: Identifiable, Codable {
    @DocumentID var id: String?
    var amount: Double
    var date: Timestamp
    var userId: String
}
