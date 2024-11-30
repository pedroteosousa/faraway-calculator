//
//  FarawayStateUpdater.swift
//  Faraway Calculator
//
//  Created by Pedro Sousa on 08/11/24.
//

import UIKit
import SwiftUI
import Vision

enum Resource {
    case animal
    case mineral
    case food
}

enum CardColor {
    case gray
    case red
    case green
    case blue
    case yellow
}

struct Card {
    let requirements: [Resource: Int]
    let state: CardState
    let points: CardPoints
    
    func score(state: CardState) -> Int {
        for (resource, count) in requirements {
            if state.resources[resource, default: 0] < count {
                return 0
            }
        }
        return points.score(state: state)
    }
}

struct CardState {
    var colors: [CardColor: Int]
    var resources: [Resource: Int]
    var clues: Int
    var nights: Int
    
    mutating func add(card: Card) {
        for (color, count) in card.state.colors {
            colors[color, default: 0] += count
        }
        for (resource, count) in card.state.resources {
            resources[resource, default: 0] += count
        }
        clues += card.state.clues
        nights += card.state.nights
    }
}

struct CardPoints {
    let colors: [CardColor: Int]
    let colorGroup: Int
    let resources: [Resource: Int]
    let resourceGroup: Int
    let clues: Int
    let nights: Int
    let nothing: Int
    
    func score(state: CardState) -> Int {
        var score: Int = nothing
        score += nights * state.nights
        score += clues * state.clues
        var colorGroupCount = 10
        let allColors: [CardColor] = [.gray, .red, .green, .blue, .yellow]
        for color in allColors {
            let count = state.colors[color, default: 0]
            if color != .gray {
                colorGroupCount = min(colorGroupCount, count)
            }
            score += colors[color, default: 0] * count
        }
        score += colorGroup * colorGroupCount
        var resourceGroupCount = 1000
        let allResources: [Resource] = [.mineral, .animal, .food]
        for resource in allResources {
            let count = state.resources[resource, default: 0]
            resourceGroupCount = min(resourceGroupCount, count)
            score += resources[resource, default: 0] * count
        }
        score += resourceGroup * resourceGroupCount
        return score
    }
}

struct CardsInfo {
    var regions: [Int: Card] = [:]
    var sanctuaries: [Int: Card] = [:]
    
    static var shared: CardsInfo = {
        let instance = CardsInfo()
        return instance
    }()
    
    func get_region(id: Int) -> Card? {
        return regions[id]
    }
    
    func get_sanctuary(id: Int) -> Card? {
        return sanctuaries[id]
    }
    
    private init() {
        guard let filepath = Bundle.main.path(forResource: "card_info", ofType: "csv") else {
            return
        }
        var data = ""
        do {
            data = try String(contentsOfFile: filepath)
        } catch {
            print(error)
            return
        }
        let rows = data.components(separatedBy: "\n")
        for row in rows {
            let columns = row.components(separatedBy: ",")
            if columns.count <= 1 {
                continue
            }
            var cols: [Int] = []
            for str in columns {
                if str == "" {
                    cols.append(0)
                } else {
                    cols.append(Int(str)!)
                }
            }
            let color: CardColor = {
                switch(cols[2]) {
                    case 0: return .gray
                    case 1: return .red
                    case 2: return .green
                    case 3: return .blue
                    default: return .yellow
                }
            }()
            let cardState = CardState(colors: [color:1], resources: [.mineral:cols[4],.animal:cols[5],.food:cols[6]], clues: cols[3], nights: cols[1])
            let cardPoints = CardPoints(colors: [.gray: cols[22], .red:cols[15], .green:cols[16], .blue:cols[17], .yellow:cols[18]], colorGroup: cols[19], resources: [.mineral: cols[10], .animal: cols[11], .food: cols[12]], resourceGroup: cols[21], clues: cols[13], nights: cols[14], nothing: cols[20])
            let requirements: [Resource: Int] = [.mineral:cols[7], .animal:cols[8], .food:cols[9]]
            let card = Card(requirements: requirements, state: cardState, points: cardPoints)
            if cols[23] == 0 {
                self.regions[cols[0]] = card
            } else {
                self.sanctuaries[cols[0]] = card
            }
        }
    }
}

struct Detection {
    let boundingBox: CGRect
    let identifier: String
    let confidence: VNConfidence
}

enum CardType {
    case region
    case sanctuary
}

struct GameStateView: View {
    let state: GameState
    @Binding var showScore: Bool
    
    var body: some View {
        VStack {
            if state.regions.count == 8 {
                HStack {
                    ForEach(0..<state.sanctuaries.count, id: \.self) { index in
                        CardView(id: state.sanctuaries[index], type: .sanctuary, score: showScore ? state.cardScore[state.sanctuaries[index]] : nil)
                    }
                }
                HStack {
                    ForEach(0..<4) { index in
                        CardView(id: state.regions[index], type: .region, score: showScore ? state.cardScore[state.regions[index]] : nil)
                    }
                }
                HStack {
                    ForEach(4..<8) { index in
                        CardView(id: state.regions[index], type: .region, score: showScore ? state.cardScore[state.regions[index]] : nil)
                    }
                }
            }
        }
    }
}

struct GameState: Hashable {
    var regions: [Int] = []
    var sanctuaries: [Int] = []
    var cardScore: [Int: Int] = [:]
    var score: Int = 0
    
    init(cards: [Detection]) {
        let sortedCards = cards.sorted {
            if $0.boundingBox.maxY < $1.boundingBox.midY {
                return false
            } else if $1.boundingBox.maxY < $0.boundingBox.midY {
                return true
            } else {
                return $0.boundingBox.midX < $1.boundingBox.midX
            }
        }
        for card in sortedCards {
            let type = card.identifier.prefix(1)
            let id: Int = Int(card.identifier.suffix(card.identifier.count - 1))!
            if type == "R" {
                regions.append(id)
            } else {
                sanctuaries.append(id)
            }
        }
        if self.isValid() {
            self.calculateScore()
        }
    }
    
    func isValid() -> Bool {
        if regions.count != 8 {
            return false
        }
        var seenRegions: [Int: Bool] = [:]
        var seenSanctuaries: [Int: Bool] = [:]
        var expectedSanctuaryCount: Int = 0
        var lastRegion: Int = CardsInfo.shared.regions.count
        for region in regions {
            if seenRegions[region, default: false] {
                return false
            }
            seenRegions[region] = true
            if region > lastRegion {
                expectedSanctuaryCount += 1
            }
            lastRegion = region
        }
        if sanctuaries.count != expectedSanctuaryCount {
            return false
        }
        for sanctuary in sanctuaries {
            if seenSanctuaries[sanctuary, default: false] {
                return false
            }
            seenSanctuaries[sanctuary] = true
        }
        return true
    }
    
    private mutating func calculateScore() {
        score = 0
        var state: CardState = CardState(colors: [:], resources: [:], clues: 0, nights: 0)
        let regions = regions.reversed()
        for sanctuary in sanctuaries {
            state.add(card: CardsInfo.shared.get_sanctuary(id: sanctuary)!)
        }
        for region in regions {
            let card = CardsInfo.shared.get_region(id: region)!
            state.add(card: card)
            let cardScore = card.score(state: state)
            self.cardScore[region] = cardScore
            score += cardScore
        }
        for sanctuary in sanctuaries {
            let card = CardsInfo.shared.get_sanctuary(id: sanctuary)!
            let cardScore = card.score(state: state)
            self.cardScore[sanctuary] = cardScore
            score += cardScore
        }
    }
    
    func hash(into hasher: inout Hasher) {
        let str = regions.description + "," + sanctuaries.description
        str.hash(into: &hasher)
    }
    
    static func == (lhs: GameState, rhs: GameState) -> Bool {
        return
            lhs.regions == rhs.regions &&
            lhs.sanctuaries == rhs.sanctuaries
    }
}

enum GameStateError: Error {
    case noData
    case notEnoughData
    case notConfident
}

struct GameStateUpdater {
    struct StateQueue {
        var states: [GameState] = []
        mutating func enqueue(_ value: GameState) {
            states.append(value)
        }
        mutating func dequeue() -> GameState? {
            guard !states.isEmpty else {
                return nil
            }
            return states.removeFirst()
        }
        var head: GameState? {
            return states.first
        }
        var tail: GameState? {
            return states.last
        }
        var size: Int {
            return states.count
        }
    }
    
    private var stopped: Bool = false
    private var stateFrequencyCount: [GameState: Int] = [:]
    private var stateQueue: StateQueue = .init()
    private let targetStateCount: Int = 30
    private let targetConfidence: Float = 0.7
    
    static var shared = GameStateUpdater()
    
    private init() {}
    
    mutating func newDetection(cards: [Detection]) {
        if self.stopped {
            return
        }
        let state = GameState.init(cards: cards)
        if !state.isValid() {
            return
        }
        stateQueue.enqueue(state)
        self.stateFrequencyCount[state, default: 0] += 1
        if stateQueue.size < targetStateCount {
            return
        }
        if stateQueue.size > targetStateCount {
            let removedState = stateQueue.dequeue()!
            self.stateFrequencyCount[removedState, default: 0] -= 1
        }
    }
    
    mutating func reset() {
        self.stateFrequencyCount = [:]
        self.stateQueue = .init()
        self.stopped = false
    }
    
    mutating func getState() throws -> GameState {
        if stateQueue.size == 0 {
            throw GameStateError.noData
        }
        if stateQueue.size < targetStateCount {
            throw GameStateError.notEnoughData
        }
        let candidateState = self.stateFrequencyCount.max(by: { $0.value < $1.value })?.key
        let confidence = Float(self.stateFrequencyCount[candidateState!]!) / Float(self.stateQueue.size)
        if confidence < targetConfidence {
            throw GameStateError.notConfident
        }
        self.stopped = true
        return candidateState!
    }
}
