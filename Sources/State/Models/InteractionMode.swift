import SwiftUI

enum InteractionMode: Int, CaseIterable {
    case click = 0
    case hover = 1
    
    var name: String {
        switch self {
        case .click: return "Click"
        case .hover: return "Hover"
        }
    }
    
    var icon: String {
        switch self {
        case .click: return "hand.tap"
        case .hover: return "eye.slash"
        }
    }
    
    var color: Color {
        switch self {
        case .click: return .blue
        case .hover: return .orange
        }
    }
    
    var shortDescription: String {
        switch self {
        case .click: return "Click for menu"
        case .hover: return "Auto-hide"
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .click: return "Click overlay → menu appears (copy, hide, ignore)"
        case .hover: return "Move mouse over overlay → it disappears"
        }
    }
}
