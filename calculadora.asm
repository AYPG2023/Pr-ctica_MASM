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
WndProc  proto :DWORD,:DWORD,:DWORD,:DWORD
Calcular proto :DWORD

IDC_NUM1      equ 1001
IDC_NUM2      equ 1002
IDC_RESULT    equ 1003

BTN_SUMAR     equ 2001
BTN_RESTAR    equ 2002
BTN_MULT      equ 2003
BTN_DIV       equ 2004

COLOR_FONDO   equ 002A1B0Fh
COLOR_TEXTO   equ 00FFFFFFh
COLOR_PANEL   equ 003B2A1Ah

.data
ClassName db "CalculadoraMASM",0
AppName   db "Calculadora Aritmetica - MASM",0

titulo    db "CALCULADORA MASM32",0
lblNum1   db "Numero 1:",0
lblNum2   db "Numero 2:",0
lblRes    db "Resultado:",0

btnSumar  db "SUMAR",0
btnRestar db "RESTAR",0
btnMult   db "MULTIPLICAR",0
btnDiv    db "DIVIDIR",0

editClass db "EDIT",0
btnClass  db "BUTTON",0
statClass db "STATIC",0

msgErrorCampos db "Ingrese ambos numeros.",0
msgDivCero     db "No se puede dividir entre cero.",0
msgTitulo      db "Aviso",0

fmtDecimal db "%d",0

fontName db "Segoe UI",0

buffer1   db 32 dup(0)
buffer2   db 32 dup(0)
bufferRes db 64 dup(0)

.data?
hInstance HINSTANCE ?
hNum1     HWND ?
hNum2     HWND ?
hResult   HWND ?
hFont     HFONT ?
hFontBig  HFONT ?
hBrushBg  HBRUSH ?

.code

start:
    invoke GetModuleHandle, NULL
    mov hInstance, eax

    invoke WinMain, hInstance, NULL, NULL, SW_SHOWDEFAULT
    invoke ExitProcess, eax

WinMain proc hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD

    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG
    LOCAL hwnd:HWND

    invoke CreateSolidBrush, COLOR_FONDO
    mov hBrushBg, eax

    invoke CreateFont, 20,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,\
           DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,\
           DEFAULT_QUALITY,DEFAULT_PITCH or FF_DONTCARE, addr fontName
    mov hFont, eax

    invoke CreateFont, 26,0,0,0,FW_BOLD,FALSE,FALSE,FALSE,\
           DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,\
           DEFAULT_QUALITY,DEFAULT_PITCH or FF_DONTCARE, addr fontName
    mov hFontBig, eax

    mov wc.cbSize, SIZEOF WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, OFFSET WndProc
    mov wc.cbClsExtra, NULL
    mov wc.cbWndExtra, NULL

    push hInst
    pop wc.hInstance

    mov wc.hbrBackground, eax
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, OFFSET ClassName

    invoke LoadIcon, NULL, IDI_APPLICATION
    mov wc.hIcon, eax
    mov wc.hIconSm, eax

    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax

    invoke RegisterClassEx, addr wc

    invoke CreateWindowEx, NULL, addr ClassName, addr AppName,\
           WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX,\
           CW_USEDEFAULT, CW_USEDEFAULT, 460, 360,\
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

    LOCAL hdc:HDC
    LOCAL ps:PAINTSTRUCT
    LOCAL rect:RECT

    .if uMsg == WM_CREATE

        invoke CreateWindowEx, NULL, addr statClass, addr titulo,\
               WS_CHILD or WS_VISIBLE or SS_CENTER,\
               40, 25, 360, 35,\
               hwnd, NULL, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFontBig, TRUE

        invoke CreateWindowEx, NULL, addr statClass, addr lblNum1,\
               WS_CHILD or WS_VISIBLE,\
               55, 85, 100, 25,\
               hwnd, NULL, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, WS_EX_CLIENTEDGE, addr editClass, NULL,\
               WS_CHILD or WS_VISIBLE or WS_BORDER or ES_AUTOHSCROLL,\
               170, 80, 220, 32,\
               hwnd, IDC_NUM1, hInstance, NULL
        mov hNum1, eax
        invoke SendMessage, hNum1, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr statClass, addr lblNum2,\
               WS_CHILD or WS_VISIBLE,\
               55, 130, 100, 25,\
               hwnd, NULL, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, WS_EX_CLIENTEDGE, addr editClass, NULL,\
               WS_CHILD or WS_VISIBLE or WS_BORDER or ES_AUTOHSCROLL,\
               170, 125, 220, 32,\
               hwnd, IDC_NUM2, hInstance, NULL
        mov hNum2, eax
        invoke SendMessage, hNum2, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnSumar,\
               WS_CHILD or WS_VISIBLE,\
               55, 180, 160, 38,\
               hwnd, BTN_SUMAR, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnRestar,\
               WS_CHILD or WS_VISIBLE,\
               230, 180, 160, 38,\
               hwnd, BTN_RESTAR, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnMult,\
               WS_CHILD or WS_VISIBLE,\
               55, 230, 160, 38,\
               hwnd, BTN_MULT, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr btnClass, addr btnDiv,\
               WS_CHILD or WS_VISIBLE,\
               230, 230, 160, 38,\
               hwnd, BTN_DIV, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, NULL, addr statClass, addr lblRes,\
               WS_CHILD or WS_VISIBLE,\
               55, 292, 100, 25,\
               hwnd, NULL, hInstance, NULL
        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        invoke CreateWindowEx, WS_EX_CLIENTEDGE, addr editClass, NULL,\
               WS_CHILD or WS_VISIBLE or WS_BORDER or ES_READONLY or ES_CENTER,\
               170, 285, 220, 35,\
               hwnd, IDC_RESULT, hInstance, NULL
        mov hResult, eax
        invoke SendMessage, hResult, WM_SETFONT, hFontBig, TRUE

    .elseif uMsg == WM_CTLCOLORSTATIC

        invoke SetTextColor, wParam, COLOR_TEXTO
        invoke SetBkColor, wParam, COLOR_FONDO
        mov eax, hBrushBg
        ret

    .elseif uMsg == WM_CTLCOLOREDIT

        invoke SetTextColor, wParam, 00000000h
        invoke SetBkColor, wParam, 00FFFFFFh
        invoke GetStockObject, WHITE_BRUSH
        ret

    .elseif uMsg == WM_COMMAND

        mov eax, wParam
        and eax, 0FFFFh

        .if eax == BTN_SUMAR
            invoke Calcular, 1
        .elseif eax == BTN_RESTAR
            invoke Calcular, 2
        .elseif eax == BTN_MULT
            invoke Calcular, 3
        .elseif eax == BTN_DIV
            invoke Calcular, 4
        .endif

    .elseif uMsg == WM_DESTROY

        invoke DeleteObject, hFont
        invoke DeleteObject, hFontBig
        invoke DeleteObject, hBrushBg
        invoke PostQuitMessage, NULL

    .else

        invoke DefWindowProc, hwnd, uMsg, wParam, lParam
        ret

    .endif

    xor eax, eax
    ret

WndProc endp

Calcular proc operacion:DWORD

    LOCAL num1:DWORD
    LOCAL num2:DWORD
    LOCAL resultado:DWORD

    invoke GetWindowText, hNum1, addr buffer1, SIZEOF buffer1
    cmp eax, 0
    je CamposVacios

    invoke GetWindowText, hNum2, addr buffer2, SIZEOF buffer2
    cmp eax, 0
    je CamposVacios

    invoke atodw, addr buffer1
    mov num1, eax

    invoke atodw, addr buffer2
    mov num2, eax

    mov eax, operacion

    .if eax == 1

        mov eax, num1
        add eax, num2
        mov resultado, eax

    .elseif eax == 2

        mov eax, num1
        sub eax, num2
        mov resultado, eax

    .elseif eax == 3

        mov eax, num1
        imul num2
        mov resultado, eax

    .elseif eax == 4

        cmp num2, 0
        je DivisionCero

        mov eax, num1
        cdq
        idiv num2
        mov resultado, eax

    .endif

    invoke wsprintf, addr bufferRes, addr fmtDecimal, resultado
    invoke SetWindowText, hResult, addr bufferRes
    ret

CamposVacios:
    invoke MessageBox, NULL, addr msgErrorCampos, addr msgTitulo, MB_ICONWARNING
    ret

DivisionCero:
    invoke MessageBox, NULL, addr msgDivCero, addr msgTitulo, MB_ICONERROR
    ret

Calcular endp

end start