.386
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc
include \masm32\include\masm32.inc
include \masm32\include\advapi32.inc

includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib
includelib \masm32\lib\gdi32.lib
includelib \masm32\lib\masm32.lib
includelib \masm32\lib\advapi32.lib
includelib \masm32\lib\psapi.lib

; ------------------------------------------------------------------
; Administrador de Procesos - MASM32
; Ejercicio 3: Administracion de procesos con interfaz grafica
; ------------------------------------------------------------------
; Funcionalidades principales:
; 1. Listar procesos en ejecucion.
; 2. Seleccionar multiples procesos.
; 3. Finalizar uno o varios procesos seleccionados.
; 4. Mostrar informacion del proceso: PID, PPID, threads, prioridad,
;    memoria usada y tiempo de CPU acumulado.
; 5. Modificar prioridad: Alta, Normal, Baja e Inactiva.
; 6. Seleccionar todos los procesos.
; 7. Limpiar seleccion.
; 8. Actualizacion manual.
; 9. Actualizacion automatica por temporizador.
; 10. Gestion basica de permisos mediante SeDebugPrivilege.
; ------------------------------------------------------------------

WinMain proto :DWORD,:DWORD,:DWORD,:DWORD
WndProc proto :DWORD,:DWORD,:DWORD,:DWORD
CargarProcesos proto
TerminarSeleccionados proto
CambiarPrioridad proto :DWORD
MostrarInfo proto
LimpiarSeleccion proto
SeleccionarTodos proto
ToggleAutoRefresh proto :DWORD
ObtenerMemoriaKB proto :DWORD
ObtenerCpuMs proto :DWORD
HabilitarDebugPrivilege proto

GetProcessMemoryInfo PROTO STDCALL :DWORD,:DWORD,:DWORD

PROCESS_MEMORY_COUNTERS_LOCAL STRUCT
    cb                         DWORD ?
    PageFaultCount             DWORD ?
    PeakWorkingSetSize         DWORD ?
    WorkingSetSize             DWORD ?
    QuotaPeakPagedPoolUsage    DWORD ?
    QuotaPagedPoolUsage        DWORD ?
    QuotaPeakNonPagedPoolUsage DWORD ?
    QuotaNonPagedPoolUsage     DWORD ?
    PagefileUsage              DWORD ?
    PeakPagefileUsage          DWORD ?
PROCESS_MEMORY_COUNTERS_LOCAL ENDS

IDC_LISTA       equ 1001

BTN_ACTUALIZAR equ 2001
BTN_FINALIZAR  equ 2002
BTN_ALTA       equ 2003
BTN_NORMAL     equ 2004
BTN_INFO       equ 2005
BTN_LIMPIAR    equ 2006
BTN_BAJA       equ 2007
BTN_IDLE       equ 2008
BTN_TODOS      equ 2009
BTN_AUTO       equ 2010
BTN_ACERCA     equ 2011

ID_TIMER_AUTO  equ 3001

MAX_PROCESOS equ 1024

.data
ClassName db "AdminProcesosMASM",0
AppName   db "Administrador de Procesos - MASM32",0

kernelDll db "kernel32.dll",0
nameProcess32First db "Process32First",0
nameProcess32Next  db "Process32Next",0

listClass db "LISTBOX",0
btnClass  db "BUTTON",0
statClass db "STATIC",0

titulo db "ADMINISTRADOR DE PROCESOS MASM32",0
lblProcesos db "Procesos en ejecucion:",0

btnActualizar db "Actualizar",0
btnFinalizar  db "Finalizar seleccionados",0
btnAlta       db "Prioridad Alta",0
btnNormal     db "Prioridad Normal",0
btnBaja       db "Prioridad Baja",0
btnIdle       db "Prioridad Inactiva",0
btnInfo       db "Ver informacion",0
btnLimpiar    db "Limpiar seleccion",0
btnTodos      db "Seleccionar todos",0
btnAuto       db "Auto actualizar",0
btnAcerca     db "Acerca de",0

msgTitulo db "Administrador de procesos",0
msgConfirmar db "Desea finalizar los procesos seleccionados?",0
msgSinSeleccion db "Debe seleccionar al menos un proceso.",0
msgFinalizado db "Operacion realizada. Actualizando lista.",0
msgPrioridad db "Prioridad modificada correctamente.",0
msgError db "No se pudo realizar la operacion. Ejecute como administrador si es necesario.",0
msgApiError db "No se pudieron cargar las funciones Process32FirstA/Process32NextA.",0

msgAutoOn db "Actualizacion automatica activada.",0
msgAutoOff db "Actualizacion automatica desactivada.",0

msgAcerca db "Administrador de Procesos desarrollado en MASM32.",13,10
          db "Permite listar procesos, seleccionar multiples elementos,",13,10
          db "finalizarlos, consultar memoria/CPU y modificar prioridad.",13,10,13,10
          db "Nota: algunas operaciones requieren ejecutar como administrador.",0

fmtProceso db "PID: %u | Mem: %u KB | %s",0

fmtInfo db "Nombre del proceso: %s",13,10
        db "PID: %u",13,10
        db "ID padre: %u",13,10
        db "Threads: %u",13,10
        db "Prioridad base: %u",13,10
        db "Memoria aproximada: %u KB",13,10
        db "Tiempo CPU acumulado: %u ms",0

fmtTotal db "Total de procesos: %u",0

fontName db "Segoe UI",0
debugPrivilegeName db "SeDebugPrivilege",0

buffer db 300 dup(0)
infoBuffer db 700 dup(0)
totalBuffer db 64 dup(0)

.data?
hInstance HINSTANCE ?
hLista HWND ?
hTotal HWND ?
hFont HFONT ?
hFontTitle HFONT ?
hBrush HBRUSH ?

hKernel dd ?
pProcess32First dd ?
pProcess32Next  dd ?

pids dd MAX_PROCESOS dup(?)
selected dd MAX_PROCESOS dup(?)
processCount dd ?
autoRefresh dd ?

.code

start:
    invoke GetModuleHandle, NULL
    mov hInstance, eax

    ; Se intenta habilitar SeDebugPrivilege para mejorar el acceso
    ; a procesos protegidos cuando el programa se ejecuta como administrador.
    invoke HabilitarDebugPrivilege

    invoke GetModuleHandle, addr kernelDll
    mov hKernel, eax

    invoke GetProcAddress, hKernel, addr nameProcess32First
    mov pProcess32First, eax

    invoke GetProcAddress, hKernel, addr nameProcess32Next
    mov pProcess32Next, eax

    invoke WinMain, hInstance, NULL, NULL, SW_SHOWDEFAULT
    invoke ExitProcess, eax

WinMain proc hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD

    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG
    LOCAL hwnd:HWND

    invoke CreateSolidBrush, 00F0F0F0h
    mov hBrush, eax

    invoke CreateFont, 18,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,\
           DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,\
           DEFAULT_QUALITY,DEFAULT_PITCH or FF_DONTCARE, addr fontName
    mov hFont, eax

    invoke CreateFont, 24,0,0,0,FW_BOLD,FALSE,FALSE,FALSE,\
           DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,\
           DEFAULT_QUALITY,DEFAULT_PITCH or FF_DONTCARE, addr fontName
    mov hFontTitle, eax

    mov wc.cbSize, SIZEOF WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, OFFSET WndProc
    mov wc.cbClsExtra, NULL
    mov wc.cbWndExtra, NULL

    push hInst
    pop wc.hInstance

    mov wc.hbrBackground, COLOR_BTNFACE+1
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, OFFSET ClassName

    invoke LoadIcon, NULL, IDI_APPLICATION
    mov wc.hIcon, eax
    mov wc.hIconSm, eax

    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax

    invoke RegisterClassEx, addr wc

    invoke CreateWindowEx, NULL, addr ClassName, addr AppName,\
           WS_OVERLAPPEDWINDOW,\
           CW_USEDEFAULT, CW_USEDEFAULT, 900, 620,\
           NULL, NULL, hInst, NULL

    mov hwnd, eax

    invoke ShowWindow, hwnd, CmdShow
    invoke UpdateWindow, hwnd

MessageLoop:
    invoke GetMessage, addr msg, NULL, 0, 0
    cmp eax, 0
    je ExitLoop

    invoke TranslateMessage, addr msg
    invoke DispatchMessage, addr msg
    jmp MessageLoop

ExitLoop:
    mov eax, msg.wParam
    ret

WinMain endp

WndProc proc hwnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM

    .if uMsg == WM_CREATE

        invoke CreateWindowEx, NULL, addr statClass, addr titulo,\
               WS_CHILD or WS_VISIBLE or SS_CENTER,\
               20, 20, 830, 35,\
               hwnd, NULL, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFontTitle, TRUE

        invoke CreateWindowEx, NULL, addr statClass, addr lblProcesos,\
               WS_CHILD or WS_VISIBLE,\
               30, 70, 250, 25,\
               hwnd, NULL, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, WS_EX_CLIENTEDGE, addr listClass, NULL,\
               WS_CHILD or WS_VISIBLE or WS_VSCROLL or LBS_EXTENDEDSEL or LBS_NOTIFY,\
               30, 100, 560, 390,\
               hwnd, IDC_LISTA, hInstance, NULL
        mov hLista, eax
        invoke SendMessage, hLista, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnActualizar,\
               WS_CHILD or WS_VISIBLE,\
               620, 100, 210, 32,\
               hwnd, BTN_ACTUALIZAR, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnInfo,\
               WS_CHILD or WS_VISIBLE,\
               620, 138, 210, 32,\
               hwnd, BTN_INFO, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnFinalizar,\
               WS_CHILD or WS_VISIBLE,\
               620, 176, 210, 32,\
               hwnd, BTN_FINALIZAR, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnAlta,\
               WS_CHILD or WS_VISIBLE,\
               620, 214, 210, 32,\
               hwnd, BTN_ALTA, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnNormal,\
               WS_CHILD or WS_VISIBLE,\
               620, 252, 210, 32,\
               hwnd, BTN_NORMAL, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnBaja,\
               WS_CHILD or WS_VISIBLE,\
               620, 290, 210, 32,\
               hwnd, BTN_BAJA, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnIdle,\
               WS_CHILD or WS_VISIBLE,\
               620, 328, 210, 32,\
               hwnd, BTN_IDLE, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnTodos,\
               WS_CHILD or WS_VISIBLE,\
               620, 366, 210, 32,\
               hwnd, BTN_TODOS, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnLimpiar,\
               WS_CHILD or WS_VISIBLE,\
               620, 404, 210, 32,\
               hwnd, BTN_LIMPIAR, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnAuto,\
               WS_CHILD or WS_VISIBLE,\
               620, 442, 210, 32,\
               hwnd, BTN_AUTO, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnAcerca,\
               WS_CHILD or WS_VISIBLE,\
               620, 480, 210, 32,\
               hwnd, BTN_ACERCA, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr statClass, NULL,\
               WS_CHILD or WS_VISIBLE,\
               30, 510, 500, 25,\
               hwnd, NULL, hInstance, NULL
        mov hTotal, eax
        invoke SendMessage, hTotal, WM_SETFONT, hFont, TRUE

        invoke CargarProcesos

    .elseif uMsg == WM_TIMER

        mov eax, wParam
        .if eax == ID_TIMER_AUTO
            invoke CargarProcesos
        .endif

    .elseif uMsg == WM_COMMAND

        mov eax, wParam
        and eax, 0FFFFh

        .if eax == BTN_ACTUALIZAR
            invoke CargarProcesos

        .elseif eax == BTN_FINALIZAR
            invoke TerminarSeleccionados

        .elseif eax == BTN_ALTA
            invoke CambiarPrioridad, HIGH_PRIORITY_CLASS

        .elseif eax == BTN_NORMAL
            invoke CambiarPrioridad, NORMAL_PRIORITY_CLASS

        .elseif eax == BTN_BAJA
            invoke CambiarPrioridad, BELOW_NORMAL_PRIORITY_CLASS

        .elseif eax == BTN_IDLE
            invoke CambiarPrioridad, IDLE_PRIORITY_CLASS

        .elseif eax == BTN_INFO
            invoke MostrarInfo

        .elseif eax == BTN_TODOS
            invoke SeleccionarTodos

        .elseif eax == BTN_LIMPIAR
            invoke LimpiarSeleccion

        .elseif eax == BTN_AUTO
            invoke ToggleAutoRefresh, hwnd

        .elseif eax == BTN_ACERCA
            invoke MessageBox, hwnd, addr msgAcerca, addr msgTitulo, MB_OK or MB_ICONINFORMATION

        .endif

    .elseif uMsg == WM_CTLCOLORSTATIC

        invoke SetBkColor, wParam, 00F0F0F0h
        invoke SetTextColor, wParam, 00000000h
        mov eax, hBrush
        ret

    .elseif uMsg == WM_DESTROY

        invoke KillTimer, hwnd, ID_TIMER_AUTO
        invoke DeleteObject, hFont
        invoke DeleteObject, hFontTitle
        invoke DeleteObject, hBrush
        invoke PostQuitMessage, NULL

    .else

        invoke DefWindowProc, hwnd, uMsg, wParam, lParam
        ret

    .endif

    xor eax, eax
    ret

WndProc endp

CargarProcesos proc

    LOCAL pe:PROCESSENTRY32
    LOCAL hSnap:DWORD
    LOCAL ok:DWORD
    LOCAL memKB:DWORD

    cmp pProcess32First, 0
    je ApiError

    cmp pProcess32Next, 0
    je ApiError

    mov processCount, 0

    invoke SendMessage, hLista, LB_RESETCONTENT, 0, 0

    invoke CreateToolhelp32Snapshot, TH32CS_SNAPPROCESS, 0
    mov hSnap, eax

    cmp hSnap, INVALID_HANDLE_VALUE
    je SalirCarga

    invoke RtlZeroMemory, addr pe, SIZEOF PROCESSENTRY32
    mov pe.dwSize, SIZEOF PROCESSENTRY32

    lea eax, pe
    push eax
    push hSnap
    call dword ptr [pProcess32First]
    mov ok, eax

    .while ok != 0

        mov eax, processCount
        cmp eax, MAX_PROCESOS
        jge FinListado

        mov ecx, processCount
        mov eax, pe.th32ProcessID
        mov pids[ecx*4], eax

        invoke ObtenerMemoriaKB, pe.th32ProcessID
        mov memKB, eax

        invoke wsprintf, addr buffer, addr fmtProceso, pe.th32ProcessID, memKB, addr pe.szExeFile
        invoke SendMessage, hLista, LB_ADDSTRING, 0, addr buffer

        inc processCount

        lea eax, pe
        push eax
        push hSnap
        call dword ptr [pProcess32Next]
        mov ok, eax

    .endw

FinListado:
    invoke CloseHandle, hSnap

SalirCarga:
    invoke wsprintf, addr totalBuffer, addr fmtTotal, processCount
    invoke SetWindowText, hTotal, addr totalBuffer
    ret

ApiError:
    invoke MessageBox, NULL, addr msgApiError, addr msgTitulo, MB_ICONERROR
    ret

CargarProcesos endp

TerminarSeleccionados proc

    LOCAL totalSel:DWORD
    LOCAL i:DWORD
    LOCAL index:DWORD
    LOCAL pid:DWORD
    LOCAL hProc:DWORD

    invoke SendMessage, hLista, LB_GETSELCOUNT, 0, 0
    mov totalSel, eax

    cmp totalSel, 0
    jg HaySeleccion

    invoke MessageBox, NULL, addr msgSinSeleccion, addr msgTitulo, MB_ICONWARNING
    ret

HaySeleccion:

    invoke MessageBox, NULL, addr msgConfirmar, addr msgTitulo, MB_YESNO or MB_ICONQUESTION
    cmp eax, IDYES
    jne SalirTerminar

    invoke SendMessage, hLista, LB_GETSELITEMS, MAX_PROCESOS, addr selected

    mov i, 0

LoopTerminar:

    mov eax, i
    cmp eax, totalSel
    jge FinTerminar

    mov eax, selected[eax*4]
    mov index, eax

    mov eax, index
    mov eax, pids[eax*4]
    mov pid, eax

    invoke OpenProcess, PROCESS_TERMINATE, FALSE, pid
    mov hProc, eax

    cmp hProc, 0
    je SiguienteTerminar

    invoke TerminateProcess, hProc, 0
    invoke CloseHandle, hProc

SiguienteTerminar:
    inc i
    jmp LoopTerminar

FinTerminar:
    invoke MessageBox, NULL, addr msgFinalizado, addr msgTitulo, MB_OK
    invoke CargarProcesos

SalirTerminar:
    ret

TerminarSeleccionados endp

CambiarPrioridad proc prioridad:DWORD

    LOCAL totalSel:DWORD
    LOCAL i:DWORD
    LOCAL index:DWORD
    LOCAL pid:DWORD
    LOCAL hProc:DWORD

    invoke SendMessage, hLista, LB_GETSELCOUNT, 0, 0
    mov totalSel, eax

    cmp totalSel, 0
    jg HaySeleccion

    invoke MessageBox, NULL, addr msgSinSeleccion, addr msgTitulo, MB_ICONWARNING
    ret

HaySeleccion:

    invoke SendMessage, hLista, LB_GETSELITEMS, MAX_PROCESOS, addr selected

    mov i, 0

LoopPrioridad:
    mov eax, i
    cmp eax, totalSel
    jge FinPrioridad

    mov eax, selected[eax*4]
    mov index, eax

    mov eax, index
    mov eax, pids[eax*4]
    mov pid, eax

    invoke OpenProcess, PROCESS_SET_INFORMATION or PROCESS_QUERY_INFORMATION, FALSE, pid
    mov hProc, eax

    cmp hProc, 0
    je SiguientePrioridad

    invoke SetPriorityClass, hProc, prioridad
    invoke CloseHandle, hProc

SiguientePrioridad:
    inc i
    jmp LoopPrioridad

FinPrioridad:
    invoke MessageBox, NULL, addr msgPrioridad, addr msgTitulo, MB_OK
    invoke CargarProcesos
    ret

CambiarPrioridad endp

MostrarInfo proc

    LOCAL totalSel:DWORD
    LOCAL index:DWORD
    LOCAL pid:DWORD
    LOCAL pe:PROCESSENTRY32
    LOCAL hSnap:DWORD
    LOCAL ok:DWORD
    LOCAL memKB:DWORD
    LOCAL cpuMs:DWORD

    cmp pProcess32First, 0
    je ApiError

    cmp pProcess32Next, 0
    je ApiError

    invoke SendMessage, hLista, LB_GETSELCOUNT, 0, 0
    mov totalSel, eax

    cmp totalSel, 0
    jg HaySeleccion

    invoke MessageBox, NULL, addr msgSinSeleccion, addr msgTitulo, MB_ICONWARNING
    ret

HaySeleccion:

    invoke SendMessage, hLista, LB_GETSELITEMS, MAX_PROCESOS, addr selected

    mov eax, selected[0]
    mov index, eax

    mov eax, index
    mov eax, pids[eax*4]
    mov pid, eax

    invoke CreateToolhelp32Snapshot, TH32CS_SNAPPROCESS, 0
    mov hSnap, eax

    cmp hSnap, INVALID_HANDLE_VALUE
    je SalirInfo

    invoke RtlZeroMemory, addr pe, SIZEOF PROCESSENTRY32
    mov pe.dwSize, SIZEOF PROCESSENTRY32

    lea eax, pe
    push eax
    push hSnap
    call dword ptr [pProcess32First]
    mov ok, eax

    .while ok != 0

        mov eax, pe.th32ProcessID
        cmp eax, pid
        je Encontrado

        lea eax, pe
        push eax
        push hSnap
        call dword ptr [pProcess32Next]
        mov ok, eax

    .endw

    jmp CerrarInfo

Encontrado:

    invoke ObtenerMemoriaKB, pid
    mov memKB, eax

    invoke ObtenerCpuMs, pid
    mov cpuMs, eax

    invoke wsprintf, addr infoBuffer, addr fmtInfo,\
           addr pe.szExeFile,\
           pe.th32ProcessID,\
           pe.th32ParentProcessID,\
           pe.cntThreads,\
           pe.pcPriClassBase,\
           memKB,\
           cpuMs

    invoke MessageBox, NULL, addr infoBuffer, addr msgTitulo, MB_OK

CerrarInfo:
    invoke CloseHandle, hSnap

SalirInfo:
    ret

ApiError:
    invoke MessageBox, NULL, addr msgApiError, addr msgTitulo, MB_ICONERROR
    ret

MostrarInfo endp

LimpiarSeleccion proc
    invoke SendMessage, hLista, LB_SETSEL, FALSE, -1
    ret
LimpiarSeleccion endp

SeleccionarTodos proc
    invoke SendMessage, hLista, LB_SETSEL, TRUE, -1
    ret
SeleccionarTodos endp

ToggleAutoRefresh proc hwnd:DWORD

    .if autoRefresh == 0
        mov autoRefresh, 1
        invoke SetTimer, hwnd, ID_TIMER_AUTO, 3000, NULL
        invoke MessageBox, hwnd, addr msgAutoOn, addr msgTitulo, MB_OK or MB_ICONINFORMATION
    .else
        mov autoRefresh, 0
        invoke KillTimer, hwnd, ID_TIMER_AUTO
        invoke MessageBox, hwnd, addr msgAutoOff, addr msgTitulo, MB_OK or MB_ICONINFORMATION
    .endif

    ret

ToggleAutoRefresh endp

ObtenerMemoriaKB proc pid:DWORD

    LOCAL hProc:DWORD
    LOCAL pmc:PROCESS_MEMORY_COUNTERS_LOCAL

    invoke OpenProcess, PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, FALSE, pid
    mov hProc, eax

    cmp hProc, 0
    jne MemOk

    xor eax, eax
    ret

MemOk:
    invoke RtlZeroMemory, addr pmc, SIZEOF PROCESS_MEMORY_COUNTERS_LOCAL
    mov pmc.cb, SIZEOF PROCESS_MEMORY_COUNTERS_LOCAL

    invoke GetProcessMemoryInfo, hProc, addr pmc, SIZEOF PROCESS_MEMORY_COUNTERS_LOCAL
    cmp eax, 0
    je MemError

    mov eax, pmc.WorkingSetSize
    shr eax, 10
    push eax
    invoke CloseHandle, hProc
    pop eax
    ret

MemError:
    invoke CloseHandle, hProc
    xor eax, eax
    ret

ObtenerMemoriaKB endp

ObtenerCpuMs proc pid:DWORD

    LOCAL hProc:DWORD
    LOCAL ftCreate:FILETIME
    LOCAL ftExit:FILETIME
    LOCAL ftKernel:FILETIME
    LOCAL ftUser:FILETIME

    invoke OpenProcess, PROCESS_QUERY_INFORMATION, FALSE, pid
    mov hProc, eax

    cmp hProc, 0
    jne CpuOk

    xor eax, eax
    ret

CpuOk:
    invoke GetProcessTimes, hProc, addr ftCreate, addr ftExit, addr ftKernel, addr ftUser
    cmp eax, 0
    je CpuError

    ; Conversion aproximada:
    ; FILETIME trabaja en unidades de 100 ns.
    ; Se suman las partes bajas de kernel + user y se divide entre 10000
    ; para obtener milisegundos aproximados.
    mov eax, ftKernel.dwLowDateTime
    add eax, ftUser.dwLowDateTime
    xor edx, edx
    mov ecx, 10000
    div ecx
    push eax
    invoke CloseHandle, hProc
    pop eax
    ret

CpuError:
    invoke CloseHandle, hProc
    xor eax, eax
    ret

ObtenerCpuMs endp

HabilitarDebugPrivilege proc

    LOCAL hToken:DWORD
    LOCAL luid:LUID
    LOCAL tp:TOKEN_PRIVILEGES

    invoke OpenProcessToken, -1, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, addr hToken
    cmp eax, 0
    jne TokenOk
    ret

TokenOk:
    invoke LookupPrivilegeValue, NULL, addr debugPrivilegeName, addr luid
    cmp eax, 0
    jne LuidOk
    invoke CloseHandle, hToken
    ret

LuidOk:
    mov tp.PrivilegeCount, 1
    mov eax, luid.LowPart
    mov tp.Privileges[0].Luid.LowPart, eax
    mov eax, luid.HighPart
    mov tp.Privileges[0].Luid.HighPart, eax
    mov tp.Privileges[0].Attributes, SE_PRIVILEGE_ENABLED

    invoke AdjustTokenPrivileges, hToken, FALSE, addr tp, SIZEOF TOKEN_PRIVILEGES, NULL, NULL
    invoke CloseHandle, hToken
    ret

HabilitarDebugPrivilege endp

end start