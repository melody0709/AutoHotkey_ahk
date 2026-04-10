#Requires AutoHotkey v2.0
#Include "UIA.ahk" ; 确保 UIA.ahk 文件在 AHK 的 Lib 目录或脚本同目录下

; --- 配置 ---
zenPath := "D:\SynologyDrive\cpu_gpu_overlock\# CPU\ZenStates-2.0-20241202\ZenStates.exe" ; 请确保路径正确
targetWinTitle := "ZenStates" ; 根据实际窗口标题调整，可能包含版本号

; --- 尝试获取管理员权限 ---
if !A_IsAdmin {
    try {
        Run '*RunAs "' A_ScriptFullPath '"'
    } catch OSError {
        ; MsgBox "请求管理员权限失败，请手动以管理员身份运行脚本。" ; 静默模式，注释掉消息框
    }
    ExitApp ; 非管理员直接退出
}

; --- 运行与等待 ---
try {
    Run zenPath
} catch Error {
    ; MsgBox "无法运行 ZenStates.exe: " e.Message ; 静默模式
    ExitApp ; 启动失败则退出
}

if !WinWait(targetWinTitle, , 10) { ; 等待最多 10 秒
    ; MsgBox "等待 ZenStates 窗口超时。" ; 静默模式
    ExitApp ; 超时退出
}

; --- 激活与导航 ---
WinActivate(targetWinTitle)
Sleep 500 ; 等待窗口激活

Send "{Right 2}" ; 切换到 Power 选项卡
Sleep 500 ; 等待 UI 响应

; --- UIA 操作 ---
try {
    win := UIA.ElementFromHandle(WinExist(targetWinTitle))
    if !IsObject(win) {
        throw Error("无法获取 ZenStates 窗口的 UIA 元素。") ; 内部抛出错误
    }

    ; --- 确保 Core C6-State 未勾选 ---
    coreC6Checkbox := win.FindFirst({Name: "Core C6-State", Type: "CheckBox"})
    if IsObject(coreC6Checkbox) {
        togglePattern := coreC6Checkbox.TogglePattern
        if IsObject(togglePattern) {
            currentState := togglePattern.CurrentToggleState ; 0=Off, 1=On
            if currentState == 1 { ; 如果当前是勾选状态 (On)
                togglePattern.Toggle() ; 则点击一次以取消勾选
                Sleep 200 ; 短暂等待
            }
        }
    } else {
         ; 可以选择记录日志或无操作
         ; OutputDebug "未找到 Core C6-State CheckBox"
    }


    ; --- 确保 Package C6-State 未勾选 ---
    packageC6Checkbox := win.FindFirst({Name: "Package C6-State", Type: "CheckBox"})
     if IsObject(packageC6Checkbox) {
        togglePattern := packageC6Checkbox.TogglePattern
         if IsObject(togglePattern) {
            currentState := togglePattern.CurrentToggleState ; 0=Off, 1=On
             if currentState == 1 { ; 如果当前是勾选状态 (On)
                togglePattern.Toggle() ; 则点击一次以取消勾选
                Sleep 200 ; 短暂等待
            }
        }
    } else {
        ; 可以选择记录日志或无操作
        ; OutputDebug "未找到 Package C6-State CheckBox"
    }


    ; --- 点击 Apply 按钮 ---
    applyButton := win.FindFirst({Name: "Apply", Type: "Button"})
    if IsObject(applyButton) {
        invokePattern := applyButton.InvokePattern
        if IsObject(invokePattern) {
            invokePattern.Invoke() ; 点击 Apply
            Sleep 500 ; 等待应用生效
        }
    } else {
        ; 可以选择记录日志或无操作
        ; OutputDebug "未找到 Apply Button"
    }

} catch Error as e {
    ; 静默模式，发生错误时不弹出消息框
    ; 可以选择将错误记录到日志文件
    ; FileAppend(A_Now " - Error: " e.Message " at line " e.Line "`n", "ScriptErrorLog.txt")
}


Sleep 300

; 关闭 ZenStates
WinClose("ZenStates")


ExitApp
