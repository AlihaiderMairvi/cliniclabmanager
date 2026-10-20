# 🧬 Clinic Lab Manager

A comprehensive, offline-first desktop application built with **Flutter** for diagnostic labs, clinics, and pathology centers. 

Designed to replace manual paper registers and MS Word templates, this app provides a fast, reliable, and professional way to manage patients, generate lab reports, and handle billing—all without needing an internet connection.

## ✨ Key Features

*   **👥 Patient Management:** Register patients, track their visit history, and store contact details.
*   **📅 Multi-Test Visits:** Group multiple tests under a single visit with a unique PIN (e.g., `2610-000001`).
*   **🧪 Reusable Test Panels:** Create templates like "CBC" or "LFT" once, and instantly auto-fill test names, units, and reference ranges for future patients.
*   **📄 Professional PDF Reports:** Generate clean, print-ready A4 reports designed to align with pre-printed clinic letterheads.
*   **💰 Invoicing & Billing:** Automatically calculate totals, apply discounts, track payment modes (Cash, Card, Easypaisa, JazzCash), and generate receipts.
*   **💾 Local Database & Backups:** Uses SQLite for 100% offline data storage. Includes a built-in backup and restore system to keep patient data safe.
*   **🎨 Modern UI/UX:** Built with Material 3, featuring a clean medical aesthetic, responsive layouts, and smooth animations.

## 🛠️ Tech Stack

*   **Framework:** [Flutter](https://flutter.dev/) (Desktop/Windows)
*   **Language:** [Dart](https://dart.dev/)
*   **Database:** [SQLite](https://www.sqlite.org/) (via `sqflite_common_ffi` for Windows)
*   **PDF Generation:** `pdf` & `printing` packages
*   **Architecture:** Offline-first, Singleton Database Service, Stateful Widgets.

## 🚀 How to Run Locally

### Prerequisites
*   Flutter SDK (3.27.0 or higher recommended)
*   Visual Studio 2022 (with "Desktop development with C++" workload installed)
*   Windows 10 or 11 (64-bit)

### Installation Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/clinic-lab-manager.git
