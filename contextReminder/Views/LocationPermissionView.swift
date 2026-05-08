//
//  LocationPermissionView.swift
//  contextReminder
//
//  Shown on first launch (and whenever permission is .notDetermined or .denied).
//  Walks the user through granting location access in two steps:
//    Step 1 — "While Using" (foreground)
//    Step 2 — "Always Allow" (background, needed for geofences)
//

import SwiftUI

struct LocationPermissionView: View {
    @ObservedObject var locationProvider: CoreLocationProvider

    var body: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [Color(.systemBackground), Color.blue.opacity(0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                }
                .padding(.bottom, 32)

                // Title + subtitle
                VStack(spacing: 12) {
                    Text("Location Access")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text("Context Reminder uses your location to notify you at the right moment — when you arrive at or leave a place.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

                // Feature rows
                VStack(spacing: 16) {
                    featureRow(
                        icon: "bell.badge.fill",
                        color: .orange,
                        title: "Timely reminders",
                        description: "Get notified the moment you arrive at the supermarket, pharmacy, or work."
                    )
                    featureRow(
                        icon: "location.fill",
                        color: .blue,
                        title: "Works in the background",
                        description: "Geofences fire even when the app is closed — no battery drain from continuous GPS."
                    )
                    featureRow(
                        icon: "lock.shield.fill",
                        color: .green,
                        title: "Private by design",
                        description: "Your location is only used on-device to match places. It is never sent anywhere."
                    )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)

                Spacer()

                // Action area
                VStack(spacing: 12) {
                    actionButton
                    statusCaption
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Action button

    @ViewBuilder
    private var actionButton: some View {
        switch locationProvider.authorization {
        case .notDetermined:
            Button {
                locationProvider.requestWhenInUseAuthorization()
            } label: {
                Label("Allow Location Access", systemImage: "location.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

        case .foregroundOnly:
            VStack(spacing: 12) {
                // Step 1 done
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("While Using — granted")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                // Step 2
                Button {
                    locationProvider.requestAlwaysAuthorization()
                } label: {
                    Label("Allow Background Access", systemImage: "location.fill.viewfinder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Text("Tap \"Always Allow\" in the next prompt so reminders fire when the app is closed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

        case .denied, .restricted:
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("Location access denied")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Button {
                    locationProvider.openSettings()
                } label: {
                    Label("Open Settings", systemImage: "gear")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Text("Enable Location in Settings → contextReminder → Location → Always.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

        case .full:
            // Should never be visible — the parent hides this view when .full
            EmptyView()
        }
    }

    @ViewBuilder
    private var statusCaption: some View {
        switch locationProvider.authorization {
        case .notDetermined:
            Text("You can change this at any time in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        default:
            EmptyView()
        }
    }

    // MARK: - Feature row

    private func featureRow(
        icon: String,
        color: Color,
        title: String,
        description: String
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Not determined") {
    LocationPermissionView(
        locationProvider: {
            let p = CoreLocationProvider()
            return p
        }()
    )
}
