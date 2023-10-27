//
//  ContentView.swift
//  affirmative
//
//  Created by Rory Fahy on 10/25/23.
//

import SwiftUI

struct ContentView: View {
    @State private var userInput: String = "What is troubling you at the moment?"
    @ObservedObject var viewModel = TextToSpeechViewModel()
    
    var body: some View {
        VStack {
            TextField("Enter text", text: $userInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Submit") {
                viewModel.fetchAndSubmitAffirmations(input: userInput)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
