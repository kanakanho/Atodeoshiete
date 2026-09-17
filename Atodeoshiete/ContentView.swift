import PhotosUI
import SwiftUI

struct ContentView: View {
    @AppStorage("reminder.iconType") private var iconTypeRaw: String = ReminderIconType.emoji.rawValue
    @AppStorage("reminder.icon") private var iconStorage: String = "🔔"
    @AppStorage("reminder.title") private var titleStorage: String = "可憐"
    @AppStorage("reminder.message") private var messageStorage: String = "ねぇいまひま？"
    @AppStorage("reminder.scheduleMode") private var scheduleModeRaw: String = ReminderScheduleMode.afterMinutes.rawValue
    @AppStorage("reminder.minutes") private var minutes: Int = 1
    @AppStorage("reminder.seconds") private var seconds: Int = 0
    @AppStorage("reminder.hour") private var hour: Int = 9
    @AppStorage("reminder.minute") private var minute: Int = 0

    // TextFields bind to these local copies instead of directly to @AppStorage.
    // Writing straight to AppStorage on every keystroke forces a UserDefaults-driven
    // view update mid-keystroke, which clobbers in-progress Japanese IME composition
    // (confirmed text vanishes on henkan-kakutei). Editing local @State first and
    // mirroring it out via onChange keeps IME composition untouched.
    @State private var icon: String = "🔔"
    @State private var title: String = "可憐"
    @State private var message: String = "ねぇいまひま？"

    @StateObject private var notificationManager = NotificationManager.shared

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var photoImage: UIImage?
    @State private var photoLoadError: String?

    private let iconChoices = ["🔔", "⏰", "📌", "💧", "🍽️", "💊", "🧘", "📚", "🏃", "🧹", "☕️", "🎯"]

    private var iconType: Binding<ReminderIconType> {
        Binding(
            get: { ReminderIconType(rawValue: iconTypeRaw) ?? .emoji },
            set: { iconTypeRaw = $0.rawValue }
        )
    }

    private var scheduleMode: Binding<ReminderScheduleMode> {
        Binding(
            get: { ReminderScheduleMode(rawValue: scheduleModeRaw) ?? .afterMinutes },
            set: { scheduleModeRaw = $0.rawValue }
        )
    }

    private var timeOfDay: Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = hour
                components.minute = minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                hour = components.hour ?? 0
                minute = components.minute ?? 0
            }
        )
    }

    private var scheduleButtonLabel: String {
        switch scheduleMode.wrappedValue {
        case .afterMinutes:
            switch (minutes, seconds) {
            case (0, let s):
                return "\(s)秒後に通知する"
            case (let m, 0):
                return "\(m)分後に通知する"
            case (let m, let s):
                return "\(m)分\(s)秒後に通知する"
            }
        case .atTime:
            return String(format: "%02d:%02d に通知する", hour, minute)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("プレビュー") {
                    HStack(spacing: 12) {
                        iconPreview
                            .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title.isEmpty ? "あとでおしえて" : title)
                                .font(.headline)
                            Text(message.isEmpty ? "メッセージ未設定" : message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("アイコン") {
                    Picker("アイコンの種類", selection: iconType) {
                        Text("絵文字").tag(ReminderIconType.emoji)
                        Text("写真").tag(ReminderIconType.photo)
                    }
                    .pickerStyle(.segmented)

                    if iconType.wrappedValue == .emoji {
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
                    } else {
                        HStack(spacing: 16) {
                            if let photoImage {
                                Image(uiImage: photoImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundStyle(.secondary)
                                    }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                                    Label(photoImage == nil ? "写真を選択" : "写真を変更", systemImage: "photo.on.rectangle")
                                }

                                if photoImage != nil {
                                    Button(role: .destructive) {
                                        ReminderIconStore.deletePhoto()
                                        photoImage = nil
                                    } label: {
                                        Text("写真を削除")
                                    }
                                }
                            }
                        }

                        if let photoLoadError {
                            Text(photoLoadError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section("タイトル") {
                    TextField("通知のタイトル", text: $title)
                }

                Section("メッセージ") {
                    TextField("通知に表示するメッセージ", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("通知タイミング") {
                    Picker("タイミング", selection: scheduleMode) {
                        Text("分後").tag(ReminderScheduleMode.afterMinutes)
                        Text("時刻指定").tag(ReminderScheduleMode.atTime)
                    }
                    .pickerStyle(.segmented)

                    if scheduleMode.wrappedValue == .afterMinutes {
                        HStack(spacing: 0) {
                            Picker("分", selection: $minutes) {
                                ForEach(0...180, id: \.self) { value in
                                    Text("\(value)分").tag(value)
                                }
                            }
                            .pickerStyle(.wheel)

                            Picker("秒", selection: $seconds) {
                                ForEach(0..<60, id: \.self) { value in
                                    Text("\(value)秒").tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                        .frame(height: 120)
                    } else {
                        DatePicker("時刻", selection: timeOfDay, displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    Button {
                        Task {
                            await notificationManager.requestAuthorizationIfNeeded()
                            guard notificationManager.authorizationStatus == .authorized else { return }
                            notificationManager.scheduleReminder(
                                title: title,
                                body: message,
                                iconType: iconType.wrappedValue,
                                emoji: icon,
                                mode: scheduleMode.wrappedValue,
                                minutesFromNow: minutes,
                                secondsFromNow: seconds,
                                hour: hour,
                                minute: minute
                            )
                        }
                    } label: {
                        Label(scheduleButtonLabel, systemImage: "bell.badge")
                    }
                    .disabled(notificationManager.authorizationStatus == .denied)

                    if let fireDate = notificationManager.lastScheduledFireDate {
                        Text("次の通知予定: \(fireDate.formatted(date: .abbreviated, time: .standard))")
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
                photoImage = ReminderIconStore.loadPhoto()
                icon = iconStorage
                title = titleStorage
                message = messageStorage
            }
            .onChange(of: icon) { _, newValue in
                if newValue.count > 2 {
                    icon = String(newValue.suffix(2))
                    return
                }
                iconStorage = newValue
            }
            .onChange(of: title) { _, newValue in
                titleStorage = newValue
            }
            .onChange(of: message) { _, newValue in
                messageStorage = newValue
            }
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    do {
                        guard let data = try await newItem.loadTransferable(type: Data.self),
                              let uiImage = UIImage(data: data) else {
                            await MainActor.run { photoLoadError = "画像を読み込めませんでした" }
                            return
                        }
                        try ReminderIconStore.savePhoto(uiImage)
                        await MainActor.run {
                            photoImage = uiImage
                            photoLoadError = nil
                        }
                    } catch {
                        await MainActor.run { photoLoadError = error.localizedDescription }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var iconPreview: some View {
        if iconType.wrappedValue == .photo, let photoImage {
            Image(uiImage: photoImage)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Text(icon.isEmpty ? "🔔" : icon)
                .font(.system(size: 36))
        }
    }
}

#Preview {
    ContentView()
}
