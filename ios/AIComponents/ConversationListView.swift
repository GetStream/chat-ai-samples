//
//  ConversationListView.swift
//  AIComponents
//
//  Created by Martin Mitrevski on 21.11.25.
//

import SwiftUI
import StreamChat
import StreamChatAI
import StreamChatSwiftUI

struct ConversationListView: View {
    
    @StateObject private var viewModel = ChatChannelListViewModel()
    var onChannelSelected: (ChatChannel) -> Void
    var onNewChat: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack {
                HStack {
                    Text("Conversations")
                        .font(.headline)
                    
                    Spacer()

                    Button(action: onNewChat) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                    }
                    .accessibilityLabel("New chat")
                    .buttonStyle(.plain)
                }
                .padding()

                ForEach(viewModel.channels) { channel in
                    HStack {
                        Text(channel.name ?? channel.id)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onChannelSelected(channel)
                    }
                    .onAppear {
                        if let index = viewModel.channels.firstIndex(of: channel) {
                            viewModel.checkForChannels(index: index)
                        }
                    }
                }
            }
        }
        .padding(.top, 40)
    }
}
