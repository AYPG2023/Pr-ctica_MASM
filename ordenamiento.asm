.386
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\masm32.inc

includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\masm32.lib

OrdenarVector proto

.data
titulo db "VECTOR ORDENADO:",13,10,0
salto  db 13,10,0

vector db 'c','a','d','e','b',0

.code

start:

    invoke StdOut, addr titulo

    call OrdenarVector

    invoke StdOut, addr vector
    invoke StdOut, addr salto

    invoke ExitProcess, 0

OrdenarVector proc

    LOCAL i:DWORD
    LOCAL j:DWORD

    mov i, 0

OuterLoop:

    mov j, 0

InnerLoop:

    mov eax, j

    mov dl, vector[eax]
    mov bl, vector[eax+1]

    cmp dl, bl
    jbe NoSwap

    mov vector[eax], bl
    mov vector[eax+1], dl

NoSwap:

    inc j
    cmp j, 4
    jl InnerLoop

    inc i
    cmp i, 4
    jl OuterLoop

    ret

OrdenarVector endp

end start