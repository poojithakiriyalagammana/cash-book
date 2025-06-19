# 💰 Cash‑Book

A Flutter application to manage your daily income and expenses using an offline **SQLite database**. Easily track your cash-in and cash-out with categorized entries.

---

## 🚀 Getting Started

Follow these steps to set up and run the project locally.

### 📦 1. Clone the Repository

```bash
git clone https://github.com/poojithakiriyalagammana/cash-book.git
cd cash-book
```

### ⚙️ 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 📱 3. Run the App

Make sure your device/emulator is connected, then run:

```bash
flutter run
```

---

## 🧩 Features

- ✅ Add, edit, and delete **Cash-In** and **Cash-Out** entries
- ✅ Assign categories/types for income and expenses
- ✅ View total balance and transactions
- ✅ Local database with **SQLite (sqflite)** – works offline
- ✅ Custom notifications (before and on due dates)
- ✅ Financial month support (custom salary date logic)

---

## 🗃️ Local Database

This app uses the [`sqflite`](https://pub.dev/packages/sqflite) plugin to store data offline using SQLite.

You don’t need any manual setup — just run the app and the database is created automatically.

---

## 🎨 Customize

### Change App Icon

1. Add this to your `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
```

2. Run:
```bash
flutter pub run flutter_launcher_icons:main
```

### Change App Name

- **Android**:  
  Edit `android/app/src/main/AndroidManifest.xml`  
  Change:
  ```xml
  android:label="Cash Book"
  ```

- **iOS**:  
  Edit `ios/Runner/Info.plist`  
  Update:
  ```xml
  <key>CFBundleDisplayName</key>
  <string>Cash Book</string>
  ```

---

## 📂 Folder Structure (Simplified)

```
lib/
├── db/                  # Database helper and models
├── screens/             # All UI screens
├── widgets/             # Reusable components
├── utils/               # Utility functions
├── main.dart            # Entry point
```

---

## 📄 Requirements

- Flutter SDK (>=3.0.0)
- Android Studio or VS Code (with Flutter extension)
- Connected device/emulator
- No internet needed — works offline with SQLite

---

## 🔧 Built With

- [Flutter](https://flutter.dev/)
- [sqflite](https://pub.dev/packages/sqflite)
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)

---


## 🤝 Contributing

Pull requests are welcome. For major changes, open an issue first to discuss what you would like to change.

---
