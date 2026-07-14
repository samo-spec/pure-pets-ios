//
//  PPHeroApexMotionTests.swift
//  Pure PetsTests
//
//  Focused lifecycle and interruption coverage for the shared hero engine.
//

import XCTest
@testable import Pure_Pets

final class PPHeroApexMotionTests: XCTestCase {
    private var activeEnvironment: PPHeroApexMotionEnvironment {
        PPHeroApexMotionEnvironment(
            isAttached: true,
            hasValidGeometry: true,
            isApplicationActive: true,
            isReduceMotionEnabled: false,
            isLowPowerModeEnabled: false,
            isThermallyConstrained: false
        )
    }

    func testColdAttachRunsEntranceBeforeAmbientMotion() throws {
        var machine = PPHeroApexMotionStateMachine()

        let entrance = machine.send(.environmentChanged(activeEnvironment))

        XCTAssertEqual(entrance?.previous, .detached)
        XCTAssertEqual(entrance?.current, .entering)
        XCTAssertFalse(machine.hasCompletedEntrance)

        let ambient = machine.send(
            .entranceCompleted(generation: try XCTUnwrap(entrance?.generation))
        )

        XCTAssertEqual(ambient?.current, .ambient)
        XCTAssertTrue(machine.hasCompletedEntrance)
    }

    func testExplicitStopPersistsAndRejectsStaleEntranceCompletion() throws {
        var machine = PPHeroApexMotionStateMachine()
        let entrance = try XCTUnwrap(
            machine.send(.environmentChanged(activeEnvironment))
        )

        XCTAssertEqual(machine.send(.stopRequested)?.current, .idle)
        XCTAssertFalse(machine.wantsMotion)
        XCTAssertTrue(machine.hasCompletedEntrance)
        XCTAssertNil(
            machine.send(.entranceCompleted(generation: entrance.generation))
        )
        XCTAssertEqual(machine.state, .idle)

        XCTAssertEqual(machine.send(.startRequested)?.current, .ambient)
        XCTAssertTrue(machine.wantsMotion)
    }

    func testReduceMotionUsesStaticStateWithoutDeferredEntrance() {
        var machine = PPHeroApexMotionStateMachine()
        var reducedEnvironment = activeEnvironment
        reducedEnvironment.isReduceMotionEnabled = true

        XCTAssertEqual(
            machine.send(.environmentChanged(reducedEnvironment))?.current,
            .reduced
        )
        XCTAssertTrue(machine.hasCompletedEntrance)
        XCTAssertEqual(
            machine.send(.environmentChanged(activeEnvironment))?.current,
            .ambient
        )
    }

    func testInactiveApplicationSuspendsAndResumesAmbientState() throws {
        var machine = PPHeroApexMotionStateMachine()
        let entrance = try XCTUnwrap(
            machine.send(.environmentChanged(activeEnvironment))
        )
        _ = machine.send(.entranceCompleted(generation: entrance.generation))

        var inactiveEnvironment = activeEnvironment
        inactiveEnvironment.isApplicationActive = false
        XCTAssertEqual(
            machine.send(.environmentChanged(inactiveEnvironment))?.current,
            .suspended
        )
        XCTAssertEqual(
            machine.send(.environmentChanged(activeEnvironment))?.current,
            .ambient
        )
    }

    func testInterruptedRecoveryRejectsStaleSettlingCompletion() throws {
        var machine = try makeAmbientMachine()

        XCTAssertEqual(machine.send(.interactionBegan)?.current, .interactive)
        let firstSettling = try XCTUnwrap(machine.send(.interactionEnded))
        XCTAssertEqual(firstSettling.current, .settling)

        XCTAssertEqual(machine.send(.interactionBegan)?.current, .interactive)
        XCTAssertNil(
            machine.send(.settlingCompleted(generation: firstSettling.generation))
        )
        XCTAssertEqual(machine.state, .interactive)

        let secondSettling = try XCTUnwrap(machine.send(.interactionEnded))
        XCTAssertEqual(
            machine.send(
                .settlingCompleted(generation: secondSettling.generation)
            )?.current,
            .ambient
        )
    }

    func testEnergyAndThermalConstraintsResolveToStaticState() throws {
        var machine = try makeAmbientMachine()
        var lowPowerEnvironment = activeEnvironment
        lowPowerEnvironment.isLowPowerModeEnabled = true

        XCTAssertEqual(
            machine.send(.environmentChanged(lowPowerEnvironment))?.current,
            .reduced
        )

        var thermalEnvironment = activeEnvironment
        thermalEnvironment.isThermallyConstrained = true
        XCTAssertNil(machine.send(.environmentChanged(thermalEnvironment)))
        XCTAssertEqual(machine.state, .reduced)

        XCTAssertEqual(
            machine.send(.environmentChanged(activeEnvironment))?.current,
            .ambient
        )
    }

    func testExplicitStopDuringInteractionReturnsToDeterministicIdleState() throws {
        var machine = try makeAmbientMachine()
        _ = machine.send(.interactionBegan)

        XCTAssertEqual(machine.send(.stopRequested)?.current, .idle)
        XCTAssertFalse(machine.wantsMotion)
        XCTAssertNil(machine.send(.interactionEnded))
        XCTAssertEqual(machine.state, .idle)
    }

    private func makeAmbientMachine() throws -> PPHeroApexMotionStateMachine {
        var machine = PPHeroApexMotionStateMachine()
        let entrance = try XCTUnwrap(
            machine.send(.environmentChanged(activeEnvironment))
        )
        _ = machine.send(.entranceCompleted(generation: entrance.generation))
        XCTAssertEqual(machine.state, .ambient)
        return machine
    }
}
