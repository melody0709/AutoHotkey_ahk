#Requires AutoHotkey v2.0
#NoTrayIcon

; -------------------------------
;          全局常量定义
; -------------------------------
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
    "CoreParking", {  ; 新增：Processor performance core parking min cores
        subgroup: "54533251-82be-4824-96c1-47b60b740d00",
        setting:  "0cc5b647-c1df-4637-891a-dec35c318583"      
    },
    "BoostMode", {  
        subgroup: "54533251-82be-4824-96c1-47b60b740d00",
        setting:  "be337238-0d82-4146-a960-4f3749d470c7"
    },
    "MaxFrequency", {  ; 最大处理器频率
        subgroup: "54533251-82be-4824-96c1-47b60b740d00",
        setting:  "75b0ae3f-bce0-45a7-8c89-c9611c25e100"
    } 
)

; 双击检测变量（原 SMT、PowerSaving 的）
global LastSmtClick := 0, SmtClickCount := 0
global LastPowerClick := 0, PowerClickCount := 0

; 新增：组合双击检测变量，用于同时更新 SMT 与 CoreParking
global LastCombinedClick := 0, CombinedClickCount := 0

; 新增：ZenStates双击检测变量
global LastNumpad3Click := 0, Numpad3ClickCount := 0  

; 新增：boostmode双击检测变量
global LastBoostClick := 0, BoostClickCount := 0

; ***新增：电源计划切换双击检测变量***
global LastNumpad1Click := 0, Numpad1ClickCount := 0

; -------------------------------
;          热键绑定
; -------------------------------
^Esc:: SendInput("^#{F11}")  ; Ctrl+Esc -> Win+Ctrl+F11  ,需要配合 buttery-taskbar.exe 隐藏任务栏
+`::   MinimizeActiveWindow()  ; shift+` -> 最小化当前窗口 ,win11系统自带的最小化窗口
+Q::   RestoreMinimizedWindow() ; shift+Q -> 恢复窗口,win11系统自带的恢复窗口

!`::   SendInput("^!{Down}") ; Alt+` -> 缩放到托盘,需要配合 RBTray.exet to minimize to tray 
!Q::   SendInput("^!{Up}")   ; Alt+Q -> 从托盘还原,需要配合 RBTray.exet to minimize to tray


; ^+`:: SendInput("^+<")  ; Ctrl+Shift+` -> 替代 Ctrl+Shift+,edge侧边栏


^!Numpad7:: {  ; 设置GPU频率和功率限制,需要配合 nvidia 卡 使用
    RunWait("nvidia-smi -lmc 400,5002", , "Hide")  ; 设置最小和最大频率
    RunWait("nvidia-smi -pl 250", , "Hide")        ; 设置功率限制
    RunWait("nvidia-smi -lgc 200,2100", , "Hide")    ; 设置最高频率为 2100 MHz
    ShowToolTip("lmc Cap Set: 400 MHz - 5002 MHz`nPower Limit Set: 150W`nMax Clock Set: 2100 MHz")
}

^!Numpad9:: {  ; 移除GPU频率限制,需要配合 nvidia 卡 使用
    RunWait("nvidia-smi -rmc", , "Hide")
    RunWait("nvidia-smi -rgc", , "Hide")
    RunWait("nvidia-smi -pl 325", , "Hide")
    ShowToolTip("lmc rgc pl Cap Removed")
}

^!Numpad6:: {  ; Power Saver
    RunWait("powercfg /setactive " POWER_PLANS[2], , "Hide")
    ShowToolTip("已切换到 Power Saver 电源策略。")
}

; Ctrl+Alt+小键盘0 热键：同时修改 SMT 与 CoreParking设置
; 按住Ctrl+Alt键，然后按小键盘的0键，可以同时修改 SMT 与 CoreParking设置。单击操作：SMT设置为 0，CoreParking设置为 50
; 按住Ctrl+Alt键，然后双击小键盘的0键，可以同时修改 SMT 与 CoreParking设置。双击操作：SMT设置为 2，CoreParking设置为 25
^!Numpad0:: HandleCombinedDoubleClick(300, 0, 100, 2, 50)

; Ctrl+Alt+小键盘2 ; 热键：全局调整系统pcie节能策略
; 按住Ctrl+Alt键，然后按小键盘的2键，可以调整系统的节电模式。单击操作：关闭所有节电设置（设为0）
; 按住Ctrl+Alt键，然后双击小键盘的2键，可以调整系统的节电模式。双击操作：启用最大节电模式（设为2）
^!Numpad2:: HandleDoubleClick("PowerSaving", 300, 2, 0)  ; 节电模式

; Ctrl+Alt+小键盘3 单双击3 能切换zenstate c6状态
^!Numpad3:: HandleZenStatesClick()  

; Ctrl+Alt+小键盘5 单双击5 能切换boost状态
^!Numpad5:: HandleDoubleClick("BoostMode", 300, 2, 0)

; 在热键绑定部分添加新热键
^!Numpad4:: SetMaxFrequency()

; ***修改：Ctrl+Alt+Numpad1 实现 Balanced/Hydra 电源计划切换***
; 单击 -> Balanced
; 双击 -> Hydra
^!Numpad1:: HandlePowerPlanDoubleClick(300)  ; 切换balanced hydra电源策略

; -------------------------------
;           条件热键
; -------------------------------
; 仅当当前窗口【不是】scrcpy 时，才将 Alt+F 映射为 F11
#HotIf !WinActive("ahk_exe scrcpy.exe")
!F::Send("{F11}")
#HotIf ; 关闭判断条件，确保后续如果再添加其他热键不受影响

; 当鼠标悬停在桌面 (Progman 或 WorkerW) 时生效
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

; 原有的 HandleDoubleClick 用于 PowerSaving 与其他单一项的双击检测
; 修改 HandleDoubleClick 函数
HandleDoubleClick(type, interval, clickAction, doubleClickAction) {
    global LastSmtClick, SmtClickCount, LastPowerClick, PowerClickCount, LastBoostClick, BoostClickCount
    currentTime := A_TickCount
    isDouble := false
    
    switch type {
        case "Smt":
            if (currentTime - LastSmtClick < interval) {
                SmtClickCount++
                if (SmtClickCount >= 2) {
                    isDouble := true
                    UpdateSystemSettings(type, doubleClickAction)
                    SmtClickCount := 0
                }
            } else {
                SmtClickCount := 1
            }
            LastSmtClick := currentTime
            if (!isDouble) {
                SetTimer(() => CheckSingleClick(type, clickAction), -interval)
            }
        
        case "PowerSaving":
            if (currentTime - LastPowerClick < interval) {
                PowerClickCount++
                if (PowerClickCount >= 2) {
                    isDouble := true
                    UpdateSystemSettings(type, doubleClickAction)
                    PowerClickCount := 0
                }
            } else {
                PowerClickCount := 1
            }
            LastPowerClick := currentTime
            if (!isDouble) {
                SetTimer(() => CheckSingleClick(type, clickAction), -interval)
            }
        
        case "BoostMode":
            if (currentTime - LastBoostClick < interval) {
                BoostClickCount++
                if (BoostClickCount >= 2) {
                    isDouble := true
                    UpdateSystemSettings(type, doubleClickAction)
                    BoostClickCount := 0
                }
            } else {
                BoostClickCount := 1
            }
            LastBoostClick := currentTime
            if (!isDouble) {
                SetTimer(() => CheckSingleClick(type, clickAction), -interval)
            }
    }
}


; 修改 CheckSingleClick 函数
CheckSingleClick(type, action) {
    global SmtClickCount, PowerClickCount, BoostClickCount
    switch type {
        case "Smt":
            if (SmtClickCount = 1) {
                UpdateSystemSettings(type, action)
                SmtClickCount := 0
            }
        
        case "PowerSaving":
            if (PowerClickCount = 1) {
                UpdateSystemSettings(type, action)
                PowerClickCount := 0
            }
        
        case "BoostMode":
            if (BoostClickCount = 1) {
                UpdateSystemSettings(type, action)
                BoostClickCount := 0
            }
    }
}


; 新增：组合双击检测函数，同时更新 SMT 与 CoreParking
HandleCombinedDoubleClick(interval, singleSmt, singleCore, doubleSmt, doubleCore) {
    global LastCombinedClick, CombinedClickCount
    currentTime := A_TickCount
    isDouble := false

    if (currentTime - LastCombinedClick < interval) {
        CombinedClickCount++
        if (CombinedClickCount >= 2) {
            isDouble := true
            UpdateSystemSettings("Smt", doubleSmt)
            UpdateSystemSettings("CoreParking", doubleCore)
            CombinedClickCount := 0
        }
    } else {
        CombinedClickCount := 1
    }
    LastCombinedClick := currentTime
    if (!isDouble) {
        SetTimer(() => CheckCombinedSingleClick(singleSmt, singleCore), -interval)
    }
}

CheckCombinedSingleClick(singleSmt, singleCore) {
    global CombinedClickCount
    if (CombinedClickCount = 1) {
        UpdateSystemSettings("Smt", singleSmt)
        UpdateSystemSettings("CoreParking", singleCore)
        CombinedClickCount := 0
    }
}

; 修改 UpdateSystemSettings 函数
UpdateSystemSettings(type, value) {
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
        ; case "MaxFrequency": ; Tooltip handled in SetMaxFrequency
        ;     tooltipText := "Max Frequency set to " . value . " MHz"
        default:
             tooltipText := type . " set to " . value
    }
    if (tooltipText != "") {
        ; Add combined tooltip for Smt/CoreParking
        if (type = "Smt" && CombinedClickCount = 0) { 
             ; If called via combined handler and it finished, tooltip handled there
        } else if (type = "CoreParking" && CombinedClickCount = 0) {
            smtVal := (value = 50 ? 0 : 2) ; Infer SMT value from CoreParking double click
            cpVal := value
            ShowToolTip("SMT " . (smtVal = 0 ? "Disabled" : "Enabled") . "`nCore Parking Min Cores " . cpVal . "%")
        }
         else {
            ShowToolTip(tooltipText)
        }
    }
}


HandleZenStatesClick() {
    global LastNumpad3Click, Numpad3ClickCount
    interval := 300  ; 300毫秒双击判定间隔
    
    currentTime := A_TickCount
    elapsed := currentTime - LastNumpad3Click
    
    ; 如果是首次点击或超过间隔时间
    if (elapsed > interval) {
        Numpad3ClickCount := 1
    } else {
        Numpad3ClickCount += 1
    }
    
    LastNumpad3Click := currentTime
    
    if (Numpad3ClickCount = 1) {
        ; 设置计时器等待可能的第二次点击
        SetTimer(CheckZenStatesClicks, -interval)
    } else if (Numpad3ClickCount = 2) {
        ; 立即处理双击
        HandleDoubleClickAction()
        Numpad3ClickCount := 0  ; 重置计数器
    }
}

CheckZenStatesClicks() {
    global Numpad3ClickCount
    if (Numpad3ClickCount = 1) {
        ; 处理单击动作
        Run(A_ScriptDir "\lib\ZenStates_C6_Enable.ahk")
        ShowToolTip("C6状态已启用")
        Numpad3ClickCount := 0  ; 重置计数器
    }
}

HandleDoubleClickAction() {
    ; 处理双击动作
    Run(A_ScriptDir "\lib\ZenStates_C6_Disabled.ahk")
    ShowToolTip("C6状态已禁用")
}


; 新增功能函数
SetMaxFrequency() {
    ; 弹出输入框获取频率值（单位：MHz）
    inputBox := Gui("+AlwaysOnTop", "设置最大频率")
    inputBox.Add("Text",, "输入最大处理器频率 (MHz)：")
    ctl := inputBox.Add("Edit", "w100 Number Limit4", "")  ; 修改为Limit4
    inputBox.Add("Button", "Default w80", "确定").OnEvent("Click", ProcessInput)
    inputBox.OnEvent("Close", (*) => inputBox.Destroy())
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

; ***新增：电源计划切换双击处理函数***
HandlePowerPlanDoubleClick(interval) {
    global LastNumpad1Click, Numpad1ClickCount, POWER_PLANS
    currentTime := A_TickCount
    isDouble := false

    if (currentTime - LastNumpad1Click < interval) {
        Numpad1ClickCount++
        if (Numpad1ClickCount >= 2) {
            isDouble := true
            ; 双击操作: 切换到 Hydra (Index 4)
            RunWait("powercfg /setactive " POWER_PLANS[4], , "Hide")
            ShowToolTip("已切换到 Hydra 电源策略。")
            Numpad1ClickCount := 0
        }
    } else {
        Numpad1ClickCount := 1
    }
    LastNumpad1Click := currentTime
    if (!isDouble) {
        SetTimer(CheckPowerPlanSingleClick, -interval) ; 使用负值表示只运行一次
    }
}

; ***新增：电源计划切换单击检查函数***
CheckPowerPlanSingleClick() {
    global Numpad1ClickCount, POWER_PLANS
    if (Numpad1ClickCount = 1) {
        ; 单击操作: 切换到 Balanced (Index 1)
        RunWait("powercfg /setactive " POWER_PLANS[1], , "Hide")
        ShowToolTip("已切换到 Balanced 电源策略。")
        Numpad1ClickCount := 0 ; 重置计数器
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
    
    SetTimer(() => tooltipGui.Destroy(), -2000) ; Tooltip stays for 2 seconds
}

; 判断鼠标当前悬停窗口的函数
MouseIsOver(WinTitle) {
    MouseGetPos(,, &Win)
    return WinExist(WinTitle " ahk_id " Win)
}
