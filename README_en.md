# Windows Advanced Power & Productivity Hotkeys (AutoHotkey v2)

This is a feature-rich, system-enhancing AutoHotkey v2 script designed for **gaming/office performance control, system management, and window behavior optimization**. With just a few keyboard shortcuts, you can easily control CPU power policies, GPU power limits/clocks, system power-saving modes, and daily window management.

## 🌟 Core Features

*   🚀 **CPU Performance & Power Plan Hotkeys:** Quick controls for Processor Boost Mode, SMT (Simultaneous Multithreading), Core Parking, and Maximum Processor Frequency.
*   🔋 **One-Click Power Plan Switch:** Seamlessly switch between Balanced, Power Saver, and Custom/High-Performance modes (like Hydra).
*   🎮 **NVIDIA GPU Power/Clock Lock:** Toggle `nvidia-smi` limits to quickly restrict memory/core clocks for lower thermals, or uncap them for maximum gaming performance.
*   🖥️ **Quick Window & Taskbar Management:** Includes native Windows 11 style window minimization with a history stack to restore them, minimize-to-tray capability (requires 3rd-party tools), and quick taskbar hiding.
*   🛡️ **Desktop Protection:** Intercepts `Ctrl + Mouse Wheel` while hovering over the Windows Desktop to prevent accidental icon resizing.
*   ⚡ **AMD ZenStates Support:** Toggle deep CPU C6 Sleep States with single/double clicks (relies on included local script libs).

## ⌨️ Shortcut Guide

### System & Power Adjustments
*(Note: Most power and CPU adjustments require running the script as Administrator)*

*   **`Ctrl + Alt + Numpad1`**:
    *   **Single Click:** Switch to the **Balanced** Power Plan.
    *   **Double Click:** Switch to the **Hydra** (High Performance) Power Plan.
*   **`Ctrl + Alt + Numpad6`**: Switch to the **Power Saver** Power Plan.
*   **`Ctrl + Alt + Numpad0`**: Combined SMT & Core Parking toggle.
    *   **Single Click:** SMT Disabled (`0`), Core Parking set to `50%`.
    *   **Double Click:** SMT Enabled (`2`), Core Parking set to `25%`.
*   **`Ctrl + Alt + Numpad2`**: PCIe Link State Power Management.
    *   **Single Click:** Turn off all PCIe power savings (`0`).
    *   **Double Click:** Enable Maximum PCIe power savings (`2`).
*   **`Ctrl + Alt + Numpad3`**: Toggle AMD ZenStates **C6 Sleep State**.
    *   **Single Click:** Enable C6 State (Calls `ZenStates_C6_Enable.ahk`).
    *   **Double Click:** Disable C6 State (Calls `ZenStates_C6_Disabled.ahk`).
*   **`Ctrl + Alt + Numpad4`**: **Set Max CPU Frequency**. A popup UI prompts you to enter the max frequency in MHz (Enter `0` for default unconstrained frequency).
*   **`Ctrl + Alt + Numpad5`**: Processor Boost Mode.
    *   **Single Click:** Disable Boost (`0`).
    *   **Double Click:** Enable Aggressive Boost (`2`).

### NVIDIA GPU Management
*(Requires an NVIDIA GPU and `nvidia-smi.exe` in PATH)*

*   **`Ctrl + Alt + Numpad7`**: Enable GPU Power Saving / Frequency Caps.
    *   Lock Memory Clock (LMC): 400 - 5002 MHz
    *   Lock Graphics Clock (LGC): Max 2100 MHz
    *   Power Limit (PL): Script set to `250` (or `150W` visual cap).
*   **`Ctrl + Alt + Numpad9`**: Uncap Performance. Removes LMC/RGC frequency limits and restores Power Limit to 325W.

### Windows, Tray & Convenience Controls
*(Some features require companion third-party tools)*

*   **`Ctrl + Esc`**: Sends `Win+Ctrl+F11`. Best used with `buttery-taskbar.exe` to instantly hide/show the Windows taskbar.
*   **`Shift + ~` (Tilde)**: Minimize the current active window (and pushes its ID to a history stack).
*   **`Shift + Q`**: Restore the last minimized window from the history stack.
*   **`Alt + ~` (Tilde)**: Minimize window to **System Tray** (Requires `RBTray.exe` via `Ctrl+Alt+Down`).
*   **`Alt + Q`**: Restore window from System Tray (Requires `RBTray.exe` via `Ctrl+Alt+Up`).
*   **`Alt + F`**: Remapped to `F11` (Fullscreen) **ONLY** when the active window is NOT `scrcpy` (Android screen mirroring).

### Desktop Icon Resize Block
*   When your mouse is hovering over the Windows Desktop background, pressing **`Ctrl + Mouse Wheel Up/Down`** will be intercepted natively. This prevents annoying accidental icon resizing, while leaving `Ctrl + Scroll` intact in browsers and code editors.
