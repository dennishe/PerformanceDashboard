import SwiftUI

enum DashboardDesign {
    enum FontSize {
        static let tileCaption: CGFloat = 10
        static let tileSubtitle: CGFloat = 11
        static let tileControl: CGFloat = 12
        static let tileBody: CGFloat = 13
        static let tileHeader: CGFloat = 13
        static let tileValue: CGFloat = 26
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 5
        static let compact: CGFloat = 10
        static let regular: CGFloat = 12
        static let medium: CGFloat = 14
        static let large: CGFloat = 16
    }

    enum Opacity {
        static let tileChrome: Double = 0.07
        static let modalScrim: Double = 0.45
        static let popoverDivider: Double = 0.06
    }

    enum Animation {
        static let detailReveal = SwiftUI.Animation.spring(response: 0.32, dampingFraction: 0.82)
        static let detailDismiss = SwiftUI.Animation.spring(response: 0.28, dampingFraction: 0.85)
    }
}
