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
    @State private var reminderBeingEdited: Reminder?
    @State private var isShowingNewReminder = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.reminders) { reminder in
                    Button {
                        reminderBeingEdited = reminder
                    } label: {
                        reminderRow(reminder)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button {
                            viewModel.toggleCompleted(reminder)
                        } label: {
                            Label(reminder.isCompleted ? "Undo" : "Done", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
                }
                .onDelete(perform: viewModel.delete)
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingNewReminder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay {
                if viewModel.reminders.isEmpty {
                    ContentUnavailableView(
                        "No reminders yet",
                        systemImage: "bell",
                        description: Text("Tap + to create your first context reminder.")
                    )
                }
            }
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
    }

    private func reminderRow(_ reminder: Reminder) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "bell.fill")
                    .foregroundStyle(reminder.isCompleted ? .green : priorityColor(reminder.priority))
                Text(reminder.title)
                    .font(.headline)
                    .strikethrough(reminder.isCompleted)
            }

            Text(summary(for: reminder))
                .font(.caption)
                .foregroundStyle(.secondary)

            if !reminder.checklist.isEmpty {
                Text("\(completedCount(for: reminder))/\(reminder.checklist.count) checklist items done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func summary(for reminder: Reminder) -> String {
        let action = reminder.trigger.triggerType == .arriving ? "Arriving" : "Leaving"
        let target: String

        switch reminder.trigger.target {
        case .place(let place):
            target = place.name
        case .placeType(let type):
            target = "any \(type.displayName.lowercased())"
        }

        return "\(action) at \(target) - \(reminder.priority.displayName) - \(reminder.category.displayName)"
    }

    private func completedCount(for reminder: Reminder) -> Int {
        reminder.checklist.filter { $0.isCompleted }.count
    }

    private func priorityColor(_ priority: ReminderPriority) -> Color {
        switch priority {
        case .low: return .gray
        case .normal: return .blue
        case .high: return .orange
        case .urgent: return .red
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
