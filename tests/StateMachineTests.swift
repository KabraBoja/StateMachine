import XCTest
@testable import StateMachine

class StateMachineTests: XCTestCase {

    enum TestStates: Hashable {
        case A
        case B
        case C
    }

    var didEnterACount = 0
    var willExitACount = 0
    var didEnterBCount = 0
    var willExitBCount = 0
    var didEnterCCount = 0
    var willExitCCount = 0

    override func tearDown() {
        super.tearDown()
        didEnterACount = 0
        willExitACount = 0
        didEnterBCount = 0
        willExitBCount = 0
        didEnterCCount = 0
        willExitCCount = 0
    }

    func testStateMachineWithoutContext() async {
        let stateMachine = StateMachine(initialStateId: TestStates.A, states: [
            State(.A, didEnter: { _ in
            self.didEnterACount += 1
            }, willExit: { _ in
                self.willExitACount += 1
            }),
        State(.B, didEnter: { context in
            self.didEnterBCount += 1
            await context.stateMachine.changeTo(.C)
            }, willExit: { _ in
                self.willExitBCount += 1
            }),
        State(.C, didEnter: { context in
            self.didEnterCCount += 1
            await context.stateMachine.changeTo(.A)
            }, willExit: { _ in
                self.willExitCCount += 1
            }),
        ])

        await stateMachine.start()
        await stateMachine.changeTo(.B)
        XCTAssert(didEnterACount == 2)
        XCTAssert(willExitACount == 1)
        XCTAssert(didEnterBCount == 1)
        XCTAssert(willExitBCount == 1)
        XCTAssert(didEnterCCount == 1)
        XCTAssert(willExitCCount == 1)
    }

    func testStateMachineWithContext() async {

        class ContextContainer {
            var sequenceString: String = ">"
        }

        let stateMachine = StateMachine(initialStateId: TestStates.A, contextType: ContextContainer.self, states: [
            State(.A, didEnter: { context in
                context.value.sequenceString.append("entersA>")
            }, willExit: { context in
                context.value.sequenceString.append("exitsA>")
            }),
        State(.B, didEnter: { context in
            context.value.sequenceString.append("entersB>")
            await context.stateMachine.changeTo(.C)
            }, willExit: { context in
                context.value.sequenceString.append("exitsB>")
            }),
        State(.C, didEnter: { context in
            context.value.sequenceString.append("entersC>")
            await context.stateMachine.changeTo(.A)
            }, willExit: { context in
                context.value.sequenceString.append("exitsC>")
            }),
        ])

        let context = ContextContainer()
        await stateMachine.start(context: context)
        await stateMachine.changeTo(.B)

        guard let container = stateMachine.getContext()?.value else { XCTFail("no context"); return }
        print(container.sequenceString)
        XCTAssert(container.sequenceString == ">entersA>exitsA>entersB>exitsB>entersC>exitsC>entersA>")
    }

    func testWhenContextIsNotRetainedThenStateMachineStops() async {

        class ContextContainer {}

        let stateMachine = StateMachine(initialStateId: TestStates.A, contextType: ContextContainer.self, states: [
            State(.A, didEnter: { _ in
            self.didEnterACount += 1
            }, willExit: { _ in
                self.willExitACount += 1
            }),
        State(.B, didEnter: { context in
            self.didEnterBCount += 1
            await context.stateMachine.changeTo(.C)
            }, willExit: { _ in
                self.willExitBCount += 1
            }),
        State(.C, didEnter: { context in
            self.didEnterCCount += 1
            await context.stateMachine.changeTo(.A)
            }, willExit: { _ in
                self.willExitCCount += 1
            }),
        ])

        await stateMachine.start(context: ContextContainer())
        await stateMachine.changeTo(.B)
        XCTAssert(didEnterACount == 1)
        XCTAssert(willExitACount == 0)
        XCTAssert(didEnterBCount == 0)
        XCTAssert(willExitBCount == 0)
        XCTAssert(didEnterCCount == 0)
        XCTAssert(willExitCCount == 0)
        XCTAssertNil(stateMachine.getContext())
    }
}
