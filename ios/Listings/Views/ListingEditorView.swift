import PhotosUI
import SwiftUI

/// Create (POST) or update (PUT) a listing, including JPEG photo uploads.
struct ListingEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let existing: Listing?

    @State private var draft: ListingDraft
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var previews: [UIImage] = []
    @State private var photoData: [Data] = []
    @State private var removeCurrentPhotos = false
    @State private var isLoadingPhotos = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(existing: Listing?) {
        self.existing = existing
        _draft = State(initialValue: existing.map { ListingDraft(listing: $0) } ?? ListingDraft())
    }

    private var isEditing: Bool { existing != nil }
    private var currentPhotos: [String] { existing?.photos ?? [] }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Title", text: $draft.title)
                    TextField("Description", text: $draft.description, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Details") {
                    Picker("Listing type", selection: $draft.type) {
                        ForEach(ListingType.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Condition", selection: $draft.condition) {
                        ForEach(ItemCondition.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Status", selection: $draft.status) {
                        ForEach(ListingStatus.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section {
                    photosSection
                } header: {
                    Text("Photos")
                } footer: {
                    Text(isEditing
                         ? "Up to 5 photos. Choosing new photos replaces the current ones."
                         : "Up to 5 photos. They're converted to JPEG before upload.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit listing" : "Post listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(isEditing ? "Save" : "Post") {
                            Task { await save() }
                        }
                        .disabled(draft.trimmedTitle.isEmpty || isLoadingPhotos)
                    }
                }
            }
            .onChange(of: pickerItems) { _, items in
                Task { await loadPhotos(items) }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    @ViewBuilder private var photosSection: some View {
        if !previews.isEmpty {
            thumbnailStrip {
                ForEach(Array(previews.enumerated()), id: \.offset) { _, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        } else if !currentPhotos.isEmpty && !removeCurrentPhotos {
            thumbnailStrip {
                ForEach(currentPhotos, id: \.self) { path in
                    PhotoTile(path: path, cornerRadius: 10)
                        .frame(width: 72, height: 72)
                }
            }
        }

        PhotosPicker(selection: $pickerItems, maxSelectionCount: 5, matching: .images) {
            Label(previews.isEmpty ? "Choose photos" : "Choose different photos", systemImage: "photo.on.rectangle")
        }

        if isLoadingPhotos {
            HStack {
                ProgressView()
                Text("Preparing photos…").foregroundStyle(.secondary)
            }
        }

        if !previews.isEmpty {
            Button("Clear selected photos", role: .destructive) {
                pickerItems = []
            }
        } else if !currentPhotos.isEmpty {
            Toggle("Remove current photos", isOn: $removeCurrentPhotos)
        }
    }

    private func thumbnailStrip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) { content() }
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        defer { isLoadingPhotos = false }
        var images: [UIImage] = []
        var jpegs: [Data] = []
        for item in items {
            guard let raw = try? await item.loadTransferable(type: Data.self),
                  let jpeg = PhotoProcessor.jpeg(from: raw),
                  let image = UIImage(data: jpeg) else { continue }
            images.append(image)
            jpegs.append(jpeg)
        }
        previews = images
        photoData = jpegs
        errorMessage = jpegs.count < items.count ? "Some photos couldn't be read and were skipped." : nil
    }

    private func save() async {
        if let problem = draft.validationMessage {
            errorMessage = problem
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            if let existing {
                try await model.updateListing(existing, draft: draft, newPhotos: photoData, clearPhotos: removeCurrentPhotos)
                model.showToast("Listing updated")
            } else {
                try await model.createListing(draft, photos: photoData)
                model.showToast("Listing posted")
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
