#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Force

; -------------------------------
;          全局常量定义
; -------------------------------
; ⚙️ NVIDIA 显卡配置 - 以后只要在这里改数值, Tooltip 会自动同步更新
global NVIDIA_LIMIT := {
    MEM_MIN:    400,    ; 显存最低 MHz
    MEM_MAX:   5002,    ; 显存最高 MHz
    POWER_LIM:  250,    ; 功耗限制 W
    CORE_MIN:   200,    ; 核心最低 MHz
    CORE_MAX:  2100     ; 核心最高 MHz
}

global NVIDIA_UNLIMIT := {
    POWER_LIM:  325     ; 解锁后的功耗上限 W
}

global MINIMIZED_WINDOWS := []  ; 使用数组存储最小化窗口历史
global POWER_PLANS := [
    "381b4222-f694-41f0-9685-ff5bb260df2e",  ; Balanced (Index 1)
    "a1841308-3541-4fab-bc81-f71556f20b4a",  ; Power Saver (Index 2)
    "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c",  ; High Performance (Index 3)
    "8934982e-5f1a-405e-9a9f-94423e118b7f"   ; Hydra (Index 4)
]

global POWER_SETTINGS := Map(
    "Smt", {
        subgroup: "54533251-82be-4824-96c1-47b60b740d00",
        setting:  "b28a6829-c5f7-444e-8f61-10e24e85c532"
    },
    "PowerSaving", {
        subgroup: "501a4d13-42af-4429-9fd1-a8218c268e20",
        setting:  "ee12f906-d277-404b-b6da-e5fa1a576df5"
    },
    "CoreParking", {
        subgroup: "54533251-82be-4824-96c1-47b60b740d00",
        setting:  "0cc5b647-c1df-4637-891a-dec35c318583"      
    },
    "BoostMode", {  
        subgroup: "54533251-82be-4824-96c1-47b60b740d00",
        setting:  "be337238-0d82-4146-a960-4f3749d470c7"
    },
    "MaxFrequency", {
        subgroup: "54533251-82be-4824-96c1-47b60b740d00",
        setting:  "75b0ae3f-bce0-45a7-8c89-c9611c25e100"
    } 
)

global HAPP_MONITOR := {
    mainProcess: "happ.exe",
    checkIntervalMs: 360000,
    residualPaths: Map(
        "updater.exe", "C:\同花顺远航版\bin\UpdateWorking\updater.exe",
        "hxdaemonprocess.exe", "C:\同花顺远航版\bin\hxdaemonprocess\hxdaemonprocess.exe"
    )
}

; ==================================================
;           🔄 通用双击检测管理器
;  干掉所有重复代码, 所有功能统一使用这一个管理器
; ==================================================
class DoubleClickManager {
    static states := Map()
    static defaultInterval := 300

    static Handle(id, singleAction, doubleAction, interval := 0) {
        interval := interval ? interval : DoubleClickManager.defaultInterval
        
        if (!this.states.Has(id)) {
            this.states[id] := Map("last", 0, "count", 0)
        }
        state := this.states[id]
        now := A_TickCount

        if (now - state["last"] < interval) {
            state["count"]++
            if (state["count"] >= 2) {
                state["count"] := 0
                doubleAction.Call()
                return
            }
        } else {
            state["count"] := 1
        }
        state["last"] := now

        if (state["count"] = 1) {
            fn := ObjBindMethod(this, "CheckSingle", id, singleAction)
            SetTimer(fn, -interval)
        }
    }

    static CheckSingle(id, action) {
        state := this.states[id]
        if (state["count"] = 1) {
            state["count"] := 0
            action.Call()
        }
    }
}

InitializeHappResidualMonitor()

; -------------------------------
;          热键绑定
; -------------------------------
^Esc:: SendInput("^#{F11}")  ; Ctrl+Esc -> Win+Ctrl+F11  ,需要配合 buttery-taskbar.exe 隐藏任务栏
+`::   MinimizeActiveWindow()  ; shift+` -> 最小化当前窗口 ,win11系统自带的最小化窗口
+Q::   RestoreMinimizedWindow() ; shift+Q -> 恢复窗口,win11系统自带的恢复窗口

!`::   SendInput("^!{Down}") ; Alt+` -> 最小化到托盘 (需要配合 RBTray.exe)
!Q::   SendInput("^!{Up}")   ; Alt+Q -> 从托盘恢复窗口 (需要配合 RBTray.exe)


; ^+`:: SendInput("^+<")  ; Ctrl+Shift+` -> 替代 Ctrl+Shift+,edge侧边栏


^!Numpad7:: {  ; NVIDIA显卡: 设置功耗与频率限制
    RunWait("nvidia-smi -lmc " NVIDIA_LIMIT.MEM_MIN "," NVIDIA_LIMIT.MEM_MAX, , "Hide")
    RunWait("nvidia-smi -pl " NVIDIA_LIMIT.POWER_LIM, , "Hide")
    RunWait("nvidia-smi -lgc " NVIDIA_LIMIT.CORE_MIN "," NVIDIA_LIMIT.CORE_MAX, , "Hide")
    ShowToolTip("lmc Cap Set: " NVIDIA_LIMIT.MEM_MIN " MHz - " NVIDIA_LIMIT.MEM_MAX " MHz`nPower Limit Set: " NVIDIA_LIMIT.POWER_LIM "W`nMax Clock Set: " NVIDIA_LIMIT.CORE_MAX " MHz")
}

^!Numpad9:: {  ; 移除GPU频率限制,需要配合 nvidia 卡 使用
    RunWait("nvidia-smi -rmc", , "Hide")
    RunWait("nvidia-smi -rgc", , "Hide")
    RunWait("nvidia-smi -pl " NVIDIA_UNLIMIT.POWER_LIM, , "Hide")
    ShowToolTip("lmc rgc pl Cap Removed`nPower Limit Set: " NVIDIA_UNLIMIT.POWER_LIM "W")
}

^!Numpad6:: {  ; Power Saver
    RunWait("powercfg /setactive " POWER_PLANS[2], , "Hide")
    ShowToolTip("已切换到 Power Saver 电源策略。")
}

; Ctrl+Alt+Numpad0 同时控制 SMT超线程 + 核心停放
;   ✅ 单击:  SMT=关闭 / 核心停放最低 100% (全核心工作)
;   ✅ 双击:  SMT=打开 / 核心停放最低 50% (节能模式)
^!Numpad0:: DoubleClickManager.Handle("Combined", 
    (*) => ( UpdateSystemSettings("Smt", 0), UpdateSystemSettings("CoreParking", 100) ),
    (*) => ( UpdateSystemSettings("Smt", 2), UpdateSystemSettings("CoreParking", 50) )
)

; Ctrl+Alt+Numpad2 PCIe 电源管理
;   ✅ 单击:  最大PCIe节电模式 (最长续航)
;   ✅ 双击:  关闭所有PCIe节电 (最低延迟)
^!Numpad2:: DoubleClickManager.Handle("PowerSaving", 
    (*) => UpdateSystemSettings("PowerSaving", 2),
    (*) => UpdateSystemSettings("PowerSaving", 0)
)

; Ctrl+Alt+Numpad3 AMD C6 休眠状态切换
;   ✅ 单击:  启用 C6 休眠 (低功耗)
;   ✅ 双击:  禁用 C6 休眠 (低延迟 / 游戏模式)
^!Numpad3:: DoubleClickManager.Handle("ZenStates", 
    (*) => ( Run(A_ScriptDir "\lib\ZenStates_C6_Enable.ahk"), ShowToolTip("C6状态已启用") ),
    (*) => ( Run(A_ScriptDir "\lib\ZenStates_C6_Disabled.ahk"), ShowToolTip("C6状态已禁用") )
)

; Ctrl+Alt+Numpad5 处理器加速模式
;   ✅ 单击:  激进 Boost 模式 (最高性能)
;   ✅ 双击:  关闭 Boost (固定频率)
^!Numpad5:: DoubleClickManager.Handle("BoostMode", 
    (*) => UpdateSystemSettings("BoostMode", 2),
    (*) => UpdateSystemSettings("BoostMode", 0)
)

; Ctrl+Alt+Numpad4 处理器最大频率
^!Numpad4:: SetMaxFrequency()

; Ctrl+Alt+Numpad1 电源计划快速切换
;   ✅ 单击:  平衡模式 (Balanced)
;   ✅ 双击:  Hydra 自定义性能模式
^!Numpad1:: DoubleClickManager.Handle("PowerPlan", 
    (*) => ( RunWait("powercfg /setactive " POWER_PLANS[1], , "Hide"), ShowToolTip("已切换到 Balanced 电源策略。") ),
    (*) => ( RunWait("powercfg /setactive " POWER_PLANS[4], , "Hide"), ShowToolTip("已切换到 Hydra 电源策略。") )
)

; -------------------------------
;           条件热键
; -------------------------------
; 在 scrcpy 投屏窗口内禁用 Alt+F 全屏快捷键 (避免冲突)
#HotIf !WinActive("ahk_exe scrcpy.exe")
!F::Send("{F11}")
#HotIf ; 关闭判断条件，确保后续如果再添加其他热键不受影响

; 在桌面区域拦截 Ctrl+滚轮 防止意外缩放图标
#HotIf MouseIsOver("ahk_class Progman") or MouseIsOver("ahk_class WorkerW")
^WheelUp::return   ; 拦截 Ctrl + 滚轮向上
^WheelDown::return ; 拦截 Ctrl + 滚轮向下
#HotIf


; -------------------------------
;          核心功能
; -------------------------------
MinimizeActiveWindow() {
    global MINIMIZED_WINDOWS
    try {
        activeID := WinGetID("A")  ; 获取当前活动窗口ID
        WinMinimize(activeID)      ; 直接最小化窗口
        MINIMIZED_WINDOWS.Push(activeID)  ; 记录到历史
    }
}

RestoreMinimizedWindow() {
    global MINIMIZED_WINDOWS
    while MINIMIZED_WINDOWS.Length > 0 {
        lastID := MINIMIZED_WINDOWS.Pop()  ; 取出最后一个窗口ID
        if WinExist(lastID) {              ; 检查窗口是否存在
            WinRestore(lastID)             ; 恢复窗口
            WinActivate(lastID)            ; 激活到前台
            return                         ; 恢复成功后退出
        }
    }
}

UpdateSystemSettings(type, value) {
    static CombinedInProgress := false
    
    currentPlan := GetActivePowerPlan()
    config := POWER_SETTINGS[type]
    
    for plan in POWER_PLANS {
        RunWait("powercfg /setacvalueindex " plan " " config.subgroup " " config.setting " " value, , "Hide")
    }
    
    RunWait("powercfg /setactive " currentPlan, , "Hide")
    
    ; Display tooltip based on type and value
    tooltipText := ""
    switch type {
        case "Smt":
            tooltipText := "SMT " . (value = 1 ? "Enabled" : (value = 0 ? "Disabled" : "Enabled (" . value . ")"))
        case "PowerSaving":
            tooltipText := "PCIe Power Saving " . (value = 0 ? "Off" : (value = 1 ? "Moderate" : (value = 2 ? "Maximum" : "Unknown (" . value . ")")))
        case "CoreParking":
            tooltipText := "Core Parking Min Cores " . value . "%"
        case "BoostMode":
            tooltipText := "Processor Boost Mode " . (value = 0 ? "Disabled" : (value = 1 ? "Enabled" : (value = 2 ? "Aggressive" : (value = 3 ? "Efficient Enabled" : (value = 4 ? "Efficient Aggressive" : "Unknown (" . value . ")")))))
        default:
             tooltipText := type . " set to " . value
    }
    ShowToolTip(tooltipText)
}

SetMaxFrequency() {
    ; 弹出输入框获取频率值（单位：MHz）
    inputBox := Gui("+AlwaysOnTop", "设置最大频率")
    inputBox.Add("Text",, "输入最大处理器频率 (MHz)：")
    ctl := inputBox.Add("Edit", "w100 Number Limit4", "")
    inputBox.Add("Button", "Default w80", "确定").OnEvent("Click", ProcessInput)
    inputBox.OnEvent("Close", (*) => inputBox.Destroy())
    
    ; 支持ESC键关闭窗口
    inputBox.OnEvent("Escape", (*) => inputBox.Destroy())
    
    inputBox.Show()

    ProcessInput(*) {
        freq := ctl.Value
        inputBox.Destroy()
        
        ; 修改验证范围为0-9999
        if !RegExMatch(freq, "^\d+$") || freq < 0 || freq > 9999 {
            ShowToolTip("无效输入！请输入0-9999之间的整数")
            return
        }
        
        currentPlan := GetActivePowerPlan()
        config := POWER_SETTINGS["MaxFrequency"]
        
        ; 设置所有电源计划
        for plan in POWER_PLANS {
            RunWait("powercfg /setacvalueindex " plan " " config.subgroup " " config.setting " " freq, , "Hide")
        }
        
        ; 重新激活当前计划应用设置
        RunWait("powercfg /setactive " currentPlan, , "Hide")
        ShowToolTip("已设置最大处理器频率为：" freq " MHz`n（0表示使用默认最大值）")
    }
}


; -------------------------------
;          工具函数
; -------------------------------
GetActivePowerPlan() {
    try {
        shell := ComObject("WScript.Shell")
        exec := shell.Exec(A_ComSpec " /C powercfg /getactivescheme")
        if RegExMatch(exec.StdOut.ReadAll(), "([0-9a-f-]{36})", &match)
            return match[1]
    }
    return ""
}

ShowToolTip(text) {
    tooltipGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    tooltipGui.BackColor := "EEAA99"
    tooltipGui.SetFont("s16", "Segoe UI")
    tooltipCtrl := tooltipGui.Add("Text", "Center", text)
    tooltipGui.Show("NoActivate AutoSize")
    
    WinGetPos( , , &width, &height, tooltipGui.Hwnd)
    xPos := (A_ScreenWidth - width) // 3
    yPos := (A_ScreenHeight - height) // 3
    tooltipGui.Move(xPos, yPos)
    
    SetTimer(() => tooltipGui.Destroy(), -3000) ; Tooltip 停留 3 秒
}

InitializeHappResidualMonitor() {
    global HAPP_MONITOR

    CheckHappResidualProcesses()
    SetTimer(CheckHappResidualProcesses, HAPP_MONITOR.checkIntervalMs)
}

CheckHappResidualProcesses() {
    global HAPP_MONITOR

    if ProcessExist(HAPP_MONITOR.mainProcess) {
        return
    }

    hasPotentialResidual := false
    for processName, _ in HAPP_MONITOR.residualPaths {
        if ProcessExist(processName) {
            hasPotentialResidual := true
            break
        }
    }

    if !hasPotentialResidual {
        return
    }

    CleanupHappResidualProcesses()
}

CleanupHappResidualProcesses() {
    global HAPP_MONITOR

    for processName, expectedPath in HAPP_MONITOR.residualPaths {
        normalizedExpectedPath := NormalizeProcessPath(expectedPath)
        for processInfo in QueryProcessInfosByName(processName) {
            executablePath := NormalizeProcessPath(processInfo.ExecutablePath)
            if (executablePath = "" || executablePath != normalizedExpectedPath) {
                continue
            }

            try ProcessClose(Integer(processInfo.ProcessId))
        }
    }
}

QueryProcessInfosByName(processName) {
    escapedName := StrReplace(processName, "'", "''")
    return ComObjGet("winmgmts:").ExecQuery("SELECT ProcessId, ExecutablePath FROM Win32_Process WHERE Name = '" escapedName "'")
}

NormalizeProcessPath(path) {
    return path = "" ? "" : StrLower(StrReplace(path, "/", "\\"))
}

; 判断鼠标当前悬停窗口的函数
MouseIsOver(WinTitle) {
    MouseGetPos(,, &Win)
    return WinExist(WinTitle " ahk_id " Win)
}
; -------------------------------
;          Mac 风格 CapsLock
; -------------------------------
; 配置长按的时间阈值，单位为秒 (0.3 秒 = 300 毫秒)
global tap_threshold := 0.3

*CapsLock:: {
    ; 等待 CapsLock 键被释放，或者达到超时时间
    ; KeyWait 返回 1 表示在超时前释放（短按），返回 0 表示超时（长按）
    if KeyWait("CapsLock", "T" tap_threshold) {
        ; 【短按】：切换输入法
        ; Windows 默认切换输入法是 Win + Space，所以这里发送 #{Space}
        Send("#{Space}")
    } else {
        ; 【长按】：触发大小写锁定/解锁
        ; 获取当前 CapsLock 状态并将其反转
        currentState := GetKeyState("CapsLock", "T")
        SetCapsLockState(currentState ? "Off" : "On")
        
        ; 等待按键真正物理释放，避免长按期间反复触发或闪烁
        KeyWait("CapsLock")
    }
}
