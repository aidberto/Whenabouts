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
        VStack(alignment: .leading, spacing: 2) {
            Text(todayStamp)
                .font(.system(size: 12, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(.secondary)

            Text(activeReminders.isEmpty ? "inbox zero" : "here now")
                .font(.system(size: 42, weight: .bold, design: .serif))
                .italic()
                .foregroundStyle(Color(red: 0.18, green: 0.13, blue: 0.10))
        }
    }

    private var todayStamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM / h:mma"
        return formatter.string(from: Date()).lowercased()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🌿")
                .font(.system(size: 42))

            VStack(spacing: 6) {
                Text("nothing on the list.")
                    .font(.system(size: 21, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color(red: 0.17, green: 0.14, blue: 0.11))

                Text("You're caught up. Future-you will appreciate it.")
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 230)
            }

            Button {
                isShowingNewReminder = true
            } label: {
                Label("Add a reminder", systemImage: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 0.08, green: 0.10, blue: 0.05))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.78, green: 1.00, blue: 0.24))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color(red: 0.10, green: 0.10, blue: 0.08), lineWidth: 1.8)
                    )
            }
            .buttonStyle(.plain)
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
                        reminderBeingEdited = reminder
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            viewModel.toggleCompleted(reminder)
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
        HStack(alignment: .top, spacing: 14) {
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
                viewModel.toggleCompleted(reminder)
            } label: {
                Circle()
                    .stroke(cardTextColor(for: reminder).opacity(0.75), lineWidth: 1.3)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardColor(for: reminder))
        )
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

            Button {
                isShowingNewReminder = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(red: 0.08, green: 0.10, blue: 0.05))
                    .frame(width: 56, height: 56)
                    .background(
                        Circle().fill(Color(red: 0.78, green: 1.00, blue: 0.24))
                    )
                    .overlay(Circle().stroke(.black.opacity(0.72), lineWidth: 2))
            }
            .buttonStyle(.plain)

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
            Form {
                detailsSection
                triggerSection
                checklistSection
            }
            .navigationTitle(reminder == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveReminder()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Reminder title", text: $title)
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(2...4)
            Picker("Category", selection: $category) {
                ForEach(ReminderCategory.allCases) { category in
                    Text(category.displayName).tag(category)
                }
            }
            Picker("Priority", selection: $priority) {
                ForEach(ReminderPriority.allCases) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }
        }
    }

    private var triggerSection: some View {
        Section("Trigger") {
            Picker("When", selection: $triggerType) {
                ForEach(TriggerType.allCases) { triggerType in
                    Text(triggerType.displayName).tag(triggerType)
                }
            }

            Picker("Target", selection: $targetChoice) {
                ForEach(TargetChoice.allCases) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }

            if targetChoice == .savedPlace {
                if places.isEmpty {
                    Text("Add a place before creating a saved-place reminder.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Place", selection: $selectedPlaceId) {
                        ForEach(places) { place in
                            Text(place.name).tag(Optional(place.id))
                        }
                    }
                }
            } else {
                Picker("Place Type", selection: $selectedPlaceType) {
                    ForEach(MapScreenViewModel.discoverableCategories) { placeType in
                        Text(placeType.displayName).tag(placeType)
                    }
                }
            }
        }
    }

    private var checklistSection: some View {
        Section("Checklist") {
            HStack {
                TextField("Add checklist item", text: $newChecklistItem)
                Button("Add") {
                    addChecklistItem()
                }
                .disabled(newChecklistItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            ForEach(checklist) { item in
                Button {
                    toggleChecklistItem(item)
                } label: {
                    HStack {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        Text(item.title)
                    }
                }
                .foregroundStyle(.primary)
            }
            .onDelete(perform: deleteChecklistItems)
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
