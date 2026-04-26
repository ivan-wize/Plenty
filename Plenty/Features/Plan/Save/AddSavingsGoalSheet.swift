//
//  AddSavingsGoalSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/AddSavingsGoalSheet.swift
//
//  Create or edit a SavingsGoal. Name, target, optional deadline,
//  type (general or specific category). Used in the Plan tab Save mode.
//

import SwiftUI
import SwiftData

struct AddSavingsGoalSheet: View {

    let goal: SavingsGoal?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var targetAmount: Decimal = 0
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
    @State private var goalType: SavingsGoalType = .general
    @State private var monthlyContribution: Decimal = 0
    @State private var hasMonthlyTarget: Bool = false
    @State private var note: String = ""

    @State private var showDeleteConfirmation = false

    @FocusState private var nameFocused: Bool

    init(goal: SavingsGoal? = nil) {
        self.goal = goal
        if let goal {
            _name = State(initialValue: goal.name)
            _targetAmount = State(initialValue: goal.targetAmount)
            _hasDeadline = State(initialValue: goal.deadline != nil)
            _deadline = State(initialValue: goal.deadline ?? Calendar.current.date(byAdding: .month, value: 6, to: .now)!)
            _goalType = State(initialValue: goal.goalType)
            _monthlyContribution = State(initialValue: goal.monthlyContribution ?? 0)
            _hasMonthlyTarget = State(initialValue: goal.monthlyContribution != nil)
            _note = State(initialValue: goal.note ?? "")
        }
    }

    private var isEditing: Bool { goal != nil }

    private var canSave: Bool {
        targetAmount > 0 && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                targetSection
                typeSection
                deadlineSection
                monthlySection
                noteSection
                if isEditing {
                    deleteSection
                }
            }
            .navigationTitle(isEditing ? "Edit Goal" : "New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .confirmationDialog(
                "Delete this goal?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Contribution history will also be removed.")
            }
            .onAppear {
                if !isEditing { nameFocused = true }
            }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section("Name") {
            TextField("e.g. Vacation, Emergency Fund, New Bike", text: $name)
                .textInputAutocapitalization(.words)
                .focused($nameFocused)
        }
    }

    private var targetSection: some View {
        Section {
            HStack {
                Text("$")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                CurrencyField(value: $targetAmount, prompt: "0", accent: Theme.sage)
            }
        } header: {
            Text("Target")
        }
    }

    private var typeSection: some View {
        Section {
            Picker("Type", selection: $goalType) {
                ForEach(SavingsGoalType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var deadlineSection: some View {
        Section {
            Toggle("Set a deadline", isOn: $hasDeadline)
            if hasDeadline {
                DatePicker("By", selection: $deadline, in: Date.now..., displayedComponents: .date)
            }
        }
    }

    private var monthlySection: some View {
        Section {
            Toggle("Monthly target", isOn: $hasMonthlyTarget)
            if hasMonthlyTarget {
                HStack {
                    Text("$")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                    CurrencyField(value: $monthlyContribution, prompt: "0", accent: Theme.sage)
                }
            }
        } footer: {
            if hasMonthlyTarget {
                Text("Plenty will count this toward your spendable each month so the number reflects what you can actually spend after saving.")
                    .font(Typography.Support.caption)
            }
        }
    }

    private var noteSection: some View {
        Section("Note (optional)") {
            TextField("e.g. trip to Japan in March", text: $note, axis: .vertical)
                .lineLimit(1...3)
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete goal", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel", role: .cancel) { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(isEditing ? "Save" : "Add") { save() }
                .fontWeight(.semibold)
                .disabled(!canSave)
        }
    }

    // MARK: - Actions

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let goal {
            goal.name = trimmedName
            goal.targetAmount = targetAmount
            goal.goalType = goalType
            goal.deadline = hasDeadline ? deadline : nil
            goal.monthlyContribution = hasMonthlyTarget && monthlyContribution > 0 ? monthlyContribution : nil
            goal.note = note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note
        } else {
            let new = SavingsGoal(
                name: trimmedName,
                targetAmount: targetAmount,
                goalType: goalType,
                deadline: hasDeadline ? deadline : nil,
                monthlyContribution: hasMonthlyTarget && monthlyContribution > 0 ? monthlyContribution : nil,
                note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note
            )
            modelContext.insert(new)
        }
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        guard let goal else { return }
        modelContext.delete(goal)
        try? modelContext.save()
        dismiss()
    }
}
