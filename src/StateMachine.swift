import Foundation

public struct State<StateId: Hashable, ContextValue: AnyObject> {
    public let id: StateId
    public let didEnter: (StateMachine<StateId, ContextValue>.Context) async -> Void
    public let willExit: (StateMachine<StateId, ContextValue>.Context) async -> Void

    public init(_ id: StateId, didEnter: @escaping (StateMachine<StateId, ContextValue>.Context) async -> Void, willExit: @escaping (StateMachine<StateId, ContextValue>.Context) async -> Void) {
        self.id = id
        self.didEnter = didEnter
        self.willExit = willExit
    }
}

public final class StateMachine<T: Hashable, ContextValue: AnyObject> {

    public struct Context {
        public let value: ContextValue
        public let stateMachine: StateMachine<T, ContextValue>

        public init(value: ContextValue, stateMachine: StateMachine<T, ContextValue>) {
            self.value = value
            self.stateMachine = stateMachine
        }
    }

    public enum ExecutingType {
        case executingDidEnter
        case executingWillExit
        case noop
    }

    let states: [T: State<T, ContextValue>]
    private weak var weakContext: ContextValue?
    private(set) var currentState: State<T, ContextValue>
    private(set) var previousState: State<T, ContextValue>
    private(set) var hasStarted: Bool = false
    private(set) var executing: ExecutingType = .noop
    private var hasContext: Bool = false

    public init(initialStateId: T, contextType: ContextValue.Type, states: [State<T, ContextValue>]) {
        var statesMap = [T: State<T, ContextValue>]()
        for s in states {
            statesMap[s.id] = s
        }
        guard let firstState = statesMap[initialStateId] else { fatalError("Initial state not configured in states.") }
        self.states = statesMap
        self.currentState = firstState
        self.previousState = firstState
    }

    /// Starts the state machine executing the initialState didEnter closure. This method can't be called more than once.
    ///
    /// Accepts a context value to allow decoupling the initialization of the machine from the start of the execution.
    public func start(context: ContextValue) async {
        assert(!hasStarted, "State machine already started!")
        assert(executing == .noop || executing == .executingDidEnter, "Executing must be noop or executingDidEnter. Found \(executing)")
        self.hasContext = !(context is EmptyContext)
        self.weakContext = context
        guard let context = getContext() else { return }
        hasStarted = true
        executing = .executingDidEnter
        await currentState.didEnter(context)
        executing = .noop
    }

    /// Changes the current state to another state calling the willExit closure on the current state, updating the current state value and then calling the didEnter closure on the newly updated state.
    ///
    /// Can't be called while the state machine is already executing a willExit closure.
    public func changeTo(_ state: T) async {
        guard let newState = states[state] else { fatalError("State id not configured in states.") }
        guard executing != .executingWillExit else { fatalError("Can't change state from a willExit() call.") }
        guard let context = getContext() else { return }

        assert(executing == .noop || executing == .executingDidEnter, "Executing must be noop or executingDidEnter. Found \(executing)")
        executing = .executingWillExit
        await currentState.willExit(context)
        executing = .noop

        previousState = currentState
        currentState = newState

        assert(executing == .noop || executing == .executingDidEnter, "Executing must be noop or executingDidEnter. Found \(executing)")
        executing = .executingDidEnter
        await currentState.didEnter(context)
        executing = .noop
    }

    public func getContext() -> StateMachine<T, ContextValue>.Context? {
        if hasContext {
            guard let contextValue = weakContext else { return nil }
            return StateMachine<T, ContextValue>.Context(value: contextValue, stateMachine: self)
        } else {
            return StateMachine<T, ContextValue>.Context(value: EmptyContext() as! ContextValue, stateMachine: self)
        }
    }
}

public final class EmptyContext {}

public extension StateMachine where ContextValue == EmptyContext {
    convenience init(initialStateId: T, states: [State<T, ContextValue>]) {
        self.init(initialStateId: initialStateId, contextType: EmptyContext.self, states: states)
    }

    func start() async {
        await self.start(context: EmptyContext())
    }
}
