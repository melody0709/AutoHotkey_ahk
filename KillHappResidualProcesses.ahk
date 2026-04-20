; ==============================================
; happ.exe 进程残留自动清理脚本
; 功能: 监控 happ.exe 退出后自动结束相关残留进程
; 目标进程: updater.exe, hxdaemonprocess.exe
; 说明: 主热键脚本已集成同样逻辑，此文件仅保留为独立备用版
; ==============================================

#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
Persistent

A_FileEncoding := "UTF-8-RAW"
SetWorkingDir(A_ScriptDir)

global ProcessNameMain := "happ.exe"
global HappExePath := "C:\同花顺远航版\bin\happ.exe"
global ResidualProcesses := Map(
    "updater.exe", "C:\同花顺远航版\bin\UpdateWorking\updater.exe",
    "hxdaemonprocess.exe", "C:\同花顺远航版\bin\hxdaemonprocess\hxdaemonprocess.exe"
)
global CheckIntervalMs := 60000
global LogEnabled := false

WriteLog("进程监控脚本已启动")

SetTimer(MonitorHappProcess, CheckIntervalMs)
OnExit(ExitScript)
MonitorHappProcess()

MonitorHappProcess() {
    global ProcessNameMain, ResidualProcesses

    if ProcessExist(ProcessNameMain) {
        return
    }

    hasPotentialResidual := false
    for processName, _ in ResidualProcesses {
        if ProcessExist(processName) {
            hasPotentialResidual := true
            break
        }
    }

    if hasPotentialResidual {
        CleanupResidualProcesses()
    }
}

CleanupResidualProcesses() {
    global ResidualProcesses

    terminatedCount := 0

    for processName, expectedPath in ResidualProcesses {
        normalizedExpectedPath := NormalizePath(expectedPath)
        for processInfo in QueryProcessesByName(processName) {
            executablePath := NormalizePath(processInfo.ExecutablePath)
            if (executablePath = "" || executablePath != normalizedExpectedPath) {
                continue
            }

            pid := Integer(processInfo.ProcessId)
            try {
                ProcessClose(pid)
                terminatedCount += 1
            }
        }
    }

    return terminatedCount
}

QueryProcessesByName(processName) {
    escapedName := StrReplace(processName, "'", "''")
    wmiService := ComObjGet("winmgmts:")
    return wmiService.ExecQuery("SELECT Name, ProcessId, ExecutablePath FROM Win32_Process WHERE Name = '" escapedName "'")
}

NormalizePath(path) {
    return StrLower(StrReplace(path, "/", "\\"))
}

WriteLog(message) {
    global LogEnabled

    if !LogEnabled {
        return
    }

    timestamp := FormatTime(, "yyyyMMdd-HHmmss")
    FileAppend("[" timestamp "] " message "`n", A_ScriptDir "\\happ_monitor.log", "UTF-8")
}

ExitScript(*) {
    WriteLog("进程监控脚本已退出")
}