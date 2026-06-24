import SwiftUI
import UniformTypeIdentifiers

struct MeshView: View {
    @ObservedObject var mesh: TetherMesh
    @State private var draft = ""
    @State private var showFilePicker = false

    private let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    private let cardBg = Color(red: 0.067, green: 0.067, blue: 0.075)
    private let dark = Color(red: 0.04, green: 0.04, blue: 0.047)

    var body: some View {
        VStack(spacing: 0) {
            meshHeader
            transferBar
            messageList
            inputBar
        }
        .background(dark.ignoresSafeArea())
        .onAppear { mesh.start() }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tmp)
                try? FileManager.default.copyItem(at: url, to: tmp)
                mesh.sendFile(at: tmp)
            }
        }
    }

    var meshHeader: some View {
        VStack(spacing: 4) {
            Text("MESH")
                .font(.system(size: 11, weight: .medium))
                .kerning(4)
                .foregroundColor(gold)
            Text(mesh.peerCount == 0 ? "Searching..." : "\(mesh.peerCount) Connected")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white)
            if mesh.peerCount > 0 {
                Text(mesh.connectedPeers.map { $0.displayName }.joined(separator: " / "))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    var transferBar: some View {
        if !mesh.transferProgress.isEmpty {
            VStack(spacing: 6) {
                ForEach(Array(mesh.transferProgress.keys.sorted()), id: \.self) { name in
                    if let pct = mesh.transferProgress[name] {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 10))
                                .foregroundColor(gold)
                            Text(name)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(pct * 100))%")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(gold)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.white.opacity(0.06))
                                Rectangle().fill(gold).frame(width: geo.size.width * CGFloat(pct))
                            }
                        }
                        .frame(height: 3)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(cardBg)
        }
    }

    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(mesh.messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: mesh.messages.count) { _ in
                if let last = mesh.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    func messageBubble(_ msg: MeshMessage) -> some View {
        Group {
            if msg.isSystem {
                systemMessage(msg)
            } else {
                chatBubble(msg)
            }
        }
    }

    func systemMessage(_ msg: MeshMessage) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
            Text("\(msg.sender) \(msg.body)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .fixedSize()
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    func chatBubble(_ msg: MeshMessage) -> some View {
        let isMe = msg.sender == mesh.displayName
        return HStack {
            if isMe { Spacer(minLength: 60) }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                if !isMe {
                    Text(msg.sender)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(gold)
                }
                if msg.isFile {
                    fileLabel(msg)
                } else {
                    Text(msg.body)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                Text(timeString(msg.timestamp))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isMe ? gold.opacity(0.15) : cardBg)
            .overlay(
                Rectangle()
                    .stroke(isMe ? gold.opacity(0.2) : Color.white.opacity(0.06), lineWidth: 1)
            )
            if !isMe { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }

    func fileLabel(_ msg: MeshMessage) -> some View {
        HStack(spacing: 8) {
            Image(systemName: msg.kind == .fileReceived ? "arrow.down.doc" : "arrow.up.doc")
                .font(.system(size: 14))
                .foregroundColor(gold)
            Text(msg.body)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }

    var inputBar: some View {
        HStack(spacing: 0) {
            Button(action: { showFilePicker = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(gold)
                    .frame(width: 44, height: 44)
            }
            TextField("Message", text: $draft)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .accentColor(gold)
                .padding(.vertical, 10)
                .submitLabel(.send)
                .onSubmit { sendDraft() }
            Button(action: sendDraft) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(draft.isEmpty ? .secondary : .black)
                    .frame(width: 30, height: 30)
                    .background(draft.isEmpty ? Color.clear : gold)
            }
            .disabled(draft.isEmpty)
            .padding(.trailing, 8)
        }
        .background(cardBg)
        .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .top)
        .padding(.bottom, 4)
    }

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        mesh.send(text)
        draft = ""
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
