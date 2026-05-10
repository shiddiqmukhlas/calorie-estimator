import Foundation

struct DetectionData: Codable {
    struct Detection: Codable {
        let class_id: Int
        let bounding_box: BoundingBox
        let area: Double?
        let depth_mean: Double?
        let depth_median: Double?
        let weight: Double?
        let calories: Double?
        let mask: [[Int]]?
        let mask_base64: String?
    }

    struct BoundingBox: Codable {
        let x_center: Double
        let y_center: Double
        let width: Double
        let height: Double
    }

    let detections: [Detection]
}
