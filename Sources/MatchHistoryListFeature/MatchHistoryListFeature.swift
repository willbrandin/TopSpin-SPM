import ComposableArchitecture
import Foundation
import MatchClient
import Models

public typealias MatchHistoryReducer = Reducer<MatchHistoryState, MatchHistoryAction, MatchHistoryEnvironment>

public struct MatchHistoryState: Equatable {
    public init(
        matches: IdentifiedArrayOf<Match> = [],
        selectedMatch: Identified<Match.ID, Match>? = nil,
        isWatchConnected: Bool = false,
        isWCSessionSupported: Bool = false,
        isMatchRequestInFlight: Bool = false,
        isDeleteMatchRequestInFlight: Bool = false
    ) {
        self.matches = matches
        self.selectedMatch =  selectedMatch
        self.isWatchConnected = isWatchConnected
        self.isWCSessionSupported = isWCSessionSupported
        self.isMatchRequestInFlight = isMatchRequestInFlight
        self.isDeleteMatchRequestInFlight = isDeleteMatchRequestInFlight
    }
    
    public var matches: IdentifiedArrayOf<Match>
    public var selectedMatch: Identified<Match.ID, Match>?
    public var isWatchConnected: Bool
    public var isWCSessionSupported: Bool
    public var isMatchRequestInFlight: Bool
    public var isDeleteMatchRequestInFlight: Bool
}

public enum MatchHistoryAction: Equatable {
    case deleteButtonTapped(Match)
    case setSelectedMatch(selection: Match?)
    case viewLoaded
    case matchesResponse(Result<[Match], MatchClient.Failure>)
    case openWatchSettingsTapped
}

public struct MatchHistoryEnvironment {
    public init(
        mainQueue: AnySchedulerOf<DispatchQueue> = .main,
        matchClient: MatchClient = .live
    ) {
        self.mainQueue = mainQueue
        self.matchClient = matchClient
    }
    
    public var mainQueue: AnySchedulerOf<DispatchQueue>
    public var matchClient: MatchClient
}

public let matchHistoryReducer = MatchHistoryReducer
{ state, action, environment in
    switch action {
    case let .matchesResponse(.failure(error)):
        return .none
        
    case let .matchesResponse(.success(matches)):
        state.isMatchRequestInFlight = false
        state.matches = IdentifiedArrayOf<Match>(uniqueElements: matches)
        return .none
        
    case let .setSelectedMatch(selection: .some(match)):
        if let match = state.matches[id: match.id] {
            state.selectedMatch = Identified(
                match,
                id: match.id
            )
        }
        
        return .none
        
    case .setSelectedMatch(selection: .none):
        if let selectionState = state.selectedMatch {
            state.matches[id: selectionState.id] = selectionState.value
        }

        state.selectedMatch = nil
        return .none
        
    case .viewLoaded:
        guard state.matches.isEmpty else { return .none }
        
        state.isMatchRequestInFlight = true
        
        return environment.matchClient.fetch()
            .receive(on: environment.mainQueue)
            .catchToEffect(MatchHistoryAction.matchesResponse)
        
    case let .deleteButtonTapped(match):
        state.isDeleteMatchRequestInFlight = true
        state.matches.removeAll(where: { $0.id == match.id })
        
        return environment.matchClient.delete(match)
            .fireAndForget()
        
    case .openWatchSettingsTapped:
        // TODO: THIS
//        UIApplication.shared.open(URL(string: "itms-watchs://com.willBrandin.dev")!) { (didOpen) in
//            print(didOpen ? "Did open url" : "FAILED TO OPEN")
//        }
        return .none
    }
}

extension MatchHistoryEnvironment {
    static var mocked: Self {
        var matchClient = MatchClient.live
        
        matchClient.fetch = {
            let mocked: [Match] = [
                .init(
                    id: .init(),
                    date: .init(),
                    playerScore: 11,
                    opponentScore: 8,
                    workout: .init(
                        id: .init(),
                        startDate: .distantPast,
                        endDate: .init(),
                        activeCalories: 210,
                        heartRateAverage: 120,
                        heartRateMax: 132,
                        heartRateMin: 110
                    )
                ),
                .init(
                    id: .init(),
                    date: .init(),
                    playerScore: 12,
                    opponentScore: 21,
                    workout: .init(
                        id: .init(),
                        startDate: .distantPast,
                        endDate: .init(),
                        activeCalories: 210,
                        heartRateAverage: 120,
                        heartRateMax: 132,
                        heartRateMin: 110
                    )
                )
            ]
            
            return Effect(value: mocked)
        }

        return Self(mainQueue: .main, matchClient: matchClient)
    }
}