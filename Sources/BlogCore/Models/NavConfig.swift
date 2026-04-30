import Foundation

public struct NavItem: Codable, Equatable {
    public var label: String
    public var route: String

    public init(label: String, route: String) {
        self.label = label
        self.route = route
    }
}
