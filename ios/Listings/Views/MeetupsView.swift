import SwiftData
import SwiftUI

struct MeetupsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MeetupPlan.date) private var plans: [MeetupPlan]
    @State private var editing: MeetupPlan?

    private var upcoming: [MeetupPlan] { plans.filter { $0.date >= .now } }
    private var past: [MeetupPlan] { plans.filter { $0.date < .now }.reversed() }

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    ContentUnavailableView(
                        "No meetups planned",
                        systemImage: "calendar",
                        description: Text("Open a listing and choose Plan a meetup.")
                    )
                } else {
                    List {
                        if !upcoming.isEmpty {
                            Section("Upcoming") { rows(upcoming) }
                        }
                        if !past.isEmpty {
                            Section("Past") { rows(past) }
                        }
                    }
                }
            }
            .navigationTitle("Meetups")
            .sheet(item: $editing) { plan in
                MeetupEditorView(plan: plan)
            }
        }
    }

    private func rows(_ items: [MeetupPlan]) -> some View {
        ForEach(items) { plan in
            Button {
                editing = plan
            } label: {
                MeetupRow(plan: plan)
            }
            .foregroundStyle(Color.primary)
            .swipeActions {
                Button("Delete", role: .destructive) { delete(plan) }
            }
        }
    }

    private func delete(_ plan: MeetupPlan) {
        MeetupReminderService.cancel(id: plan.planID)
        context.delete(plan)
        try? context.save()
    }
}

struct MeetupRow: View {
    let plan: MeetupPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.listingTitle).font(.headline)
            Label(plan.date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                .font(.subheadline)
            Label(plan.spot, systemImage: "mappin.and.ellipse")
                .font(.subheadline)
            if !plan.notes.isEmpty {
                Text(plan.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Creates a meetup plan for a listing, or edits/deletes an existing one.
struct MeetupEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let listing: Listing?
    private let plan: MeetupPlan?
    @State private var date: Date
    @State private var spot: String
    @State private var notes: String
    @State private var errorMessage: String?

    init(listing: Listing) {
        self.listing = listing
        self.plan = nil
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        _date = State(initialValue: tomorrow)
        _spot = State(initialValue: MeetingSpot.all[0])
        _notes = State(initialValue: "")
    }

    init(plan: MeetupPlan) {
        self.listing = nil
        self.plan = plan
        _date = State(initialValue: plan.date)
        _spot = State(initialValue: plan.spot)
        _notes = State(initialValue: plan.notes)
    }

    private var itemTitle: String { listing?.title ?? plan?.listingTitle ?? "" }

    private var spots: [String] {
        MeetingSpot.all.contains(spot) ? MeetingSpot.all : MeetingSpot.all + [spot]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(itemTitle).font(.headline)
                    Text("Pick a time and a public spot on campus. Contact the seller separately to confirm.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("When and where") {
                    DatePicker("Date and time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Picker("Meeting spot", selection: $spot) {
                        ForEach(spots, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                if plan != nil {
                    Section {
                        Button("Delete meetup", role: .destructive, action: deletePlan)
                    }
                }
            }
            .navigationTitle(plan == nil ? "Plan a meetup" : "Edit meetup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
    }

    private func save() {
        guard date > .now else {
            errorMessage = "Choose a date and time in the future."
            return
        }
        let target: MeetupPlan
        if let plan {
            plan.date = date
            plan.spot = spot
            plan.notes = notes
            target = plan
        } else if let listing {
            target = MeetupPlan(listingID: listing.id, listingTitle: listing.title, date: date, spot: spot, notes: notes)
            context.insert(target)
        } else {
            return
        }

        do {
            try context.save()
        } catch {
            errorMessage = "Couldn't save the meetup: \(error.localizedDescription)"
            return
        }

        let id = target.planID
        let title = target.listingTitle
        let place = target.spot
        let when = target.date
        Task { await MeetupReminderService.schedule(id: id, title: title, spot: place, date: when) }

        model.showToast(plan == nil ? "Meetup plan saved" : "Meetup updated")
        dismiss()
    }

    private func deletePlan() {
        guard let plan else { return }
        MeetupReminderService.cancel(id: plan.planID)
        context.delete(plan)
        try? context.save()
        model.showToast("Meetup removed")
        dismiss()
    }
}
