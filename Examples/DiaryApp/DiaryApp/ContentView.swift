//
//  ContentView.swift
//  DiaryApp
//
//  Created by Den Ree on 20/05/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
      DiaryListView(DiaryContext())
    }
}

#Preview {
    ContentView()
}
