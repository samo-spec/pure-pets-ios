//
//  PPPetProfilesHostingControllers.swift
//  Pure Pets
//
//  Thin UIKit hosts for the SwiftUI pet-profile surfaces. Existing Objective-C
//  controllers remain the single owners of navigation and domain side effects.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - List host

@objc(PPPetProfilesSwiftUIHostingController)
public final class PPPetProfilesSwiftUIHostingController: UIViewController {
    private let store = PPPetProfilesListStore()
    private var hostingController: UIHostingController<PPPetProfilesListScreen>?

    private let onBack: () -> Void
    private let onAdd: () -> Void
    private let onReminders: () -> Void
    private let onRefresh: () -> Void
    private let onSelect: (PPPetProfile) -> Void
    private let onMakeDefault: (PPPetProfile) -> Void
    private let onDelete: (PPPetProfile) -> Void

    @objc(
        initWithPets:isLoading:hasError:images:onBack:onAdd:onReminders:onRefresh:onSelect:onMakeDefault:onDelete:
    )
    public init(
        pets: NSArray,
        isLoading: Bool,
        hasError: Bool,
        images: NSDictionary,
        onBack: @escaping () -> Void,
        onAdd: @escaping () -> Void,
        onReminders: @escaping () -> Void,
        onRefresh: @escaping () -> Void,
        onSelect: @escaping (PPPetProfile) -> Void,
        onMakeDefault: @escaping (PPPetProfile) -> Void,
        onDelete: @escaping (PPPetProfile) -> Void
    ) {
        self.onBack = onBack
        self.onAdd = onAdd
        self.onReminders = onReminders
        self.onRefresh = onRefresh
        self.onSelect = onSelect
        self.onMakeDefault = onMakeDefault
        self.onDelete = onDelete
        super.init(nibName: nil, bundle: nil)
        update(pets: pets, isLoading: isLoading, hasError: hasError, images: images)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let screen = PPPetProfilesListScreen(
            store: store,
            onBack: onBack,
            onAdd: onAdd,
            onReminders: onReminders,
            onRefresh: onRefresh,
            onSelect: onSelect,
            onMakeDefault: onMakeDefault,
            onDelete: onDelete
        )
        let host = UIHostingController(rootView: screen)
        hostingController = host

        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    @objc(updatePets:isLoading:hasError:images:)
    public func update(
        pets: NSArray,
        isLoading: Bool,
        hasError: Bool,
        images: NSDictionary
    ) {
        let swiftPets = pets.compactMap { $0 as? PPPetProfile }
        var swiftImages: [String: UIImage] = [:]
        for (key, value) in images {
            if let key = key as? String, let image = value as? UIImage {
                swiftImages[key] = image
            }
        }

        let apply = {
            self.store.update(
                pets: swiftPets,
                isLoading: isLoading,
                hasError: hasError,
                images: swiftImages
            )
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }
}

// MARK: - Add/edit host

@objc(PPPetProfileEditorSwiftUIHostingController)
public final class PPPetProfileEditorSwiftUIHostingController: UIViewController {
    private let store: PPPetProfileEditorStore
    private var hostingController: UIHostingController<PPPetProfileEditorScreen>?

    private let editingMode: Bool
    private let onBack: () -> Void
    private let onSave: () -> Void
    private let onPhoto: () -> Void
    private let onBreed: () -> Void
    private let onNameChanged: (String) -> Void
    private let onAgeChanged: (String) -> Void
    private let onDefaultChanged: (Bool) -> Void
    private let onAddVaccination: () -> Void
    private let onEditVaccination: (Int) -> Void
    private let onDeleteVaccination: (Int) -> Void

    @objc(
        initWithName:breed:age:isDefault:vaccinations:selectedImage:remoteImage:isSaving:saveSucceeded:isEditing:onBack:onSave:onPhoto:onBreed:onNameChanged:onAgeChanged:onDefaultChanged:onAddVaccination:onEditVaccination:onDeleteVaccination:
    )
    public init(
        name: String,
        breed: String,
        age: String,
        isDefault: Bool,
        vaccinations: NSArray,
        selectedImage: UIImage?,
        remoteImage: UIImage?,
        isSaving: Bool,
        saveSucceeded: Bool,
        isEditing: Bool,
        onBack: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onPhoto: @escaping () -> Void,
        onBreed: @escaping () -> Void,
        onNameChanged: @escaping (String) -> Void,
        onAgeChanged: @escaping (String) -> Void,
        onDefaultChanged: @escaping (Bool) -> Void,
        onAddVaccination: @escaping () -> Void,
        onEditVaccination: @escaping (Int) -> Void,
        onDeleteVaccination: @escaping (Int) -> Void
    ) {
        let rows = vaccinations.compactMap { value -> PPPetVaccinationRow? in
            guard let record = value as? PPPetVaccinationRecord else { return nil }
            return PPPetVaccinationRow(record: record)
        }
        self.store = PPPetProfileEditorStore(
            name: name,
            breed: breed,
            age: age,
            isDefault: isDefault,
            vaccinations: rows,
            selectedImage: selectedImage,
            remoteImage: remoteImage,
            isSaving: isSaving,
            saveSucceeded: saveSucceeded
        )
        self.editingMode = isEditing
        self.onBack = onBack
        self.onSave = onSave
        self.onPhoto = onPhoto
        self.onBreed = onBreed
        self.onNameChanged = onNameChanged
        self.onAgeChanged = onAgeChanged
        self.onDefaultChanged = onDefaultChanged
        self.onAddVaccination = onAddVaccination
        self.onEditVaccination = onEditVaccination
        self.onDeleteVaccination = onDeleteVaccination
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let screen = PPPetProfileEditorScreen(
            store: store,
            isEditing: editingMode,
            onBack: onBack,
            onSave: onSave,
            onPhoto: onPhoto,
            onBreed: onBreed,
            onNameChanged: onNameChanged,
            onAgeChanged: onAgeChanged,
            onDefaultChanged: onDefaultChanged,
            onAddVaccination: onAddVaccination,
            onEditVaccination: onEditVaccination,
            onDeleteVaccination: onDeleteVaccination
        )
        let host = UIHostingController(rootView: screen)
        hostingController = host

        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    @objc(updateName:breed:age:isDefault:vaccinations:selectedImage:remoteImage:isSaving:saveSucceeded:)
    public func update(
        name: String,
        breed: String,
        age: String,
        isDefault: Bool,
        vaccinations: NSArray,
        selectedImage: UIImage?,
        remoteImage: UIImage?,
        isSaving: Bool,
        saveSucceeded: Bool
    ) {
        let rows = vaccinations.compactMap { value -> PPPetVaccinationRow? in
            guard let record = value as? PPPetVaccinationRecord else { return nil }
            return PPPetVaccinationRow(record: record)
        }
        let apply = {
            self.store.update(
                name: name,
                breed: breed,
                age: age,
                isDefault: isDefault,
                vaccinations: rows,
                selectedImage: selectedImage,
                remoteImage: remoteImage,
                isSaving: isSaving,
                saveSucceeded: saveSucceeded
            )
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }
}

// MARK: - Vaccination host

@objc(PPVaccinationSwiftUIHostingController)
public final class PPVaccinationSwiftUIHostingController: UIViewController {
    private let record: PPPetVaccinationRecord
    private let isNewRecord: Bool
    private let onSaved: () -> Void
    private let onCancelled: () -> Void
    private var hostingController: UIHostingController<PPPetVaccinationEditorScreen>?

    @objc(initWithRecord:isNewRecord:onSaved:onCancelled:)
    public init(
        record: PPPetVaccinationRecord,
        isNewRecord: Bool,
        onSaved: @escaping () -> Void,
        onCancelled: @escaping () -> Void
    ) {
        self.record = record
        self.isNewRecord = isNewRecord
        self.onSaved = onSaved
        self.onCancelled = onCancelled
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let screen = PPPetVaccinationEditorScreen(
            record: record,
            isNewRecord: isNewRecord,
            onSaved: onSaved,
            onCancelled: onCancelled
        )
        let host = UIHostingController(rootView: screen)
        hostingController = host

        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }
}
