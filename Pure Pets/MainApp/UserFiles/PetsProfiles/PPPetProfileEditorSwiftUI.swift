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
    date.formatted(.dateTime.day().month(.abbreviated).year())
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
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
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

private struct PPPetEditorV4NavigationBar: View {
    let title: String
    let canSave: Bool
    let isSaving: Bool
    let onBack: () -> Void
    let onSave: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.ppTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.ppSurface, in: Circle())
                    .overlay(Circle().stroke(Color.ppSurfaceBorder.opacity(0.70), lineWidth: 0.8))
            }
            .buttonStyle(PPPetProfilePressStyle())
            .accessibilityLabel(PPPetLang("Back"))

            Text(title)
                .font(PPPetProfileFont.title())
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            Button(action: onSave) {
                Group {
                    if isSaving {
                        ProgressView().tint(.ppPrimary)
                    } else {
                        Text(PPPetLang("Save"))
                    }
                }
                .font(PPPetProfileFont.medium())
                .foregroundStyle(canSave ? Color.ppPrimary : Color.ppTextSecondary)
                .frame(minWidth: 54, minHeight: 44)
            }
            .buttonStyle(PPPetProfilePressStyle())
            .disabled(!canSave)
            .accessibilityLabel(PPPetLang("Save"))
        }
        .padding(.horizontal, PPPetProfileMetrics.screenMargin)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.ppBackground.opacity(0.97))
    }
}

private struct PPPetEditorV4Hero: View {
    @ObservedObject var store: PPPetProfileEditorStore
    let isEditing: Bool
    let onPhoto: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var identityTitle: String {
        let value = store.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? PPPetLang("pet_profiles_add_first") : value
    }

    private var hasImage: Bool {
        store.selectedImage != nil || store.remoteImage != nil
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                compactLayout
            }
        }
        .padding(dynamicTypeSize.isAccessibilitySize ? 18 : 16)
        .ppPetSurface(radius: 28, tint: Color.ppSurfaceRaised, elevation: true)
    }

    private var compactLayout: some View {
        HStack(alignment: .center, spacing: 16) {
            photoButton(side: 108)
            identityCopy
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            photoButton(side: 96)
            identityCopy
        }
    }

    private func photoButton(side: CGFloat) -> some View {
        Button(action: onPhoto) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
                    .fill(Color.ppSoftRose.opacity(0.58))

                if let image = store.selectedImage ?? store.remoteImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: side * 0.24, style: .continuous))
                        .padding(4)
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: side * 0.34, weight: .medium))
                        .foregroundStyle(Color.ppPrimary.opacity(0.72))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: side * 0.24, style: .continuous))
                        .padding(4)
                }

                Image(systemName: hasImage ? "camera.fill" : "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 38, height: 38)
                    .background(Color.ppPrimary, in: Circle())
                    .overlay(Circle().stroke(Color.ppSurfaceRaised, lineWidth: 3))
                    .offset(x: 4, y: 4)
            }
            .frame(width: side, height: side)
        }
        .buttonStyle(PPPetProfilePressStyle())
        .accessibilityLabel(PPPetLang(hasImage ? "pet_photo_change" : "pet_photo_pick"))
        .accessibilityHint(PPPetLang("pet_photo_tap"))
    }

    private var identityCopy: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(
                isEditing ? PPPetLang("pet_edit_title") : PPPetLang("pet_add_title"),
                systemImage: "pawprint.fill"
            )
            .font(PPPetProfileFont.caption())
            .foregroundStyle(Color.ppPrimary)

            Text(identityTitle)
                .font(PPPetProfileFont.title())
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            Label(
                store.breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? PPPetLang("pet_photo_tap")
                    : store.breed,
                systemImage: "circle.hexagongrid.fill"
            )
            .font(PPPetProfileFont.footnote())
            .foregroundStyle(Color.ppTextSecondary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                Label(
                    PPPetCountText("pet_profiles_vaccine_count_format", count: store.vaccinations.count),
                    systemImage: "cross.case.fill"
                )
                .font(PPPetProfileFont.footnote())
                .foregroundStyle(Color.ppCareAccent)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.ppCareAccent.opacity(0.10), in: Capsule())

                if store.isDefault {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.ppPremiumAccent)
                        .frame(width: 28, height: 28)
                        .background(Color.ppPremiumAccent.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PPPetEditorV4Field<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(PPPetProfileFont.caption())
                .foregroundStyle(Color.ppTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
    }
}

private struct PPPetEditorV4TextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let field: PPPetEditorField
    @FocusState.Binding var focusedField: PPPetEditorField?
    let keyboardType: UIKeyboardType
    let onChanged: (String) -> Void

    var body: some View {
        PPPetEditorV4Field(title: title) {
            TextField(placeholder, text: $text)
                .font(PPPetProfileFont.body())
                .foregroundStyle(Color.ppTextPrimary)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .keyboardType(keyboardType)
                .focused($focusedField, equals: field)
                .submitLabel(field == .name ? .next : .done)
                .onChange(of: text) { value in onChanged(value) }
                .onSubmit {
                    focusedField = field == .name ? .age : nil
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(
                            focusedField == field ? Color.ppPrimary.opacity(0.72) : Color.ppSurfaceBorder.opacity(0.70),
                            lineWidth: focusedField == field ? 1.4 : 0.8
                        )
                )
        }
    }
}

private struct PPPetEditorV4CategoryField: View {
    let title: String
    let value: String
    let placeholder: String
    let action: () -> Void

    var body: some View {
        PPPetEditorV4Field(title: title) {
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
                        .frame(width: 40, height: 40)
                        .accessibilityHidden(true)
                }
                .padding(.leading, 16)
                .padding(.trailing, 4)
                .frame(minHeight: 56)
                .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.ppSurfaceBorder.opacity(0.70), lineWidth: 0.8)
                )
            }
            .buttonStyle(PPPetProfilePressStyle())
            .accessibilityLabel(title)
            .accessibilityValue(value.isEmpty ? placeholder : value)
            .accessibilityHint(PPPetLang("Select"))
        }
    }
}

private struct PPPetEditorV4Setting: View {
    @ObservedObject var store: PPPetProfileEditorStore
    let onChanged: (Bool) -> Void

    var body: some View {
        Toggle(
            isOn: Binding(
                get: { store.isDefault },
                set: { value in
                    store.isDefault = value
                    onChanged(value)
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
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.ppPremiumAccent)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .ppPrimary))
        .padding(.horizontal, 16)
        .frame(minHeight: 76)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(store.isDefault ? Color.ppPremiumAccent.opacity(0.10) : Color.ppSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(Color.ppSurfaceBorder.opacity(0.70), lineWidth: 0.8)
        )
        .accessibilityValue(store.isDefault ? PPPetLang("Enabled") : PPPetLang("Disabled"))
    }
}

private struct PPPetEditorV4SaveBar: View {
    @ObservedObject var store: PPPetProfileEditorStore
    let onSave: () -> Void

    var body: some View {
        Button(action: onSave) {
            HStack(spacing: 10) {
                if store.isSaving {
                    ProgressView().tint(.white)
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
        .padding(.horizontal, PPPetProfileMetrics.screenMargin)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.ppBackground.opacity(0.98))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.ppSurfaceBorder.opacity(0.62))
                .frame(height: 0.8)
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
        PPPetProfileCanvas {
            VStack(spacing: 0) {
                PPPetEditorV4NavigationBar(
                    title: isEditing ? PPPetLang("pet_edit_title") : PPPetLang("pet_add_title"),
                    canSave: store.canSave,
                    isSaving: store.isSaving,
                    onBack: onBack,
                    onSave: onSave
                )

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 26) {
                            PPPetEditorV4Hero(
                                store: store,
                                isEditing: isEditing,
                                onPhoto: onPhoto
                            )
                            .id("identity")

                            VStack(alignment: .leading, spacing: 14) {
                                PPPetEditorSectionHeading(
                                    title: PPPetLang("pet_section_info"),
                                    hint: PPPetLang(
                                        "pet_section_info_hint",
                                        fallback: PPPetLang("pet_profiles_section_subtitle")
                                    )
                                )

                                PPPetEditorV4TextField(
                                    title: PPPetLang("pet_field_name"),
                                    placeholder: PPPetLang("pet_name_placeholder"),
                                    text: $store.name,
                                    field: .name,
                                    focusedField: $focusedField,
                                    keyboardType: .default,
                                    onChanged: onNameChanged
                                )
                                .id(PPPetEditorField.name)

                                PPPetEditorV4CategoryField(
                                    title: PPPetLang("pet_field_breed"),
                                    value: store.breed,
                                    placeholder: PPPetLang("pet_breed_placeholder"),
                                    action: onBreed
                                )

                                PPPetEditorV4TextField(
                                    title: PPPetLang(
                                        "pet_field_age_short",
                                        fallback: PPPetLang("pet_field_age")
                                    ),
                                    placeholder: PPPetLang("pet_age_months_placeholder"),
                                    text: $store.age,
                                    field: .age,
                                    focusedField: $focusedField,
                                    keyboardType: .numberPad,
                                    onChanged: onAgeChanged
                                )
                                .id(PPPetEditorField.age)
                            }

                            VStack(alignment: .leading, spacing: 14) {
                                PPPetEditorSectionHeading(
                                    title: PPPetLang("pet_section_settings"),
                                    hint: PPPetLang(
                                        "pet_section_settings_hint",
                                        fallback: PPPetLang("pet_default_toggle")
                                    )
                                )
                                PPPetEditorV4Setting(store: store, onChanged: onDefaultChanged)
                            }

                            VStack(alignment: .leading, spacing: 14) {
                                PPPetEditorSectionHeading(
                                    title: PPPetLang("pet_section_vaccinations"),
                                    hint: PPPetLang(
                                        "pet_section_vaccinations_hint",
                                        fallback: PPPetLang("pet_profiles_subtitle")
                                    )
                                )
                                PPPetVaccinationSummary(
                                    store: store,
                                    onAdd: onAddVaccination,
                                    onEdit: onEditVaccination,
                                    onDelete: onDeleteVaccination
                                )
                            }
                        }
                        .frame(maxWidth: PPPetProfileMetrics.contentMaxWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, PPPetProfileMetrics.screenMargin)
                        .padding(.top, 14)
                        .padding(.bottom, 30)
                    }
                    .scrollDismissesKeyboardCompat()
                    .onChange(of: focusedField) { field in
                        guard let field else { return }
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
            }
            .overlay {
                if store.saveSucceeded {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(Color.ppSuccess)
                        Text(PPPetLang("Done"))
                            .font(PPPetProfileFont.medium())
                            .foregroundStyle(Color.ppTextPrimary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .ppPetGlass(radius: 22, tint: Color.ppSuccess.opacity(0.12))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(PPPetLang("Done"))
                }
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Language.isRTL() ? "ar_QA" : "en_QA"))
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
