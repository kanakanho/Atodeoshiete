import SwiftUI

struct ContentView: View {
    @AppStorage("reminder.icon") private var icon: String = "🔔"
    @AppStorage("reminder.message") private var message: String = "そろそろやることある?"

    @StateObject private var notificationManager = NotificationManager.shared

    private let iconChoices = ["🔔", "⏰", "📌", "💧", "🍽️", "💊", "🧘", "📚", "🏃", "🧹", "☕️", "🎯"]

    var body: some View {
        NavigationStack {
            Form {
                Section("プレビュー") {
                    HStack(spacing: 12) {
                        Text(icon.isEmpty ? "🔔" : icon)
                            .font(.system(size: 40))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(icon.isEmpty ? "🔔" : icon) あとでおしえて")
                                .font(.headline)
                            Text(message.isEmpty ? "メッセージ未設定" : message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("アイコン") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(iconChoices, id: \.self) { candidate in
                            Button {
                                icon = candidate
                            } label: {
                                Text(candidate)
                                    .font(.system(size: 28))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(icon == candidate ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    TextField("絵文字を直接入力", text: $icon)
                        .onChange(of: icon) { _, newValue in
                            if newValue.count > 2 {
                                icon = String(newValue.suffix(2))
                            }
                        }
                }

                Section("メッセージ") {
                    TextField("通知に表示するメッセージ", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        Task {
                            await notificationManager.requestAuthorizationIfNeeded()
                            guard notificationManager.authorizationStatus == .authorized else { return }
                            notificationManager.scheduleReminder(icon: icon, message: message)
                        }
                    } label: {
                        Label("1分後に通知する", systemImage: "bell.badge")
                    }
                    .disabled(notificationManager.authorizationStatus == .denied)

                    if let fireDate = notificationManager.lastScheduledFireDate {
                        Text("次の通知予定: \(fireDate.formatted(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if notificationManager.authorizationStatus == .denied {
                        Text("通知が許可されていません。設定アプリから通知を許可してください。")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let errorMessage = notificationManager.lastError {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("通知はこの端末内で完結します。サーバーへの送信は行いません。")
                }
            }
            .navigationTitle("あとでおしえて")
            .task {
                await notificationManager.requestAuthorizationIfNeeded()
            }
        }
    }
}

#Preview {
    ContentView()
}
