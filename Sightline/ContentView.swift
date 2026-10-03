//
//  ContentView.swift
//  Sightline
//
//  Created by Bryan on 10/3/26.
//

import SwiftUI

struct ContentView: View {
    @State private var walkingStatus = "Idle"
    var body: some View {
        VStack {
            Text("Sightline")
            Text(walkingStatus)
            Button("Start Walking Mode") {
                walkingStatus = "Walking mode active"
            }
            Button("Stop") {
                walkingStatus = "Idle"
            }


        }
        .padding()
    }
}

#Preview {
    ContentView()
}
