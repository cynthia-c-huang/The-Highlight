import PhotosUI
import SwiftUI
import UIKit
//Username
//→ Supabase user metadata
//→ account-level identity
//
//Default map location
//→ MapPreferenceStore
//→ currently local app behavior
//
//Appearance
//→ UserDefaults / @AppStorage
//→ local UI behavior
//
//Profile image
//→ UserDefaults
//→ currently local to the device
struct PreferencesView: View {
    let savedHighlightCount: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    //This is another property wrapper observing the same key preferences.appAppearance as the root
    //Although both Swift properties have the same name, they are separate properties in separate views. Their connection is the shared storage key.
    //Recall @AppStorage not only provides reading/writing from UserDefaults, but also when the stored value changes, it tells SwiftUI that the view using this property may need to update.
    @AppStorage(AppAppearance.preferenceKey) private var selectedAppearanceRawValue = AppAppearance.stored().rawValue
    @StateObject private var viewModel = PreferencesViewModel() //@StateObject means PreferencesView creates and preserves one PreferencesViewModel instance while the Preferences screen remains alive.
    @State private var selectedProfilePhoto: PhotosPickerItem?

    init(savedHighlightCount: Int = 0) {
        self.savedHighlightCount = savedHighlightCount
    }

    private var theme: Theme {
        Theme(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topNavigationRow
                    titleSection

                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .accentPrimary))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }

                    profilePictureSection
                    accountSection
                    mapStartingPointSection
                    appearanceSection
                    feedbackSection
                    saveButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { //When the screen appears, SwiftUI starts that task and calls load()
            await viewModel.load()
            selectedAppearanceRawValue = viewModel.selectedAppearance.rawValue
        }
        .task(id: selectedProfilePhoto) {
            await loadSelectedProfilePhoto()
        }
    }

    private var topNavigationRow: some View {
        AppTopNavigationRow(
            title: "PREFERENCES",
            leadingAction: { dismiss() },
            trailingSystemName: "gearshape.fill",
            trailingBackground: theme.iconBackground,
            trailingForeground: .accentPrimary,
            trailingIconSize: 22
        )
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tune how the Highlight remembers meals")
                .appBodyFont(size: 15)
                .foregroundColor(theme.secondaryText)
        }
        .padding(.top, 4)
    }

    private var profilePictureSection: some View {
        let profileImage = viewModel.profileImage
        let hasProfileImage = profileImage != nil

        return preferenceCard {
            HStack(alignment: .top, spacing: 18) {
                ZStack(alignment: .topLeading) {
                    PhotosPicker(selection: $selectedProfilePhoto, matching: .images, photoLibrary: .shared()) {
                        profileImageView(profileImage)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change profile picture")

                    if hasProfileImage {
                        Button {
                            viewModel.clearProfileImage()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(theme.primaryText)
                                .frame(width: 26, height: 26)
                                .background(theme.iconBackground)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                        .offset(x: -4, y: -4)
                        .accessibilityLabel("Remove profile picture")
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    labeledTextField(
                        title: "Username",
                        systemImage: "person.fill",
                        text: $viewModel.username,
                        prompt: "Your highlight name",
                        autocapitalization: .words
                    )

                    HStack(spacing: 8) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.accentPrimary)

                        Text("\(savedHighlightCount) saved highlights")
                            .appBodyFont(size: 13)
                            .foregroundColor(theme.secondaryText)
                    }
                }
            }
        }
    }

    private func profileImageView(_ profileImage: UIImage?) -> some View {
        ZStack {
            if let profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 94, height: 94)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 94, weight: .semibold))
                    .foregroundColor(.accentSecondary)
                    .frame(width: 94, height: 94)
            }
        }
        .frame(width: 94, height: 94)
    }

    private var accountSection: some View {
        preferenceCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .appBodyFont(size: 14)
                        .foregroundColor(theme.primaryText)

                    HStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.accentSecondary)

                            TextField("you@example.com", text: $viewModel.email)
                                .appBodyFont(size: 15)
                                .foregroundColor(theme.primaryText)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 13)
                        .background(theme.fieldBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Button {
                            Task {
                                await viewModel.requestEmailVerification()
                            }
                        } label: {
                            if viewModel.isRequestingEmailVerification {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(width: 72, height: 42)
                            } else {
                                Text("Reverify")
                                    .appBodyFont(size: 13)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(width: 72, height: 42)
                            }
                        }
                        .background(Color.accentPrimary)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                        .disabled(viewModel.isRequestingEmailVerification || viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private var mapStartingPointSection: some View {
        preferenceCard {
            labeledTextField(
                title: "Default map starting point",
                systemImage: "map.fill",
                text: $viewModel.defaultMapStartingPoint,
                prompt: "City or county",
                autocapitalization: .words,
                iconColor: .accentSecondary
            )
        }
    }

    private var selectedAppearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { viewModel.selectedAppearance },
            set: { appearance in
                withAnimation(AppAppearance.transitionAnimation) {
                    viewModel.updateAppearancePreference(appearance)
                    selectedAppearanceRawValue = appearance.rawValue /*Because this property is wrapped in @AppStorage, that assignment does not only change a local Preferences property. It writes UserDefaults["preferences.appAppearance"] = "dark". The app root has its own @AppStorage connected to the same key. When the stored value changes from "light" to "dark", the root’s property wrapper observes that change.*/
                }
            }
        )
    }

    private var appearanceSection: some View {
        preferenceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    settingIcon(viewModel.selectedAppearance.systemImage)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Appearance")
                            .appBodyBoldFont(size: 15)
                            .foregroundColor(theme.primaryText)

                        Text(viewModel.selectedAppearance.subtitle)
                            .appBodyFont(size: 13)
                            .foregroundColor(theme.secondaryText)
                    }

                    Spacer()
                }

                appearanceSelectionControl
            }
        }
    }

    private var appearanceSelectionControl: some View {
        HStack(spacing: 6) {
            ForEach(AppAppearance.allCases) { appearance in
                let isSelected = viewModel.selectedAppearance == appearance

                Button {
                    selectedAppearanceBinding.wrappedValue = appearance
                } label: {
                    //System selected:
                    //- text color = theme.selectedSegmentText
                    //- background = theme.selectedSegmentBackground

                    //System not selected:
                    //- text color = theme.unselectedSegmentText
                    //- background = clear
                    Text(appearance.title)
                        .appBodyBoldFont(size: 13)
                        .foregroundColor(isSelected ? theme.selectedSegmentText : theme.unselectedSegmentText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(isSelected ? theme.selectedSegmentBackground : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(theme.segmentedBackground)
        .clipShape(Capsule())
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var feedbackSection: some View {
        if let statusMessage = viewModel.statusMessage {
            Text(statusMessage)
                .appBodyFont(size: 13)
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }

        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .appBodyFont(size: 13)
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    private var saveButton: some View {
        Button {
            Task {
                let didSave = await viewModel.saveProfilePreferences()
                if didSave {
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSavingProfile {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .textPrimary))
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                }

                Text("Save preferences")
                    .appBodyFont(size: 16)
                    .fontWeight(.bold)
            }
            .foregroundColor(.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSavingProfile || viewModel.isLoading)
        .opacity(viewModel.isSavingProfile || viewModel.isLoading ? 0.7 : 1)
    }

    private func labeledTextField(
        title: String,
        systemImage: String,
        text: Binding<String>,
        prompt: String,
        autocapitalization: TextInputAutocapitalization,
        iconColor: Color = .accentPrimary
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .appBodyFont(size: 14)
                .foregroundColor(theme.primaryText)

            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)

                TextField(prompt, text: text)
                    .appBodyFont(size: 15)
                    .foregroundColor(theme.primaryText)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 13)
            .background(theme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func settingIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.accentSecondary)
            .frame(width: 38, height: 38)
            .background(theme.iconBackground)
            .clipShape(Circle())
    }

    private func preferenceCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    private func loadSelectedProfilePhoto() async {
        guard let selectedProfilePhoto else { return }

        do {
            if let data = try await selectedProfilePhoto.loadTransferable(type: Data.self) {
                viewModel.updateProfileImage(with: data)
            }
        } catch {
            viewModel.errorMessage = "Unable to load that photo: \(error.localizedDescription)"
            viewModel.statusMessage = nil
        }

        self.selectedProfilePhoto = nil
    }

    private struct Theme {
        let colorScheme: ColorScheme

        private var isDark: Bool {
            colorScheme == .dark
        }

        var background: Color {
            isDark ? .backgroundDarkPrimary : .backgroundPrimary
        }

        var primaryText: Color {
            isDark ? .backgroundPrimary : .textPrimary
        }

        var secondaryText: Color {
            primaryText.opacity(0.7)
        }

        var cardBackground: Color {
            isDark ? .textPrimary : .containerPrimary
        }

        var fieldBackground: Color {
            isDark ? Color.backgroundDarkPrimary.opacity(0.72) : Color.backgroundPrimary.opacity(0.8)
        }

        var iconBackground: Color {
            isDark ? .textPrimary : Color.backgroundPrimary.opacity(0.8)
        }

        var segmentedBackground: Color {
            fieldBackground
        }

        var selectedSegmentBackground: Color {
            .accentSecondary
        }

        var selectedSegmentText: Color {
            .textPrimary
        }

        var unselectedSegmentText: Color {
            primaryText.opacity(0.72)
        }
    }
}

#Preview("Preferences") {
    NavigationStack {
        PreferencesView(savedHighlightCount: 12)
    }
}
