//
//  RemindersView.swift
//  contextReminder
//
//  Created by Aiden Bertovic on 5/5/2026.
//
//  Shows the user's reminders and includes the form used to create or edit a
//  reminder with a saved place, place type, priority, category, and checklist.

import SwiftUI

struct RemindersView: View {
    @StateObject var viewModel: RemindersViewModel
    @Binding var selectedTab: AppTab
    @State private var reminderBeingEdited: Reminder?
    @State private var isShowingNewReminder = false
    @State private var completingReminderID: UUID?

    var body: some View {
        ZStack(alignment: .bottom) {
            paperBackground
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    header

                    if activeReminders.isEmpty {
                        emptyState
                    } else {
                        reminderSections
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
        .sheet(isPresented: $isShowingNewReminder) {
            ReminderFormView(
                places: viewModel.places,
                reminder: nil,
                onSave: viewModel.save
            )
        }
        .sheet(item: $reminderBeingEdited) { reminder in
            ReminderFormView(
                places: viewModel.places,
                reminder: reminder,
                onSave: viewModel.save
            )
        }
    }

    private var activeReminders: [Reminder] {
        viewModel.reminders.filter { !$0.isCompleted }
    }

    private var laterReminders: [Reminder] {
        Array(activeReminders.dropFirst(4))
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

                Text("My Whenabouts")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color(red: 0.18, green: 0.13, blue: 0.10))
            }

            Spacer(minLength: 8)

            addButton {
                isShowingNewReminder = true
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
            VStack(spacing: 6) {
                Text("nothing on the list.")
                    .font(.system(size: 21, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color(red: 0.17, green: 0.14, blue: 0.11))

                Text("You're all caught up")
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 230)
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

    private var reminderSections: some View {
        VStack(alignment: .leading, spacing: 22) {
            reminderSection(
                title: "REMIND NOW",
                reminders: Array(activeReminders.prefix(4))
            )

            if !laterReminders.isEmpty {
                reminderSection(
                    title: "LATER THIS WEEK",
                    reminders: laterReminders
                )
            }
        }
    }

    private func reminderSection(title: String, reminders: [Reminder]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Color(red: 0.58, green: 0.54, blue: 0.48))
                .padding(.leading, 4)

            VStack(spacing: 14) {
                ForEach(reminders) { reminder in
                    reminderRow(reminder)
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .onTapGesture {
                        guard completingReminderID != reminder.id else { return }
                        reminderBeingEdited = reminder
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            complete(reminder)
                        } label: {
                            Label("Done", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(reminder)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func reminderRow(_ reminder: Reminder) -> some View {
        let isCompleting = completingReminderID == reminder.id

        return HStack(alignment: .top, spacing: 14) {
            Text(icon(for: reminder))
                .font(.system(size: 24))
                .frame(width: 48, height: 48)
                .background(Circle().fill(.white.opacity(0.52)))

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(reminder.category.displayName.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .tracking(0.5)
                        .foregroundStyle(cardTextColor(for: reminder).opacity(0.68))

                    if reminder.priority == .urgent {
                        Text("URGENT")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color(red: 0.13, green: 0.10, blue: 0.08))
                            )
                    }
                }

                Text(reminder.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(cardTextColor(for: reminder))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(targetLine(for: reminder))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(cardTextColor(for: reminder).opacity(0.72))

                Text(conditionLine(for: reminder))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(cardTextColor(for: reminder).opacity(0.72))

                if !reminder.checklist.isEmpty {
                    HStack(spacing: 10) {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(cardTextColor(for: reminder).opacity(0.14))
                                Capsule()
                                    .fill(cardTextColor(for: reminder).opacity(0.70))
                                    .frame(width: proxy.size.width * checklistProgress(for: reminder))
                            }
                        }
                        .frame(height: 6)

                        Text("\(completedCount(for: reminder))/\(reminder.checklist.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(cardTextColor(for: reminder).opacity(0.72))
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            Button {
                complete(reminder)
            } label: {
                ZStack {
                    Circle()
                        .fill(isCompleting ? cardTextColor(for: reminder) : .clear)
                    Circle()
                        .stroke(cardTextColor(for: reminder).opacity(0.75), lineWidth: 1.3)
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(isCompleting ? 1 : 0.45)
                        .opacity(isCompleting ? 1 : 0)
                }
                .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .disabled(isCompleting)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardColor(for: reminder))
        )
        .overlay {
            if isCompleting {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(cardTextColor(for: reminder))
                    .padding(10)
                    .background(.white.opacity(0.78), in: Circle())
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
            }
        }
        .scaleEffect(isCompleting ? 0.96 : 1)
        .opacity(isCompleting ? 0.82 : 1)
        .animation(.spring(response: 0.30, dampingFraction: 0.72), value: isCompleting)
    }

    private func targetLine(for reminder: Reminder) -> String {
        switch reminder.trigger.target {
        case .place(let place):
            return "\(reminder.trigger.triggerType == .leaving ? "->" : "@") \(place.name)"
        case .placeType(let type):
            return "@ any \(type.displayName.lowercased())"
        }
    }

    private func conditionLine(for reminder: Reminder) -> String {
        switch reminder.trigger.triggerType {
        case .arriving:
            return "on arrival"
        case .leaving:
            return "when leaving"
        }
    }

    private func completedCount(for reminder: Reminder) -> Int {
        reminder.checklist.filter { $0.isCompleted }.count
    }

    private func checklistProgress(for reminder: Reminder) -> CGFloat {
        guard !reminder.checklist.isEmpty else { return 0 }
        return CGFloat(completedCount(for: reminder)) / CGFloat(reminder.checklist.count)
    }

    private func icon(for reminder: Reminder) -> String {
        switch reminder.category {
        case .grocery: return "🛒"
        case .home: return "🏠"
        case .health: return "💊"
        case .work: return "🖨️"
        case .general: return reminder.priority == .urgent ? "✏️" : "✨"
        }
    }

    private func cardColor(for reminder: Reminder) -> Color {
        switch reminder.category {
        case .grocery:
            return Color(red: 0.84, green: 1.00, blue: 0.40)
        case .home:
            return Color(red: 1.00, green: 0.76, blue: 0.65)
        case .health:
            return Color(red: 0.82, green: 0.72, blue: 1.00)
        case .work:
            return Color(red: 0.68, green: 0.85, blue: 1.00)
        case .general:
            return reminder.priority == .urgent
                ? Color(red: 1.00, green: 0.72, blue: 0.80)
                : Color(red: 0.93, green: 0.88, blue: 1.00)
        }
    }

    private func cardTextColor(for reminder: Reminder) -> Color {
        switch reminder.category {
        case .grocery:
            return Color(red: 0.18, green: 0.27, blue: 0.08)
        case .home:
            return Color(red: 0.40, green: 0.16, blue: 0.08)
        case .health:
            return Color(red: 0.22, green: 0.10, blue: 0.48)
        case .work:
            return Color(red: 0.05, green: 0.22, blue: 0.38)
        case .general:
            return Color(red: 0.42, green: 0.08, blue: 0.18)
        }
    }

    private var quickAddBar: some View {
        HStack(spacing: 18) {
            barItem("list.bullet", "Reminders", tab: .reminders)
            barItem("square.stack.3d.up", "Places", tab: .places)
            barItem("map", "Map", tab: .map)
            #if DEBUG
            barItem("ladybug", "Debug", tab: .debug)
            #endif
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
        .accessibilityLabel("Add reminder")
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

    private func delete(_ reminder: Reminder) {
        guard let index = viewModel.reminders.firstIndex(where: { $0.id == reminder.id }) else {
            return
        }
        viewModel.delete(at: IndexSet(integer: index))
    }

    private func complete(_ reminder: Reminder) {
        guard completingReminderID != reminder.id else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.66)) {
            completingReminderID = reminder.id
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            withAnimation(.easeInOut(duration: 0.22)) {
                viewModel.toggleCompleted(reminder)
                completingReminderID = nil
            }
        }
    }
}

struct ReminderFormView: View {
    enum TargetChoice: String, CaseIterable, Identifiable {
        case savedPlace
        case placeType

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .savedPlace: return "Saved Place"
            case .placeType: return "Any Type"
            }
        }
    }

    let places: [Place]
    let reminder: Reminder?
    let onSave: (Reminder) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var notes: String
    @State private var category: ReminderCategory
    @State private var priority: ReminderPriority
    @State private var triggerType: TriggerType
    @State private var targetChoice: TargetChoice
    @State private var selectedPlaceId: UUID?
    @State private var selectedPlaceType: PlaceType
    @State private var checklist: [ChecklistItem]
    @State private var newChecklistItem = ""

    init(
        places: [Place],
        reminder: Reminder?,
        onSave: @escaping (Reminder) -> Void
    ) {
        self.places = places
        self.reminder = reminder
        self.onSave = onSave

        _title = State(initialValue: reminder?.title ?? "")
        _notes = State(initialValue: reminder?.notes ?? "")
        _category = State(initialValue: reminder?.category ?? .general)
        _priority = State(initialValue: reminder?.priority ?? .normal)
        _triggerType = State(initialValue: reminder?.trigger.triggerType ?? .arriving)
        _checklist = State(initialValue: reminder?.checklist ?? [])

        if let reminder {
            switch reminder.trigger.target {
            case .place(let place):
                _targetChoice = State(initialValue: .savedPlace)
                _selectedPlaceId = State(initialValue: place.id)
                _selectedPlaceType = State(initialValue: .supermarket)
            case .placeType(let type):
                _targetChoice = State(initialValue: .placeType)
                _selectedPlaceId = State(initialValue: places.first?.id)
                _selectedPlaceType = State(initialValue: type)
            }
        } else {
            _targetChoice = State(initialValue: .savedPlace)
            _selectedPlaceId = State(initialValue: places.first?.id)
            _selectedPlaceType = State(initialValue: .supermarket)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                paperBackground

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Add new reminder")
                            .font(.system(size: 28, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(Color(red: 0.24, green: 0.19, blue: 0.15))
                            .padding(.top, 8)

                        detailsSection
                        triggerSection
                        categorySection
                        prioritySection
                        notesSection
                        checklistSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.13))
                            .frame(width: 48, height: 42)
                            .background(.white.opacity(0.58), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveReminder()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(canSave ? Color(red: 0.18, green: 0.16, blue: 0.13) : .secondary.opacity(0.42))
                            .frame(width: 48, height: 42)
                            .background(.white.opacity(canSave ? 0.58 : 0.42), in: Capsule())
                    }
                    .disabled(!canSave)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Save")
                }
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Buy oat milk...", text: $title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color(red: 0.18, green: 0.15, blue: 0.12))
                .textInputAutocapitalization(.sentences)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.black.opacity(0.04), lineWidth: 1)
        )
    }

    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            formSectionTitle("WHERE SHOULD IT FIRE?")

            LazyVGrid(columns: tileColumns, spacing: 10) {
                ForEach(places) { place in
                    targetTile(
                        icon: icon(for: place.placeType),
                        title: place.name,
                        subtitle: "place",
                        tint: color(for: place.placeType),
                        isSelected: targetChoice == .savedPlace && selectedPlaceId == place.id
                    ) {
                        targetChoice = .savedPlace
                        selectedPlaceId = place.id
                    }
                }

                if places.isEmpty {
                    Text("Add a place before creating a saved-place reminder.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .gridCellColumns(2)
                }

                ForEach(MapScreenViewModel.discoverableCategories) { placeType in
                    targetTile(
                        icon: icon(for: placeType),
                        title: placeType.displayName.lowercased(),
                        subtitle: "category",
                        tint: color(for: placeType),
                        isSelected: targetChoice == .placeType && selectedPlaceType == placeType
                    ) {
                        targetChoice = .placeType
                        selectedPlaceType = placeType
                    }
                }
            }

            formSectionTitle("WHEN YOU...")
                .padding(.top, 4)

            HStack(spacing: 10) {
                ForEach(TriggerType.allCases) { type in
                    optionButton(
                        icon: type == .arriving ? "arrow.left" : "arrow.right",
                        title: type == .arriving ? "Arrive" : "Leave",
                        isSelected: triggerType == type
                    ) {
                        triggerType = type
                    }
                }
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            formSectionTitle("WHAT IS IT ABOUT?")

            LazyVGrid(columns: tileColumns, spacing: 10) {
                ForEach(ReminderCategory.allCases) { option in
                    optionTile(
                        title: option.displayName,
                        subtitle: optionSubtitle(for: option),
                        isSelected: category == option
                    ) {
                        category = option
                    }
                }
            }
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            formSectionTitle("HOW URGENT?")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(ReminderPriority.allCases) { option in
                    optionTile(
                        title: option.displayName,
                        subtitle: prioritySubtitle(for: option),
                        isSelected: priority == option
                    ) {
                        priority = option
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            formSectionTitle("NOTES")

            TextField("Add extra detail...", text: $notes, axis: .vertical)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(3...5)
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            formSectionTitle("CHECKLIST")

            HStack {
                TextField("Add checklist item", text: $newChecklistItem)
                    .font(.system(size: 14, weight: .semibold))

                Button("Add") {
                    addChecklistItem()
                }
                .font(.system(size: 13, weight: .bold))
                .disabled(newChecklistItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            ForEach(checklist) { item in
                HStack {
                    Button {
                        toggleChecklistItem(item)
                    } label: {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        Text(item.title)
                            .strikethrough(item.isCompleted)
                        Spacer()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .buttonStyle(.plain)

                    Button {
                        deleteChecklistItem(item)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 14)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
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

    private var tileColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    }

    private func formSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy))
            .tracking(0.9)
            .foregroundStyle(Color(red: 0.62, green: 0.58, blue: 0.51))
    }

    private func targetTile(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(icon)
                    .font(.system(size: 19))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(tint.opacity(isSelected ? 0.50 : 0.30)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .heavy))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.72))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(Color(red: 0.18, green: 0.15, blue: 0.12))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 58)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.38) : .white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.95) : tint.opacity(0.16), lineWidth: isSelected ? 1.4 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func optionButton(
        icon: String,
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
            }
            .foregroundStyle(isSelected ? .white : Color(red: 0.20, green: 0.17, blue: 0.13))
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color(red: 0.11, green: 0.10, blue: 0.08) : .white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.black.opacity(isSelected ? 0 : 0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func optionTile(
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy))
                Text(subtitle)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.74))
                    .lineLimit(2)
            }
            .foregroundStyle(Color(red: 0.18, green: 0.15, blue: 0.12))
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color(red: 0.94, green: 0.90, blue: 0.82) : .white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color(red: 0.22, green: 0.19, blue: 0.15) : .black.opacity(0.04), lineWidth: isSelected ? 1.2 : 1)
            )
        }
        .buttonStyle(.plain)
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

    private func color(for type: PlaceType) -> Color {
        switch type {
        case .home:
            return Color(red: 1.00, green: 0.76, blue: 0.65)
        case .work:
            return Color(red: 0.68, green: 0.85, blue: 1.00)
        case .supermarket:
            return Color(red: 0.78, green: 1.00, blue: 0.24)
        case .pharmacy:
            return Color(red: 0.82, green: 0.72, blue: 1.00)
        case .postOffice:
            return Color(red: 1.00, green: 0.84, blue: 0.48)
        case .custom:
            return Color(red: 0.88, green: 0.94, blue: 0.82)
        }
    }

    private func optionSubtitle(for category: ReminderCategory) -> String {
        switch category {
        case .grocery: return "shops and errands"
        case .home: return "household"
        case .health: return "medicine and care"
        case .work: return "uni or work"
        case .general: return "anything else"
        }
    }

    private func prioritySubtitle(for priority: ReminderPriority) -> String {
        switch priority {
        case .low: return "quiet reminder"
        case .normal: return "usual nudge"
        case .high: return "important"
        case .urgent: return "tell me right away"
        }
    }

    private var canSave: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespaces).isEmpty
        if targetChoice == .savedPlace {
            return hasTitle && selectedPlace != nil
        }
        return hasTitle
    }

    private var selectedPlace: Place? {
        guard let selectedPlaceId else { return nil }
        return places.first { $0.id == selectedPlaceId }
    }

    private func addChecklistItem() {
        let trimmed = newChecklistItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        checklist.append(ChecklistItem(title: trimmed))
        newChecklistItem = ""
    }

    private func toggleChecklistItem(_ item: ChecklistItem) {
        guard let index = checklist.firstIndex(where: { $0.id == item.id }) else { return }
        checklist[index].isCompleted.toggle()
    }

    private func deleteChecklistItems(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            checklist.remove(at: index)
        }
    }

    private func deleteChecklistItem(_ item: ChecklistItem) {
        checklist.removeAll { $0.id == item.id }
    }

    private func saveReminder() {
        let target: ReminderTarget
        if targetChoice == .savedPlace {
            guard let selectedPlace else { return }
            target = .place(selectedPlace)
        } else {
            target = .placeType(selectedPlaceType)
        }

        let savedReminder = Reminder(
            id: reminder?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces),
            category: category,
            priority: priority,
            trigger: ReminderTrigger(
                id: reminder?.trigger.id ?? UUID(),
                triggerType: triggerType,
                target: target
            ),
            checklist: checklist,
            isCompleted: reminder?.isCompleted ?? false,
            createdAt: reminder?.createdAt ?? Date()
        )

        onSave(savedReminder)
        dismiss()
    }
}
