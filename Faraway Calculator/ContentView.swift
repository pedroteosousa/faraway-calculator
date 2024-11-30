//
//  ContentView.swift
//  Faraway Calculator
//
//  Created by Pedro Sousa on 29/10/24.
//

import SwiftUI

struct ContentView: View {
    let scoreTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var score: Int = 0
    @State private var state: GameState? = nil
    @State private var showScore: Bool = false
    @State private var message: String = ""
    
    func updateView() {
        do {
            state = try GameStateUpdater.shared.getState()
            score = state!.score
        }
        catch GameStateError.noData {
            message = "Point the camera at the cards"
        }
        catch GameStateError.notEnoughData {
            message = "Make sure all cards are outlined"
        }
        catch GameStateError.notConfident {
            message = "Make sure all cards are clearly visible"
        }
        catch {
            // ignored
        }
    }
    
    func reset() {
        GameStateUpdater.shared.reset()
        state = nil
        showScore = false
        updateView()
    }
    
    var body: some View {
        ZStack() {
            Color(UIColor(red: 0.98, green: 0.98, blue: 0.95, alpha: 1)).ignoresSafeArea()
            VStack {
                if state != nil {
                    Spacer()
                    Text("Score: \(score)")
                        .foregroundColor(.black)
                        .fontWeight(.bold)
                        .font(.system(size: 20))
                        .padding()
                    GameStateView(state: state!, showScore: $showScore)
                    Spacer()
                    HStack {
                        Button("Toggle Card Scores") {
                            showScore = !showScore
                        }.fontWeight(.bold).padding()
                        Spacer()
                        Button("Restart") {
                            reset()
                        }.fontWeight(.bold).padding()
                    }
                } else {
                    ZStack {
                        CameraView().ignoresSafeArea()
                        VStack {
                            Text(message)
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .shadow(color: .black, radius: 20)
                                .padding()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                .scaleEffect(2)
                                .shadow(color: .black, radius: 20)
                                .padding()
                            Spacer()
                        }
                    }
                }
            }
        }.onReceive(scoreTimer, perform: { _ in
            updateView()
        })
    }
}
