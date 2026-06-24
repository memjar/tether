import SwiftUI
import UniformTypeIdentifiers

struct MeshView: View {
    @ObservedObject var mesh: TetherMesh
    @State private var draft = ""
    @State private var showFilePicker = false

    private static let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    private static let cardBg = Color(red: 0.067, green: 0.067, blue: 0.075)
    private static let dark = Color(red: 0.04, green: 0.04, blue: 0.047)
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            meshHeader
            transferBar
            messageList
            inputBar
        }
        .background(Self.dark.ignoresSafeArea())
        .onAppear { mesh.start() }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: tmp)
            try? FileManager.default.copyItem(at: url, to: tmp)
            mesh.sendFile(at: tmp)
        }
    }

    private var meshHeader: some View {
        VStack(spacing: 4) {
            Text("MESH")
                .font(.system(size: 11, weight: .medium))
                .kerning(4)
                .foregroundColor(Self.gold)
            Text(mesh.peerCount == 0 ? "Searching..." : "\(mesh.peerCount) Connected")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white)
            if mesh.peerCount > 0 {
                Text(mesh.connectedPeers.map(\.displayName).joined(separator: " / "))
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
    private var transferBar: some View {
        if !mesh.transferProgress.isEmpty {
            VStack(spacing: 6) {
                ForEach(Array(mesh.transferProgress.keys.sorted()), id: \.self) { key in
                    if let pct = mesh.transferProgress[key] {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 10))
                                .foregroundColor(Self.gold)
                            Text(key)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(pct * 100))%")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Self.gold)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.white.opacity(0.06))
                                Rectangle().fill(Self.gold).frame(width: geo.size.width * pct)
                            }
                        }
                        .frame(height: 3)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Self.cardBg)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(mesh.messages) { msg in
                        messageBubble(msg).id(msg.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: mesh.messages.count) { _ in
                guard let last = mesh.messages.last else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ msg: MeshMessage) -> some View {
        if msg.isSystem {
            systemRow(msg)
        } else {
            chatRow(msg)
        }
    }

    private func systemRow(_ msg: MeshMessage) -> some View {
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

    private func chatRow(_ msg: MeshMessage) -> some View {
        let isMe = msg.sender == mesh.displayName
        return HStack {
            if isMe { Spacer(minLength: 60) }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                if !isMe {
                    Text(msg.sender)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Self.gold)
                }
                if msg.isFile {
                    fileRow(msg)
                } else {
                    Text(msg.body)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                Text(Self.timeFmt.string(from: msg.timestamp))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isMe ? Self.gold.opacity(0.15) : Self.cardBg)
            .overlay(Rectangle().stroke(isMe ? Self.gold.opacity(0.2) : Color.white.opacity(0.06), lineWidth: 1))
            if !isMe { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }

    private func fileRow(_ msg: MeshMessage) -> some View {
        HStack(spacing: 8) {
            Image(systemName: msg.kind == .fileReceived ? "arrow.down.doc" : "arrow.up.doc")
                .font(.system(size: 14))
                .foregroundColor(Self.gold)
            Text(msg.body)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 0) {
            Button { showFilePicker = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Self.gold)
                    .frame(width: 44, height: 44)
            }
            TextField("Message", text: $draft)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .accentColor(Self.gold)
                .padding(.vertical, 10)
                .submitLabel(.send)
                .onSubmit(sendDraft)
            Button(action: sendDraft) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(draft.isEmpty ? .secondary : .black)
                    .frame(width: 30, height: 30)
                    .background(draft.isEmpty ? Color.clear : Self.gold)
            }
            .disabled(draft.isEmpty)
            .padding(.trailing, 8)
        }
        .background(Self.cardBg)
        .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .top)
        .padding(.bottom, 4)
    }

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        mesh.send(text)
        draft = ""
    }
}
