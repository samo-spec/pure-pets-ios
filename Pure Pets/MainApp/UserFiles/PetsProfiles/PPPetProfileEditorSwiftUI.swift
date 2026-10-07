//
//  PPPetProfileEditorSwiftUI.swift
//  Pure Pets
//
//  SwiftUI visual surfaces for add/edit pet and vaccination records. The
//  Objective-C coordinators still own model mutation, PHPicker, persistence,
//  and navigation dismissal.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Value snapshots

struct PPPetVaccinationRow: Identifiable, Equatable {
    let id: String
    let name: String
    let appliedAt: Date?
    let nextDueDate: Date?
    let notes: String

    init(record: PPPetVaccinationRecord) {
        let recordID = record.recordID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = recordID.isEmpty ? "record-\(ObjectIdentifier(record).hashValue)" : recordID
        self.name = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.appliedAt = record.appliedAt
        self.nextDueDate = record.nextDueDate
        self.notes = (record.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var dateSummary: String {
        var parts: [String] = []
        if let appliedAt {
            parts.append("\(PPPetLang("pet_vaccine_applied")): \(PPPetDateText(appliedAt))")
        }
        if let nextDueDate {
            parts.append("\(PPPetLang("pet_vaccine_next_due")): \(PPPetDateText(nextDueDate))")
        }
        return parts.isEmpty ? PPPetLang("pet_vaccine_no_date") : parts.joined(separator: "  ·  ")
    }
}

func PPPetDateText(_ date: Date) -> String {
    date.formatted(.dateTime.day().month(.abbreviated).year()
        .locale(Locale(identifier: Language.isRTL() ? "ar_QA" : "en_QA")))
}

final class PPPetProfileEditorStore: ObservableObject {
    @Published var name: String
    @Published var breed: String
    @Published var age: String
    @Published var isDefault: Bool
    @Published private(set) var vaccinations: [PPPetVaccinationRow]
    @Published var selectedImage: UIImage?
    @Published var remoteImage: UIImage?
    @Published private(set) var isSaving: Bool
    @Published private(set) var saveSucceeded: Bool

    init(
        name: String,
        breed: String,
        age: String,
        isDefault: Bool,
        vaccinations: [PPPetVaccinationRow],
        selectedImage: UIImage?,
        remoteImage: UIImage?,
        isSaving: Bool,
        saveSucceeded: Bool
    ) {
        self.name = name
        self.breed = breed
        self.age = age
        self.isDefault = isDefault
        self.vaccinations = vaccinations
        self.selectedImage = selectedImage
        self.remoteImage = remoteImage
        self.isSaving = isSaving
        self.saveSucceeded = saveSucceeded
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving && !saveSucceeded
    }

    func update(
        name: String,
        breed: String,
        age: String,
        isDefault: Bool,
        vaccinations: [PPPetVaccinationRow],
        selectedImage: UIImage?,
        remoteImage: UIImage?,
        isSaving: Bool,
        saveSucceeded: Bool
    ) {
        self.name = name
        self.breed = breed
        self.age = age
        self.isDefault = isDefault
        self.vaccinations = vaccinations
        self.selectedImage = selectedImage
        self.remoteImage = remoteImage
        self.isSaving = isSaving
        self.saveSucceeded = saveSucceeded
    }
}

// MARK: - Shared editor components

private enum PPPetEditorField: Hashable {
    case name
    case age
    case vaccineName
    case notes
}

private struct PPPetEditorSectionHeading: View {
    let title: String
    let hint: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(PPPetProfileFont.headline())
                .foregroundStyle(Color.ppTextPrimary)
            Text(hint)
                .font(PPPetProfileFont.footnote())
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct PPPetEditorFieldLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(PPPetProfileFont.caption())
            .foregroundStyle(Color.ppTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PPPetEditorTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let field: PPPetEditorField
    @FocusState.Binding var focusedField: PPPetEditorField?
    let keyboardType: UIKeyboardType
    let onChanged: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            PPPetEditorFieldLabel(title: title)

            TextField(placeholder, text: $text)
                .font(PPPetProfileFont.body())
                .foregroundStyle(Color.ppTextPrimary)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .keyboardType(keyboardType)
                .focused($focusedField, equals: field)
                .submitLabel(field == .name ? .next : .done)
                .onChange(of: text) { value in
                    onChanged(value)
                }
                .onSubmit {
                    if field == .name {
                        focusedField = .age
                    } else {
                        focusedField = nil
                    }
                }
                .padding(.horizontal, 15)
                .frame(minHeight: 52)
                .ppPetSurface(
                    radius: 16,
                    tint: focusedField == field ? Color.ppSoftRose.opacity(0.50) : Color.ppSurface,
                    elevation: false
                )
        }
    }
}

private struct PPPetIdentityHeader: View {
    @ObservedObject var store: PPPetProfileEditorStore
    let isEditing: Bool
    let onPhoto: () -> Void

    private var identityTitle: String {
        let value = store.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? PPPetLang("pet_profiles_add_first") : value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .center, spacing: 16) {
                Button(action: onPhoto) {
                    ZStack(alignment: .bottomTrailing) {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(Color.ppSoftRose.opacity(0.58))
                            .frame(width: 112, height: 112)

                        if let image = store.selectedImage ?? store.remoteImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 106, height: 106)
                                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                        } else {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 38, weight: .medium))
                                .foregroundStyle(Color.ppPrimary.opacity(0.72))
                                .frame(width: 106, height: 106)
                                .background(Color.ppSurface.opacity(0.40), in: RoundedRectangle(cornerRadius: 27, style: .continuous))
                        }

                        Image(systemName: "camera.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 38, height: 38)
                            .background(Color.ppPrimary, in: Circle())
                            .overlay(Circle().stroke(Color.ppBackground, lineWidth: 3))
                    }
                }
                .buttonStyle(PPPetProfilePressStyle())
                .accessibilityLabel(
                    PPPetLang(
                        store.selectedImage == nil && store.remoteImage == nil
                            ? "pet_photo_pick"
                            : "pet_photo_change"
                    )
                )
                .accessibilityHint(PPPetLang("pet_photo_tap"))

                VStack(alignment: .leading, spacing: 8) {
                    Text(isEditing ? PPPetLang("pet_edit_title") : PPPetLang("pet_add_title"))
                        .font(PPPetProfileFont.caption())
                        .foregroundStyle(Color.ppPrimary)
                        .textCase(.uppercase)

                    Text(identityTitle)
                        .font(PPPetProfileFont.largeTitle())
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if !store.breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(store.breed)
                            .font(PPPetProfileFont.medium())
                            .foregroundStyle(Color.ppTextSecondary)
                            .lineLimit(2)
                    } else {
                        Text(PPPetLang("pet_photo_tap"))
                            .font(PPPetProfileFont.footnote())
                            .foregroundStyle(Color.ppTextSecondary.opacity(0.76))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Label(
                    store.vaccinations.isEmpty
                        ? PPPetCountText("pet_profiles_vaccine_count_format", count: 0)
                        : PPPetCountText("pet_profiles_vaccine_count_format", count: store.vaccinations.count),
                    systemImage: "cross.case.fill"
                )
                .font(PPPetProfileFont.footnote())
                .foregroundStyle(Color.ppCareAccent)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.ppCareAccent.opacity(0.11), in: Capsule())

                if store.isDefault {
                    Label(PPPetLang("pet_profiles_default_badge"), systemImage: "star.fill")
                        .font(PPPetProfileFont.footnote())
                        .foregroundStyle(Color.ppPremiumAccent)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Color.ppPremiumAccent.opacity(0.15), in: Capsule())
                }

                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .ppPetSurface(radius: 30, tint: Color.ppSurfaceRaised, elevation: true)
    }
}

private struct PPPetCategoryField: View {
    let title: String
    let value: String
    let placeholder: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            PPPetEditorFieldLabel(title: title)
            Button(action: action) {
                HStack(spacing: 12) {
                    Text(value.isEmpty ? placeholder : value)
                        .font(PPPetProfileFont.body())
                        .foregroundStyle(value.isEmpty ? Color.ppTextSecondary : Color.ppTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ppTextSecondary)
                        .frame(width: PPPetProfileMetrics.minimumHitSize, height: PPPetProfileMetrics.minimumHitSize)
                        .accessibilityHidden(true)
                }
                .padding(.leading, 15)
                .padding(.trailing, 4)
                .frame(minHeight: 52)
                .ppPetSurface(radius: 16, tint: Color.ppSurface, elevation: false)
            }
            .buttonStyle(PPPetProfilePressStyle())
            .accessibilityLabel(title)
            .accessibilityValue(value.isEmpty ? placeholder : value)
            .accessibilityHint(PPPetLang("Select"))
        }
    }
}

private struct PPPetDefaultSetting: View {
    @ObservedObject var store: PPPetProfileEditorStore
    let onChanged: (Bool) -> Void

    var body: some View {
        Toggle(
            isOn: Binding(
                get: { store.isDefault },
                set: { newValue in
                    store.isDefault = newValue
                    onChanged(newValue)
                }
            )
        ) {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(PPPetLang("pet_default_toggle"))
                        .font(PPPetProfileFont.body())
                        .foregroundStyle(Color.ppTextPrimary)
                    Text(PPPetLang("pet_profiles_default_badge"))
                        .font(PPPetProfileFont.footnote())
                        .foregroundStyle(Color.ppTextSecondary)
                }
            } icon: {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.ppPremiumAccent)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .ppPrimary))
        .padding(.horizontal, 15)
        .frame(minHeight: 70)
        .ppPetSurface(
            radius: 18,
            tint: store.isDefault ? Color.ppPremiumAccent.opacity(0.10) : Color.ppSurface,
            elevation: false
        )
        .accessibilityValue(store.isDefault ? PPPetLang("Enabled") : PPPetLang("Disabled"))
    }
}

private struct PPPetVaccinationSummary: View {
    @ObservedObject var store: PPPetProfileEditorStore
    let onAdd: () -> Void
    let onEdit: (Int) -> Void
    let onDelete: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(PPPetCountText("pet_profiles_vaccine_count_format", count: store.vaccinations.count))
                .font(PPPetProfileFont.footnote())
                .foregroundStyle(Color.ppCareAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.ppCareAccent.opacity(0.10), in: Capsule())

            if store.vaccinations.isEmpty {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: "cross.case")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.ppCareAccent)
                        .frame(width: 34, height: 34)
                        .background(Color.ppCareAccent.opacity(0.10), in: Circle())
                        .accessibilityHidden(true)
                    Text(PPPetLang("pet_vaccine_no_date"))
                        .font(PPPetProfileFont.footnote())
                        .foregroundStyle(Color.ppTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(store.vaccinations) { vaccination in
                    if let index = store.vaccinations.firstIndex(where: { $0.id == vaccination.id }) {
                        HStack(alignment: .top, spacing: 11) {
                            Button(action: { onEdit(index) }) {
                            HStack(alignment: .top, spacing: 11) {
                                Image(systemName: "cross.case.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.ppCareAccent)
                                    .frame(width: 30, height: 30)
                                    .background(Color.ppCareAccent.opacity(0.11), in: Circle())
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(vaccination.name.isEmpty ? PPPetLang("pet_vaccine_name") : vaccination.name)
                                        .font(PPPetProfileFont.medium())
                                        .foregroundStyle(Color.ppTextPrimary)
                                        .lineLimit(2)
                                    Text(vaccination.dateSummary)
                                        .font(PPPetProfileFont.footnote())
                                        .foregroundStyle(Color.ppTextSecondary)
                                        .lineLimit(3)
                                    if !vaccination.notes.isEmpty {
                                        Text(vaccination.notes)
                                            .font(PPPetProfileFont.footnote())
                                            .foregroundStyle(Color.ppTextSecondary.opacity(0.86))
                                            .lineLimit(2)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .contentShape(Rectangle())
                            }
                            .buttonStyle(PPPetProfilePressStyle())
                            .accessibilityLabel(vaccination.name.isEmpty ? PPPetLang("pet_vaccine_name") : vaccination.name)
                            .accessibilityValue(vaccination.dateSummary)
                            .accessibilityHint(PPPetLang("Edit"))

                            Button(role: .destructive, action: { onDelete(index) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(width: PPPetProfileMetrics.minimumHitSize, height: PPPetProfileMetrics.minimumHitSize)
                            }
                            .buttonStyle(PPPetProfilePressStyle())
                            .accessibilityLabel(PPPetLang("Delete"))
                        }
                        .padding(.vertical, 8)
                    }
                }
            }

            Button(action: onAdd) {
                Label(PPPetLang("pet_vaccine_add"), systemImage: "plus.circle.fill")
                    .font(PPPetProfileFont.medium())
                    .foregroundStyle(Color.ppCareAccent)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.ppCareAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PPPetProfilePressStyle())
            .accessibilityLabel(PPPetLang("pet_vaccine_add"))
        }
        .padding(17)
        .ppPetSurface(radius: 22, tint: Color.ppSurface, elevation: false)
    }
}

private struct PPPetEditorSaveBar: View {
    @ObservedObject var store: PPPetProfileEditorStore
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onSave) {
                HStack(spacing: 9) {
                    if store.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else if store.saveSucceeded {
                        Image(systemName: "checkmark")
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(
                        store.isSaving
                            ? PPPetLang("please_wait")
                            : store.saveSucceeded
                                ? PPPetLang("Done")
                                : PPPetLang("Save")
                    )
                }
            }
            .buttonStyle(PPPetProfilePrimaryButtonStyle())
            .disabled(!store.canSave && !store.saveSucceeded)
            .accessibilityLabel(
                store.isSaving
                    ? PPPetLang("please_wait")
                    : store.saveSucceeded ? PPPetLang("Done") : PPPetLang("Save")
            )
        }
        .padding(.horizontal, PPPetProfileMetrics.screenMargin)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Add/Edit screen

private struct PPPetEditorNavigationBar: View {
    @ObservedObject var store: PPPetProfileEditorStore
    let isEditing: Bool
    let onBack: () -> Void
    let onSave: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var title: some View {
        Text(PPPetLang(isEditing ? "pet_edit_title" : "pet_add_title"))
            .font(PPPetProfileFont.headline())
            .foregroundStyle(Color.ppTextPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.ppTextPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.ppSurface, in: Circle())
                }
                .buttonStyle(PPPetProfilePressStyle())
                .disabled(store.isSaving || store.saveSucceeded)
                .accessibilityLabel(PPPetLang("Back"))

                if !dynamicTypeSize.isAccessibilitySize {
                    title.frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer(minLength: 0)
                }

                Button(action: onSave) {
                    HStack(spacing: 8) {
                        if store.isSaving {
                            ProgressView().tint(.ppTextPrimary)
                        } else if store.saveSucceeded {
                            Image(systemName: "checkmark")
                                .accessibilityHidden(true)
                        }
                        Text(PPPetLang(store.isSaving ? "please_wait" : store.saveSucceeded ? "Done" : "Save"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(PPPetProfileFont.medium())
                    .foregroundStyle(store.canSave ? Color.white : Color.ppTextPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(minWidth: 64, minHeight: 44)
                    .background(store.canSave ? Color.ppPrimary : Color.ppSurface, in: Capsule())
                }
                .buttonStyle(PPPetProfilePressStyle())
                .disabled(!store.canSave)
                .accessibilityIdentifier("petEditor.save")
                .accessibilityHint(PPPetLang(store.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "pet_editor_name_hint" : "pet_editor_save_hint"))
            }
            if dynamicTypeSize.isAccessibilitySize { title }
        }
        .padding(.horizontal, PPPetProfileMetrics.screenMargin)
        .padding(.vertical, 8)
        .background(Color.ppBackground)
    }
}

/// The name is the identity preview and the field itself; there is no second draft.
private struct PPPetEditorPortrait: View {
    @ObservedObject var store: PPPetProfileEditorStore
    @FocusState.Binding var focusedField: PPPetEditorField?
    let onPhoto: () -> Void
    let onNameChanged: (String) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast

    private var hasImage: Bool { store.selectedImage != nil || store.remoteImage != nil }

    var body: some View {
        VStack(spacing: 16) {
            Button(action: onPhoto) {
                VStack(spacing: 8) {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let image = store.selectedImage ?? store.remoteImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    Color.ppSoftRose
                                    Image(systemName: "pawprint.fill")
                                        .font(.system(size: 44, weight: .regular))
                                        .foregroundStyle(Color.ppAccentText)
                                }
                            }
                        }
                        .frame(width: 112, height: 112)
                        .clipShape(Circle())
                        .padding(6)
                        .overlay(Circle().strokeBorder(Color.ppPrimary.opacity(contrast == .increased ? 1 : 0.22), lineWidth: 1))

                        Image(systemName: "camera.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(width: 36, height: 36)
                            .background(Color.ppPrimary, in: Circle())
                            .overlay(Circle().strokeBorder(Color.ppBackground, lineWidth: 3))
                    }
                    Text(PPPetLang(hasImage ? "pet_photo_change" : "pet_editor_add_photo"))
                        .font(PPPetProfileFont.medium())
                        .foregroundStyle(Color.ppAccentText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(PPPetProfilePressStyle())
            .accessibilityLabel(PPPetLang(hasImage ? "pet_photo_change" : "pet_photo_pick"))
            .accessibilityIdentifier("petEditor.photo")

            VStack(spacing: 8) {
                Text(PPPetLang("pet_editor_name_label"))
                    .font(PPPetProfileFont.caption())
                    .foregroundStyle(Color.ppTextSecondary)

                nameField
                    .font(PPPetProfileFont.largeTitle())
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .age }
                    .frame(minHeight: 48)
                    .accessibilityLabel(PPPetLang("pet_field_name"))
                    .accessibilityHint(PPPetLang("pet_editor_name_hint"))
                    .accessibilityIdentifier("petEditor.name")

                Capsule()
                    .fill(focusedField == .name ? Color.ppPrimary : Color.ppSurfaceBorder)
                    .frame(width: 48, height: 2)
                    .accessibilityHidden(true)

                Text(PPPetLang("pet_editor_identity_hint"))
                    .font(PPPetProfileFont.footnote())
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .id(PPPetEditorField.name)
        }
        .multilineTextAlignment(.center)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var nameBinding: Binding<String> {
        Binding(get: { store.name }, set: { value in
            // UIKit must receive the current draft synchronously before a Save tap.
            let name = value.replacingOccurrences(of: "\n", with: " ")
            store.name = name
            onNameChanged(name)
        })
    }

    @ViewBuilder private var nameField: some View {
        if #available(iOS 16.0, *) {
            TextField(PPPetLang("pet_editor_name_prompt"), text: nameBinding, axis: .vertical)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 1...6 : 1...3)
        } else {
            TextField(PPPetLang("pet_editor_name_prompt"), text: nameBinding)
        }
    }
}

private struct PPPetEditorDetailRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    label
                    content()
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    label.frame(width: 92, alignment: .leading)
                    content()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
    }

    private var label: some View {
        Text(title)
            .font(PPPetProfileFont.medium())
            .foregroundStyle(Color.ppTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true) // The native field/button supplies this label.
    }
}

private struct PPPetEditorDefaultSetting: View {
    @ObservedObject var store: PPPetProfileEditorStore
    let onChanged: (Bool) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var binding: Binding<Bool> {
        Binding(get: { store.isDefault }, set: { value in
            store.isDefault = value
            onChanged(value)
        })
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(PPPetLang("pet_default_toggle"))
                .font(PPPetProfileFont.headline())
                .foregroundStyle(Color.ppTextPrimary)
            Text(PPPetLang("pet_editor_default_hint"))
                .font(PPPetProfileFont.footnote())
                .foregroundStyle(Color.ppTextSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    copy
                    Toggle(PPPetLang("pet_default_toggle"), isOn: binding)
                        .labelsHidden()
                }
            } else {
                Toggle(isOn: binding) { copy }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .ppPrimary))
        .accessibilityIdentifier("petEditor.default")
        .padding(.vertical, 8)
    }
}

private struct PPPetEditorVaccinations: View {
    @ObservedObject var store: PPPetProfileEditorStore
    let onAdd: () -> Void
    let onEdit: (Int) -> Void
    let onDelete: (Int) -> Void
    @State private var deletionID: String?
    @State private var isConfirmingDeletion = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(PPPetLang("pet_section_vaccinations"))
                        .font(PPPetProfileFont.title())
                        .foregroundStyle(Color.ppTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(PPPetLang("pet_editor_vaccinations_hint"))
                        .font(PPPetProfileFont.footnote())
                        .foregroundStyle(Color.ppTextSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                if !store.vaccinations.isEmpty {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.ppAccentText)
                            .frame(width: 44, height: 44)
                            .background(Color.ppSurface, in: Circle())
                    }
                    .buttonStyle(PPPetProfilePressStyle())
                    .accessibilityLabel(PPPetLang("pet_vaccine_add"))
                }
            }

            if store.vaccinations.isEmpty {
                Button(action: onAdd) {
                    HStack(spacing: 16) {
                        Image(systemName: "cross.case")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(Color.ppCareAccent)
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(PPPetLang("pet_editor_first_vaccine"))
                                .font(PPPetProfileFont.headline())
                                .foregroundStyle(Color.ppTextPrimary)
                            Text(PPPetLang("pet_editor_vaccine_optional"))
                                .font(PPPetProfileFont.footnote())
                                .foregroundStyle(Color.ppTextSecondary)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "plus")
                            .foregroundStyle(Color.ppAccentText)
                            .accessibilityHidden(true)
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                    .ppPetSurface(radius: 24, tint: .ppSurface, elevation: false)
                }
                .buttonStyle(PPPetProfilePressStyle())
                .accessibilityIdentifier("petEditor.addVaccination")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(store.vaccinations) { vaccination in
                        HStack(alignment: .top, spacing: 8) {
                            Button {
                                if let index = store.vaccinations.firstIndex(where: { $0.id == vaccination.id }) {
                                    onEdit(index)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(vaccination.name.isEmpty ? PPPetLang("pet_vaccine_name") : vaccination.name)
                                        .font(PPPetProfileFont.headline())
                                        .foregroundStyle(Color.ppTextPrimary)
                                    Text(vaccination.dateSummary)
                                        .font(PPPetProfileFont.footnote())
                                        .foregroundStyle(Color.ppTextSecondary)
                                    if !vaccination.notes.isEmpty {
                                        Text(vaccination.notes)
                                            .font(PPPetProfileFont.footnote())
                                            .foregroundStyle(Color.ppTextSecondary)
                                    }
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PPPetProfilePressStyle())
                            .accessibilityHint(PPPetLang("Edit"))

                            Button(role: .destructive) {
                                deletionID = vaccination.id
                                isConfirmingDeletion = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.ppError)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(PPPetProfilePressStyle())
                            .accessibilityLabel(String(format: PPPetLang("pet_editor_remove_vaccine_format"), vaccination.name))
                        }
                        .padding(16)
                        if vaccination.id != store.vaccinations.last?.id {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
                .ppPetSurface(radius: 24, tint: .ppSurface, elevation: false)
            }
        }
        .confirmationDialog(PPPetLang("pet_editor_remove_vaccine_title"), isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
            Button(PPPetLang("Delete"), role: .destructive) {
                if let id = deletionID, let index = store.vaccinations.firstIndex(where: { $0.id == id }) {
                    onDelete(index)
                }
                deletionID = nil
            }
            Button(PPPetLang("Cancel"), role: .cancel) { deletionID = nil }
        } message: {
            Text(PPPetLang("pet_editor_remove_vaccine_message"))
        }
    }
}

struct PPPetProfileEditorScreen: View {
    @ObservedObject var store: PPPetProfileEditorStore
    let isEditing: Bool
    let onBack: () -> Void
    let onSave: () -> Void
    let onPhoto: () -> Void
    let onBreed: () -> Void
    let onNameChanged: (String) -> Void
    let onAgeChanged: (String) -> Void
    let onDefaultChanged: (Bool) -> Void
    let onAddVaccination: () -> Void
    let onEditVaccination: (Int) -> Void
    let onDeleteVaccination: (Int) -> Void

    @FocusState private var focusedField: PPPetEditorField?

    var body: some View {
        VStack(spacing: 0) {
            PPPetEditorNavigationBar(store: store, isEditing: isEditing, onBack: {
                focusedField = nil
                onBack()
            }, onSave: {
                focusedField = nil
                onSave()
            })

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        PPPetEditorPortrait(store: store, focusedField: $focusedField, onPhoto: {
                            focusedField = nil
                            onPhoto()
                        }, onNameChanged: onNameChanged)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(PPPetLang("pet_editor_details_title"))
                                .font(PPPetProfileFont.title())
                                .foregroundStyle(Color.ppTextPrimary)
                                .accessibilityAddTraits(.isHeader)
                            details
                        }
                        PPPetEditorDefaultSetting(store: store, onChanged: onDefaultChanged)
                        Divider()
                        PPPetEditorVaccinations(store: store, onAdd: {
                            focusedField = nil
                            onAddVaccination()
                        }, onEdit: { index in
                            focusedField = nil
                            onEditVaccination(index)
                        }, onDelete: onDeleteVaccination)
                    }
                    .disabled(store.isSaving || store.saveSucceeded)
                    .padding(.horizontal, PPPetProfileMetrics.screenMargin)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboardCompat()
                .onChange(of: focusedField) { field in
                    guard let field else { return }
                    proxy.scrollTo(field, anchor: .center)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if focusedField != nil {
                HStack(spacing: 16) {
                    Text(PPPetLang(focusedField == .age ? "pet_field_age" : "pet_field_name"))
                        .font(PPPetProfileFont.footnote())
                        .foregroundStyle(Color.ppTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(PPPetLang("Done")) { focusedField = nil }
                        .font(PPPetProfileFont.headline())
                        .foregroundStyle(Color.ppAccentText)
                        .frame(minWidth: 44, minHeight: 44)
                        .buttonStyle(PPPetProfilePressStyle())
                }
                .padding(.horizontal, PPPetProfileMetrics.screenMargin)
                .background(Color.ppSurface)
            }
        }
        .background(Color.ppBackground.ignoresSafeArea())
        .tint(.ppAccentText)
        .multilineTextAlignment(.leading)
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Language.isRTL() ? "ar_QA" : "en_QA"))
    }

    private var details: some View {
        VStack(spacing: 0) {
            Button {
                focusedField = nil
                onBreed()
            } label: {
                PPPetEditorDetailRow(title: PPPetLang("pet_field_breed")) {
                    HStack(spacing: 8) {
                        Text(store.breed.isEmpty ? PPPetLang("pet_editor_breed_prompt") : store.breed)
                            .font(PPPetProfileFont.body())
                            .foregroundStyle(store.breed.isEmpty ? Color.ppTextSecondary : Color.ppTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.ppTextSecondary)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PPPetProfilePressStyle())
            .accessibilityLabel(PPPetLang("pet_field_breed"))
            .accessibilityValue(store.breed.isEmpty ? PPPetLang("pet_editor_breed_prompt") : store.breed)
            .accessibilityIdentifier("petEditor.breed")

            Divider().padding(.horizontal, 16)

            PPPetEditorDetailRow(title: PPPetLang("pet_field_age_short")) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField(PPPetLang("pet_editor_age_prompt"), text: Binding(
                        get: { store.age }, set: { value in
                            store.age = value
                            onAgeChanged(value)
                        }
                    ))
                    .font(PPPetProfileFont.body())
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.leading)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .age)
                    .frame(minHeight: 44)
                    .accessibilityLabel(PPPetLang("pet_field_age"))
                    .accessibilityHint(PPPetLang("pet_editor_age_unit"))
                    .accessibilityIdentifier("petEditor.age")
                    Text(PPPetLang("pet_editor_age_unit"))
                        .font(PPPetProfileFont.footnote())
                        .foregroundStyle(Color.ppTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(PPPetEditorField.age)
        }
        .ppPetSurface(radius: 24, tint: .ppSurface, elevation: false)
    }
}

// MARK: - Vaccination sheet

private struct PPPetVaccinationV5Card<Content: View>: View {
    let title: String
    let symbol: String
    let content: () -> Content

    init(
        title: String,
        symbol: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol)
                .font(PPPetProfileFont.medium())
                .foregroundStyle(Color.ppTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            content()
        }
        .padding(16)
        .ppPetSurface(radius: 22, tint: Color.ppSurfaceRaised, elevation: false)
    }
}

struct PPPetVaccinationEditorScreen: View {
    let record: PPPetVaccinationRecord
    let isNewRecord: Bool
    let onSaved: () -> Void
    let onCancelled: () -> Void

    @State private var name: String
    @State private var appliedDate: Date
    @State private var notes: String
    @State private var nextDueEnabled: Bool
    @State private var nextDueDate: Date
    @State private var showValidation = false
    @FocusState private var focusedField: PPPetEditorField?

    init(
        record: PPPetVaccinationRecord,
        isNewRecord: Bool,
        onSaved: @escaping () -> Void,
        onCancelled: @escaping () -> Void
    ) {
        self.record = record
        self.isNewRecord = isNewRecord
        self.onSaved = onSaved
        self.onCancelled = onCancelled
        _name = State(initialValue: record.name)
        _appliedDate = State(initialValue: record.appliedAt ?? Date())
        _notes = State(initialValue: record.notes ?? "")
        _nextDueEnabled = State(initialValue: record.nextDueDate != nil)
        _nextDueDate = State(initialValue: record.nextDueDate ?? Date())
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showValidation = true
            focusedField = .vaccineName
            return
        }

        record.name = trimmedName
        record.appliedAt = appliedDate
        record.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        record.nextDueDate = nextDueEnabled ? nextDueDate : nil
        onSaved()
    }

    var body: some View {
        PPPetProfileCanvas {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button(action: onCancelled) {
                        Text(PPPetLang("Cancel"))
                            .font(PPPetProfileFont.medium())
                            .foregroundStyle(Color.ppTextSecondary)
                            .frame(minWidth: PPPetProfileMetrics.minimumHitSize, minHeight: PPPetProfileMetrics.minimumHitSize)
                    }
                    .buttonStyle(PPPetProfilePressStyle())
                    .accessibilityLabel(PPPetLang("Cancel"))

                    Text(isNewRecord ? PPPetLang("pet_vaccine_add") : PPPetLang("pet_vaccine_edit"))
                        .font(PPPetProfileFont.headline())
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity)

                    Button(action: save) {
                        Group {
                            if canSave { Text(isNewRecord ? PPPetLang("Add") : PPPetLang("Save")) }
                            else { Text(isNewRecord ? PPPetLang("Add") : PPPetLang("Save")) }
                        }
                        .font(PPPetProfileFont.medium())
                        .foregroundStyle(canSave ? Color.ppPrimary : Color.ppTextSecondary)
                        .frame(minWidth: PPPetProfileMetrics.minimumHitSize, minHeight: PPPetProfileMetrics.minimumHitSize)
                    }
                    .buttonStyle(PPPetProfilePressStyle())
                    .disabled(!canSave)
                    .accessibilityLabel(isNewRecord ? PPPetLang("Add") : PPPetLang("Save"))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(Color.ppBackground.opacity(0.96))

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: "cross.case.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.ppCareAccent)
                                    .frame(width: 48, height: 48)
                                    .background(Color.ppCareAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .accessibilityHidden(true)

                                Text(isNewRecord ? PPPetLang("pet_vaccine_add_subtitle") : PPPetLang("pet_vaccine_edit_subtitle"))
                                    .font(PPPetProfileFont.body())
                                    .foregroundStyle(Color.ppTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(16)
                            .ppPetSurface(radius: 24, tint: Color.ppCareAccent.opacity(0.09), elevation: false)

                            PPPetVaccinationV5Card(
                                title: PPPetLang("pet_section_vaccinations"),
                                symbol: "cross.case.fill"
                            ) {
                                VStack(alignment: .leading, spacing: 8) {
                                    PPPetEditorFieldLabel(title: PPPetLang("pet_vaccine_name"))
                                    TextField(PPPetLang("pet_vaccine_name_prompt"), text: $name)
                                        .font(PPPetProfileFont.body())
                                        .foregroundStyle(Color.ppTextPrimary)
                                        .focused($focusedField, equals: .vaccineName)
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .notes }
                                        .padding(.horizontal, 15)
                                        .frame(minHeight: 56)
                                        .ppPetSurface(
                                            radius: 16,
                                            tint: showValidation ? Color.ppError.opacity(0.08) : Color.ppSurface,
                                            elevation: false
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(showValidation ? Color.ppError.opacity(0.72) : .clear, lineWidth: 1)
                                        )
                                        .id(PPPetEditorField.vaccineName)

                                    if showValidation {
                                        Text(PPPetLang("pet_vaccine_name_required", fallback: PPPetLang("pet_name_required_msg")))
                                            .font(PPPetProfileFont.footnote())
                                            .foregroundStyle(Color.ppError)
                                    }
                                }

                                Divider().overlay(Color.ppSurfaceBorder.opacity(0.72))

                                DatePicker(
                                    PPPetLang("pet_vaccine_applied"),
                                    selection: $appliedDate,
                                    displayedComponents: .date
                                )
                                .font(PPPetProfileFont.medium())
                                .foregroundStyle(Color.ppTextPrimary)
                                .tint(.ppPrimary)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 56)
                                .ppPetSurface(radius: 16, tint: Color.ppSurface, elevation: false)
                            }

                            PPPetVaccinationV5Card(
                                title: PPPetLang("pet_vaccine_notes_label"),
                                symbol: "note.text"
                            ) {
                                TextField(PPPetLang("pet_vaccine_notes_placeholder"), text: $notes)
                                    .font(PPPetProfileFont.body())
                                    .foregroundStyle(Color.ppTextPrimary)
                                    .focused($focusedField, equals: .notes)
                                    .padding(.horizontal, 15)
                                    .frame(minHeight: 56)
                                    .ppPetSurface(radius: 16, tint: Color.ppSurface, elevation: false)
                                    .id(PPPetEditorField.notes)
                            }

                            PPPetVaccinationV5Card(
                                title: PPPetLang("pet_vaccine_remind"),
                                symbol: "bell.badge.fill"
                            ) {
                                Toggle(isOn: $nextDueEnabled) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(PPPetLang("pet_vaccine_next_due"))
                                            .font(PPPetProfileFont.body())
                                            .foregroundStyle(Color.ppTextPrimary)
                                        Text(PPPetLang("pet_vaccine_remind"))
                                            .font(PPPetProfileFont.footnote())
                                            .foregroundStyle(Color.ppTextSecondary)
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: .ppPrimary))
                                .padding(.horizontal, 2)
                                .frame(minHeight: 52)

                                if nextDueEnabled {
                                    DatePicker(
                                        PPPetLang("pet_vaccine_next_due"),
                                        selection: $nextDueDate,
                                        displayedComponents: .date
                                    )
                                    .font(PPPetProfileFont.medium())
                                    .foregroundStyle(Color.ppTextPrimary)
                                    .tint(.ppPrimary)
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 56)
                                    .ppPetSurface(radius: 16, tint: Color.ppSoftRose.opacity(0.34), elevation: false)
                                }
                            }
                        }
                        .frame(maxWidth: PPPetProfileMetrics.contentMaxWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, PPPetProfileMetrics.screenMargin)
                        .padding(.top, 14)
                        .padding(.bottom, 36)
                    }
                    .scrollDismissesKeyboardCompat()
                    .onChange(of: focusedField) { field in
                        guard let field else { return }
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
            }
        }
        .onAppear {
            guard isNewRecord else { return }
            DispatchQueue.main.async {
                focusedField = .vaccineName
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Language.isRTL() ? "ar_QA" : "en_QA"))
    }
}
