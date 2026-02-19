# Garnet Studio

<div align="center">
  <img src="https://raw.githubusercontent.com/athxrvx/Garnet-Studio/refs/heads/main/assets/previews/Screenshot%202026-02-19%20105240.png" alt="Dashboard" width="800"/>
</div>

<br>

**Garnet Studio** is a comprehensive, privacy-first AI workspace built around [Ollama](https://ollama.com/).

What originally started as a simple desktop wrapper to interact with Ollama more comfortably has evolved into a full-featured local ecosystem. It combines powerful **local research capabilities** with a **secure device gateway**. The goal is straightforward: run models locally, keep your data strictly on your machine, and seamlessly access your setup from other devices on your local network without ever exposing it to the internet.

---

## 🚀 Key Features

### 🧠 AI Research Engine & Multi-Tool Chat
Create distinct projects, upload documents, and chat with your local models seamlessly.

<p align="center">
  <img src="https://raw.githubusercontent.com/athxrvx/Garnet-Studio/refs/heads/main/assets/previews/Screenshot%202026-02-19%20105450.png" width="32%" />
  <img src="https://raw.githubusercontent.com/athxrvx/Garnet-Studio/refs/heads/main/assets/previews/Screenshot%202026-02-19%20105851.png" width="32%" />
  <img src="https://raw.githubusercontent.com/athxrvx/Garnet-Studio/refs/heads/main/assets/previews/Screenshot%202026-02-19%20105621.png" width="32%" />
</p>

* **Workspace Management**: Isolate your research topics into dedicated workspaces.
* **Multi-Modal Ingestion**: Drag-and-drop PDFs, text files, Markdown, code, or web links. 
* **Context-Aware RAG**: Local indexing and chunking ensure the AI answers using *only* the context from your uploaded files, citing sources automatically.
* **Dynamic Chat Tools**: Toggle between standard Web chat, your Knowledge Base, and Deep Research modes.
* **Privacy-First**: Embeddings are stored in a local SQLite database. Nothing leaves your machine.

---

### ⚙️ Local Model Management
Manage your entire local LLM inventory visually without touching the command line.

<p align="center">
  <img src="https://raw.githubusercontent.com/athxrvx/Garnet-Studio/refs/heads/main/assets/previews/Screenshot%202026-02-19%20105411.png" width="48%" />
  <img src="https://raw.githubusercontent.com/athxrvx/Garnet-Studio/refs/heads/main/assets/previews/Screenshot%202026-02-19%20105426.png" width="48%" />
</p>

* **Inventory Control**: View installed models, track their memory footprint, and activate them with a click.
* **Granular Configuration**: Easily tweak Generation Parameters (Temperature, Top P), adjust context window sizes, and set custom System Prompts per model.

---

### 🔒 Secure Device Gateway
Use your powerful desktop GPU from your phone or tablet safely.

<p align="center">
  <img src="https://raw.githubusercontent.com/athxrvx/Garnet-Studio/refs/heads/main/assets/previews/Screenshot%202026-02-19%20105257.png" width="48%" />
  <img src="https://raw.githubusercontent.com/athxrvx/Garnet-Studio/refs/heads/main/assets/previews/Screenshot%202026-02-19%20105336.png" width="48%" />
</p>

* **End-to-End Encryption**: Devices pair securely using a custom RSA/AES handshake protocol.
* **Zero-Config Discovery**: Automatically find Garnet Studio on your Wi-Fi using mDNS (`_garnet._tcp`).
* **Local Proxy Server**: Built-in Dart `shelf` server (Port 8787) acts as a secure proxy to Ollama.
* **Access Control**: Authorize, view, and revoke connected devices directly from the desktop manager.

---

### 📊 System Monitoring & Settings
Keep an eye on your hardware and customize your app experience.

<p align="center">
  <img src="https://raw.githubusercontent.com/athxrvx/Garnet-Studio/refs/heads/main/assets/previews/Screenshot%202026-02-19%20105645.png" width="71%" />
  <img src="https://raw.githubusercontent.com/athxrvx/Garnet-Studio/refs/heads/main/assets/previews/Screenshot%202026-02-19%20105224.png" width="25%" />
</p>

* **Real-time Metrics**: Track CPU, RAM, and VRAM usage, alongside live network traffic and system logs.
* **App Customization**: Deep dark mode UI, auto-start gateway preferences, and user profile management.
* **Desktop Integrated**: Custom window controls and system tray integration.

---

## 🛠️ Tech Stack

* **Framework**: Flutter (Dart 3) & Riverpod `^2.5.1`
* **AI/LLM**: Ollama Integration
* **Database**: SQFlite (SQLite) with FFI for Desktop
* **Backend**: `shelf`, `shelf_router`, `shelf_web_socket`
* **Networking**: `nsd` (Service Discovery), `http`, `web_socket_channel`
* **Security**: `encrypt` (AES/RSA), `crypto`

---

## 📦 Installation

### Prerequisites
1.  **Ollama**: Install [Ollama](https://ollama.com/) and ensure it is running (`ollama serve`).
    * *Tip: Pull your first model using `ollama pull llama3` or `ollama pull gemma`.*
2.  **Flutter SDK**: Version 3.10.0 or higher.
3.  **Visual Studio** (Windows): Required for compiling C++ desktop runners.

### Setup

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/athxrvx/Garnet-Studio.git](https://github.com/athxrvx/Garnet-Studio.git)
    cd Garnet-Studio
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the application (Windows):**
    ```bash
    flutter run -d windows
    ```

---

## 🤝 Contributing

This is a hobby project! I’m actively learning the networking and security concepts involved, so there may be rough edges or bugs. Contributions are highly welcome:

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

*Areas for improvement: Bug fixes, refactoring, security/performance enhancements, and UI polish.*

---

## 🏆 Credits

This project was inspired by and built alongside ideas from incredible tools in the open-source AI community:
* [Ollama](https://ollama.com/)
* [LM Studio](https://lmstudio.ai/)
* PocketLLM
* Ollaman
* [Msty](https://msty.app/)

These projects helped shape the local-first AI ecosystem and heavily influenced the direction of Garnet Studio.

---

## 📄 License & Disclaimer

**License**: Distributed under the MIT License. See `LICENSE` for more information.

**Disclaimer**: This project has not been professionally audited. While it uses standard encryption primitives, it should *not* be treated as production-grade security software. Use it with that understanding.
