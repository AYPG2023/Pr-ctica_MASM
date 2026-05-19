.386
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc
include \masm32\include\masm32.inc

includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib
includelib \masm32\lib\gdi32.lib
includelib \masm32\lib\masm32.lib

WinMain proto :DWORD,:DWORD,:DWORD,:DWORD
WndProc proto :DWORD,:DWORD,:DWORD,:DWORD
CargarProcesos proto
TerminarSeleccionados proto
CambiarPrioridad proto :DWORD
MostrarInfo proto
LimpiarSeleccion proto

IDC_LISTA       equ 1001

BTN_ACTUALIZAR equ 2001
BTN_FINALIZAR  equ 2002
BTN_ALTA       equ 2003
BTN_NORMAL     equ 2004
BTN_INFO       equ 2005
BTN_LIMPIAR    equ 2006

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
btnInfo       db "Ver informacion",0
btnLimpiar    db "Limpiar seleccion",0

msgTitulo db "Administrador de procesos",0
msgConfirmar db "Desea finalizar los procesos seleccionados?",0
msgSinSeleccion db "Debe seleccionar al menos un proceso.",0
msgFinalizado db "Operacion realizada. Actualizando lista.",0
msgPrioridad db "Prioridad modificada correctamente.",0
msgError db "No se pudo realizar la operacion. Ejecute como administrador si es necesario.",0
msgApiError db "No se pudieron cargar las funciones Process32FirstA/Process32NextA.",0

fmtProceso db "PID: %u   |   %s",0

fmtInfo db "Nombre del proceso: %s",13,10
        db "PID: %u",13,10
        db "ID padre: %u",13,10
        db "Threads: %u",13,10
        db "Prioridad base: %u",0

fmtTotal db "Total de procesos: %u",0

fontName db "Segoe UI",0

buffer db 260 dup(0)
infoBuffer db 512 dup(0)
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

.code

start:
    invoke GetModuleHandle, NULL
    mov hInstance, eax

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
           CW_USEDEFAULT, CW_USEDEFAULT, 760, 540,\
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
               20, 20, 700, 35,\
               hwnd, NULL, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFontTitle, TRUE

        invoke CreateWindowEx, NULL, addr statClass, addr lblProcesos,\
               WS_CHILD or WS_VISIBLE,\
               30, 70, 250, 25,\
               hwnd, NULL, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, WS_EX_CLIENTEDGE, addr listClass, NULL,\
               WS_CHILD or WS_VISIBLE or WS_VSCROLL or LBS_EXTENDEDSEL or LBS_NOTIFY,\
               30, 100, 480, 340,\
               hwnd, IDC_LISTA, hInstance, NULL
        mov hLista, eax
        invoke SendMessage, hLista, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnActualizar,\
               WS_CHILD or WS_VISIBLE,\
               540, 100, 170, 35,\
               hwnd, BTN_ACTUALIZAR, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnInfo,\
               WS_CHILD or WS_VISIBLE,\
               540, 145, 170, 35,\
               hwnd, BTN_INFO, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnFinalizar,\
               WS_CHILD or WS_VISIBLE,\
               540, 190, 170, 35,\
               hwnd, BTN_FINALIZAR, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnAlta,\
               WS_CHILD or WS_VISIBLE,\
               540, 235, 170, 35,\
               hwnd, BTN_ALTA, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnNormal,\
               WS_CHILD or WS_VISIBLE,\
               540, 280, 170, 35,\
               hwnd, BTN_NORMAL, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnLimpiar,\
               WS_CHILD or WS_VISIBLE,\
               540, 325, 170, 35,\
               hwnd, BTN_LIMPIAR, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr statClass, NULL,\
               WS_CHILD or WS_VISIBLE,\
               30, 455, 400, 25,\
               hwnd, NULL, hInstance, NULL
        mov hTotal, eax
        invoke SendMessage, hTotal, WM_SETFONT, hFont, TRUE

        invoke CargarProcesos

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

        .elseif eax == BTN_INFO
            invoke MostrarInfo

        .elseif eax == BTN_LIMPIAR
            invoke LimpiarSeleccion

        .endif

    .elseif uMsg == WM_CTLCOLORSTATIC

        invoke SetBkColor, wParam, 00F0F0F0h
        invoke SetTextColor, wParam, 00000000h
        mov eax, hBrush
        ret

    .elseif uMsg == WM_DESTROY

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

        invoke wsprintf, addr buffer, addr fmtProceso, pe.th32ProcessID, addr pe.szExeFile
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

    mov eax, selected[0]
    mov index, eax

    mov eax, index
    mov eax, pids[eax*4]
    mov pid, eax

    invoke OpenProcess, PROCESS_SET_INFORMATION, FALSE, pid
    mov hProc, eax

    cmp hProc, 0
    je ErrorPrioridad

    invoke SetPriorityClass, hProc, prioridad
    invoke CloseHandle, hProc

    invoke MessageBox, NULL, addr msgPrioridad, addr msgTitulo, MB_OK
    ret

ErrorPrioridad:
    invoke MessageBox, NULL, addr msgError, addr msgTitulo, MB_ICONERROR
    ret

CambiarPrioridad endp

MostrarInfo proc

    LOCAL totalSel:DWORD
    LOCAL index:DWORD
    LOCAL pid:DWORD
    LOCAL pe:PROCESSENTRY32
    LOCAL hSnap:DWORD
    LOCAL ok:DWORD

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

    invoke wsprintf, addr infoBuffer, addr fmtInfo,\
           addr pe.szExeFile,\
           pe.th32ProcessID,\
           pe.th32ParentProcessID,\
           pe.cntThreads,\
           pe.pcPriClassBase

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

end start