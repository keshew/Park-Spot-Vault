import SwiftUI
import PhotosUI
import AVFoundation
import UserNotifications

struct SaveParkingFlow: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var permissions: PermissionCenter
    @StateObject private var location = LocationProvider()
    @State private var step = 0
    @State private var title = ""
    @State private var floor = ""
    @State private var zone = ""
    @State private var notes = ""
    @State private var landmarks = ""
    @State private var image: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var errorMessage: String?
    @State private var reminderDenied = false
    @State private var saving = false
    @State private var loadingPhoto = false
    @State private var reminderMinutes = 0
    @FocusState private var focusedField: Field?
    let onSaved: (ParkingSession) -> Void

    private enum Field: Hashable { case title, floor, zone, notes, landmarks }
    private var canSave: Bool {
        !loadingPhoto && (location.location != nil || image != nil || [title, floor, zone, notes, landmarks].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }
    private var pageTitle: String { ["Save parking", "Parking details", "Review your spot", "Parking saved"][step] }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                ScrollViewReader { reader in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Color.clear.frame(height: 1).id("save-top")
                            if step == 0 { capturePage }
                            else if step == 1 { detailsPage }
                            else if step == 2 { reviewPage }
                            else { successPage }
                        }
                        .vaultPagePadding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: step) { _ in reader.scrollTo("save-top", anchor: .top) }
                    .onChange(of: focusedField) { field in
                        guard let field else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            guard focusedField == field else { return }
                            withAnimation(.easeOut(duration: 0.2)) { reader.scrollTo(field, anchor: .center) }
                        }
                    }
                }
            }
        }
        .background { VaultBackground() }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(image: $image).ignoresSafeArea()
        }
        .onChange(of: photoItem) { item in
            guard let item else { return }
            loadingPhoto = true
            Task { @MainActor in
                defer { loadingPhoto = false }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self), let photo = UIImage(data: data) else {
                        errorMessage = "This photo could not be opened. Please choose another image."
                        return
                    }
                    image = photo
                } catch { errorMessage = "The photo could not be loaded. Please try again." }
            }
        }
        .alert("Unable to continue", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .alert("Notifications are off", isPresented: $reminderDenied) {
            Button("Save without reminder") { reminderMinutes = 0; persistSession() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can enable notifications in Settings. Your parking details can still be saved without a reminder.")
        }
        .onDisappear { location.stop() }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(step == 3 ? "ALL SET" : "STEP \(step + 1) OF 3")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.vaultAccent)
                    Text(pageTitle)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .accessibilityLabel(step == 3 ? "Close saved parking" : "Cancel saving parking")
            }
            if step < 3 {
                HStack(spacing: 6) {
                    ForEach(0..<3) { index in
                        Capsule().fill(index <= step ? Color.vaultSecondary : Color.white.opacity(0.1)).frame(height: 4)
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if step == 1 || step == 2 {
                Button {
                    focusedField = nil
                    step -= 1
                } label: {
                    Image(systemName: "arrow.left").font(.headline)
                        .frame(width: 52, height: 56)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .accessibilityLabel("Previous step")
                .disabled(saving)
            }
            LiquidButton(title: saving ? "Saving…" : (step == 3 ? "Done" : step == 2 ? "Save parking" : "Continue"), icon: step >= 2 ? "checkmark" : "arrow.right") {
                focusedField = nil
                if step == 3 { dismiss() }
                else if step == 2 { save() }
                else { step += 1 }
            }
            .accessibilityIdentifier("save.continue")
            .disabled(saving || loadingPhoto || (step == 1 && !canSave))
        }
        .frame(maxWidth: 680)
        .padding(.horizontal, 20).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private var capturePage: some View {
        VStack(alignment: .leading, spacing: 20) {
            ParkingBuddyTip(
                artwork: .capture,
                title: "Let's save a few clues",
                message: "Save a location or snap a nearby sign. No GPS signal? I'll help you remember the spot with a photo and notes."
            )
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: location.location == nil ? "location.circle" : "checkmark.circle.fill")
                            .font(.system(size: 28)).foregroundColor(.vaultSecondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.isLocating ? "Finding your location…" : location.location == nil ? "Save your location" : "GPS location saved")
                                .font(.headline)
                            Text(location.location == nil ? "Works best outdoors" : "Accuracy \(location.accuracy)")
                                .font(.caption).foregroundColor(.vaultMuted)
                        }
                    }
                    if let error = location.errorMessage {
                        Text(error).font(.subheadline).foregroundColor(.vaultWarning)
                    }
                    SecondaryButton(title: location.location == nil ? "Use current location" : "Refresh location", icon: "location.fill") { location.capture() }
                        .disabled(location.isLocating)
                    if location.isLocating { ProgressView().tint(.vaultSecondary) }
                }
            }
            if let image {
                PremiumParkingScene(colors: [.vaultAccent, .vaultCard], image: image)
                    .aspectRatio(1.4, contentMode: .fit)
                Button(role: .destructive) { self.image = nil; photoItem = nil } label: {
                    Label("Remove photo", systemImage: "trash")
                }
                .font(.subheadline)
            }
            HStack(spacing: 12) {
                SecondaryButton(title: "Camera", icon: "camera") { openCamera() }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Photos", systemImage: "photo.on.rectangle")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                }
                .disabled(loadingPhoto)
            }
            if loadingPhoto { Label("Loading photo…", systemImage: "photo").font(.subheadline).foregroundColor(.vaultMuted) }
        }
    }

    private var detailsPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            ParkingBuddyTip(
                artwork: .permissions,
                title: "What will you recognize?",
                message: "Tell me the floor, space number or a nearby landmark. You can type your own floor instead of choosing one."
            )
            field("Place name", hint: "e.g. City Mall parking", text: $title, focus: .title)
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Floor").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 66))], spacing: 8) {
                        ForEach(["Ground", "B1", "B2", "P1", "P2"], id: \.self) { value in
                            Button { floor = value } label: {
                                Text(value).font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(floor == value ? .vaultBackground : .white)
                                    .frame(maxWidth: .infinity).frame(height: 44)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(floor == value ? Color.vaultSecondary : Color.white.opacity(0.06)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    TextField("Or enter a floor", text: $floor)
                        .focused($focusedField, equals: .floor)
                        .id(Field.floor)
                        .accessibilityIdentifier("save.floor")
                        .submitLabel(.done).onSubmit { focusedField = nil }
                        .padding(12).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    TextField("Zone or space number (optional)", text: $zone)
                        .textInputAutocapitalization(.characters)
                        .focused($focusedField, equals: .zone)
                        .id(Field.zone)
                        .accessibilityIdentifier("save.zone")
                        .submitLabel(.done).onSubmit { focusedField = nil }
                        .padding(12).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes").font(.headline)
                TextEditor(text: $notes)
                    .focused($focusedField, equals: .notes)
                    .id(Field.notes)
                    .accessibilityIdentifier("save.notes")
                    .scrollContentBackground(.hidden)
                    .frame(height: 130).padding(12).background(GlassFill())
                Text("Try a pillar color, entrance, lift or row number.")
                    .font(.caption).foregroundColor(.vaultMuted)
            }
            field("Landmarks", hint: "e.g. Blue pillar, North lift", text: $landmarks, focus: .landmarks)
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Parking reminder", systemImage: "bell").font(.headline)
                    Picker("Remind me", selection: $reminderMinutes) {
                        Text("No reminder").tag(0)
                        Text("In 30 minutes").tag(30)
                        Text("In 1 hour").tag(60)
                        Text("In 2 hours").tag(120)
                        Text("In 3 hours").tag(180)
                    }
                    .pickerStyle(.menu).tint(.vaultSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !canSave {
                Text("Add a location, photo or parking detail to continue.")
                    .font(.subheadline).foregroundColor(.vaultWarning)
            }
        }
    }

    private var reviewPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            ParkingBuddyTip(
                artwork: .returning,
                title: "One last look together",
                message: "Check your clues, then tap Save parking. I'll keep them ready on Home and in History."
            )
            PremiumParkingScene(colors: [.vaultAccent, .vaultCard], image: image)
                .aspectRatio(1.5, contentMode: .fit)
            GlassCard {
                VStack(spacing: 16) {
                    ReviewRow(title: "Place", value: clean(title).isEmpty ? "Parking spot" : clean(title), icon: "parkingsign")
                    ReviewRow(title: "Floor", value: clean(floor).isEmpty ? "Not specified" : clean(floor), icon: "square.stack")
                    ReviewRow(title: "Zone", value: clean(zone).isEmpty ? "Not specified" : clean(zone), icon: "number")
                    ReviewRow(title: "Location", value: location.location == nil ? "Not saved" : location.coordinate, icon: "location")
                    if !clean(notes).isEmpty { ReviewRow(title: "Notes", value: clean(notes), icon: "note.text") }
                    if !clean(landmarks).isEmpty { ReviewRow(title: "Landmarks", value: clean(landmarks), icon: "mappin") }
                    ReviewRow(title: "Reminder", value: reminderMinutes == 0 ? "Off" : "In \(reminderMinutes) min", icon: "bell")
                }
            }
            Text("Your parking details and photo are stored on this device.")
                .font(.subheadline).foregroundColor(.vaultMuted)
        }
    }

    private var successPage: some View {
        VStack(spacing: 18) {
            ParkingArtwork(.permissions).frame(maxWidth: 280).frame(height: 260)
            Text("See you on the way back")
                .font(.system(size: 26, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
            Text("Your spot is saved. Find it on Home or in History whenever you need it.")
                .font(.body).foregroundColor(.vaultMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
    }

    private func field(_ label: String, hint: String, text: Binding<String>, focus: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.headline)
            TextField(hint, text: text)
                .focused($focusedField, equals: focus)
                .id(focus)
                .accessibilityIdentifier("save." + label.lowercased().replacingOccurrences(of: " ", with: ""))
                .submitLabel(.done).onSubmit { focusedField = nil }
                .padding(16).background(GlassFill())
        }
    }

    private func clean(_ string: String) -> String { string.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "A camera isn't available here. Choose an image with Photos instead."
            return
        }
        Task { @MainActor in
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            var granted = status == .authorized
            if status == .notDetermined { granted = await AVCaptureDevice.requestAccess(for: .video) }
            if granted { showingCamera = true }
            else { errorMessage = "Camera access is off. Enable it in iOS Settings, or use Photos." }
            permissions.refresh()
        }
    }

    private func save() {
        guard canSave, !saving else { return }
        saving = true
        Task { @MainActor in
            if reminderMinutes > 0 {
                let allowed = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
                guard allowed else { saving = false; reminderDenied = true; return }
            }
            persistSession()
        }
    }

    private func persistSession() {
        let filename = image.flatMap(ImageStore.save)
        if image != nil && filename == nil {
            saving = false
            errorMessage = "The photo could not be saved. Please try again or remove the photo."
            return
        }
        let now = Date()
        let session = ParkingSession(
            title: clean(title).isEmpty ? "Parking spot" : clean(title),
            floor: clean(floor), zone: clean(zone), note: clean(notes),
            coordinate: location.location == nil ? "" : location.coordinate,
            accuracy: location.accuracy, distance: "", heading: location.heading ?? 0,
            parkedAt: now, photoFilename: filename,
            landmarks: landmarks.split(separator: ",").map { clean(String($0)) }.filter { !$0.isEmpty },
            reminderAt: reminderMinutes > 0 ? now.addingTimeInterval(Double(reminderMinutes) * 60) : nil
        )
        onSaved(session)
        saving = false
        step = 3
        location.stop()
    }
}
