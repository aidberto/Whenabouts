
import SwiftUI

struct PlacesLibraryView: View {
    @StateObject var viewModel: PlacesLibraryViewModel
    @Binding var selectedTab: AppTab

    // When non-nil, the create/edit sheet is shown. Setting this back to nil dismisses the sheet.
    @State private var creationViewModel: PlaceCreationViewModel?

    var body: some View {
        ZStack(alignment: .bottom) {
            paperBackground

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if viewModel.places.isEmpty {
                        emptyState
                    } else {
                        placesList
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 54)
                .padding(.bottom, 112)
            }
        }
        .safeAreaInset(edge: .bottom) {
            quickAddBar
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $creationViewModel) { vm in
            PlaceCreationView(viewModel: vm)
        }
    }

    private var paperBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.95, blue: 0.90),
                Color(red: 1.00, green: 0.98, blue: 0.94)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(todayStamp)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(.secondary)

                Text("My Places")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color(red: 0.18, green: 0.13, blue: 0.10))
            }

            Spacer(minLength: 8)

            addButton {
                creationViewModel = viewModel.makeCreationViewModel()
            }
        }
    }

    private var todayStamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM / h:mma"
        return formatter.string(from: Date())
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("📍")
                .font(.system(size: 42))

            VStack(spacing: 6) {
                Text("no places saved.")
                    .font(.system(size: 21, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color(red: 0.17, green: 0.14, blue: 0.11))

                Text("Save the places that should trigger your reminders.")
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 240)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 24, x: 0, y: 12)
        )
        .padding(.top, 8)
    }

    private var placesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SAVED PLACES")
                .font(.system(size: 13, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Color(red: 0.58, green: 0.54, blue: 0.48))
                .padding(.leading, 4)

            VStack(spacing: 14) {
                ForEach(viewModel.places) { place in
                    placeRow(place)
                }
            }
        }
    }

    private func placeRow(_ place: Place) -> some View {
        HStack(spacing: 14) {
            Button {
                creationViewModel = viewModel.makeCreationViewModel(editing: place)
            } label: {
                HStack(spacing: 14) {
                    Text(icon(for: place.placeType))
                        .font(.system(size: 24))
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(.white.opacity(0.52)))

                    VStack(alignment: .leading, spacing: 7) {
                        Text(place.placeType.displayName.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .tracking(0.5)
                            .foregroundStyle(textColor(for: place.placeType).opacity(0.68))

                        Text(place.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(textColor(for: place.placeType))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(formattedCoordinate(for: place))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(textColor(for: place.placeType).opacity(0.68))
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button {
                delete(place)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(textColor(for: place.placeType).opacity(0.72))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.38)))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardColor(for: place.placeType))
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var quickAddBar: some View {
        HStack(spacing: 18) {
            barItem("list.bullet", "Reminders", tab: .reminders)
            barItem("square.stack.3d.up", "Places", tab: .places)
            barItem("map", "Map", tab: .map)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, 14)
        .padding(.bottom, -8)
    }

    private func addButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(Color(red: 0.08, green: 0.10, blue: 0.05))
                .frame(width: 46, height: 46)
                .background(
                    Circle().fill(Color(red: 0.78, green: 1.00, blue: 0.24))
                )
                .overlay(Circle().stroke(Color(red: 0.10, green: 0.10, blue: 0.08), lineWidth: 1.8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add place")
    }

    private func barItem(_ icon: String, _ title: String, tab: AppTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 24, height: 22, alignment: .center)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .frame(height: 12, alignment: .center)
            }
            .foregroundStyle(selectedTab == tab ? Color(red: 0.28, green: 0.23, blue: 0.16) : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 56, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func delete(_ place: Place) {
        guard let index = viewModel.places.firstIndex(where: { $0.id == place.id }) else {
            return
        }
        viewModel.delete(at: IndexSet(integer: index))
    }

    private func formattedCoordinate(for place: Place) -> String {
        String(format: "%.5f, %.5f", place.latitude, place.longitude)
    }

    private func icon(for type: PlaceType) -> String {
        switch type {
        case .home: return "🏠"
        case .work: return "🎓"
        case .supermarket: return "🛒"
        case .pharmacy: return "💊"
        case .postOffice: return "📦"
        case .custom: return "📍"
        }
    }

    private func cardColor(for type: PlaceType) -> Color {
        switch type {
        case .home:
            return Color(red: 1.00, green: 0.76, blue: 0.65)
        case .work:
            return Color(red: 0.68, green: 0.85, blue: 1.00)
        case .supermarket:
            return Color(red: 0.84, green: 1.00, blue: 0.40)
        case .pharmacy:
            return Color(red: 0.82, green: 0.72, blue: 1.00)
        case .postOffice:
            return Color(red: 1.00, green: 0.84, blue: 0.48)
        case .custom:
            return Color(red: 0.93, green: 0.88, blue: 1.00)
        }
    }

    private func textColor(for type: PlaceType) -> Color {
        switch type {
        case .home:
            return Color(red: 0.40, green: 0.16, blue: 0.08)
        case .work:
            return Color(red: 0.05, green: 0.22, blue: 0.38)
        case .supermarket:
            return Color(red: 0.18, green: 0.27, blue: 0.08)
        case .pharmacy:
            return Color(red: 0.22, green: 0.10, blue: 0.48)
        case .postOffice:
            return Color(red: 0.42, green: 0.24, blue: 0.04)
        case .custom:
            return Color(red: 0.30, green: 0.18, blue: 0.42)
        }
    }
}

// Lets us drive the create/edit sheet using `.sheet(item:)`. Each PlaceCreationViewModel is uniquely identified by its memory address.
extension PlaceCreationViewModel: Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

struct PlacesLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PlacesLibraryView(
                viewModel: PlacesLibraryViewModel(
                    store: InMemoryPlaceStore(places: [
                        Place(name: "Home", placeType: .home, latitude: -33.8688, longitude: 151.2093),
                        Place(name: "Coles Broadway", placeType: .supermarket, latitude: -33.8836, longitude: 151.1959)
                    ]),
                    location: ScriptedLocationProvider(),
                    searcher: StaticAddressSearcher(),
                    geocoder: StaticGeocoder()
                ),
                selectedTab: .constant(.places)
            )
            .previewDisplayName("With places")

            PlacesLibraryView(
                viewModel: PlacesLibraryViewModel(
                    store: InMemoryPlaceStore(),
                    location: ScriptedLocationProvider(),
                    searcher: StaticAddressSearcher(),
                    geocoder: StaticGeocoder()
                ),
                selectedTab: .constant(.places)
            )
            .previewDisplayName("Empty")
        }
    }
}
