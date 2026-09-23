import SwiftUI

struct DashboardOverviewHeader: View {
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OVERVIEW")
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                Text("System performance at a glance")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("LIVE  ·  1 SEC REFRESH")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .frame(height: 60, alignment: .top)
    }
}
