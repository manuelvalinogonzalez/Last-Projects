# SplitWithMe 💸

A comprehensive multi-platform application to manage and split shared expenses between friends. This project demonstrates the same solution implemented through different technological stacks.

## 🛠️ Tech Stack & Implementations
The project is divided into three main platforms:

* **Android (Mobile)**: Developed with **Flutter & Dart** for a robust mobile experience.
* **Desktop**: Built using **Python (FastAPI)**, handling both the backend logic and the desktop interface.
* **Web**: A lightweight version created with **HTML5, CSS3, and JavaScript**.

## 📂 Project Structure
* **`/backend`**: Core logic, database management, and Desktop application implementation.
* **`/mobile`**: Flutter source code specifically optimized for Android.
* **`/web`**: Web implementation files (HTML, CSS, and JS).

## 🚀 How to Run & Preview

### 📱 Android
* **Option A**: Open the `/mobile` folder using **Android Studio** to inspect the code and run it in an emulator.
* **Option B**: Install the generated APK on an **Android device**.
* *Requirements*: Flutter SDK installed.

### 💻 Desktop (Backend)
> [!IMPORTANT]
> To ensure data persistence, the database must be active and accessible by the backend.

To start the server and the application logic, run the following commands in your terminal:

```bash
cd backend
fastapi run