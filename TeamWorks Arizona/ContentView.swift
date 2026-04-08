//
//  ContentView.swift
//  TeamWorks Arizona
//
//  Created by Jason Cantor on 1/21/26.
//

import SwiftUI

struct TeamworksWebView: UIViewControllerRepresentable {
    let urlString: String

    func makeUIViewController(context: Context) -> TeamworksWebViewController {
        return TeamworksWebViewController(url: urlString)
    }

    func updateUIViewController(_ uiViewController: TeamworksWebViewController, context: Context) {
        // No updates needed - URL is fixed
    }
}

struct ContentView: View {
    var body: some View {
        TeamworksWebView(urlString: "https://displays.tw")
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
