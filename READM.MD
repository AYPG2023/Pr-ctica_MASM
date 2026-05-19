# Prácticas MASM32 — Desarrollo de Funcionalidades Básicas

## Requisitos

- MASM32 SDK instalado en:
  
```txt
C:\masm32
```

- Windows 10/11
- CMD o Terminal

---

# Ejercicio 1 — Calculadora Aritmética

## Compilar

```bat
\masm32\bin\ml /c /coff calculadora.asm
```

## Linkear

```bat
\masm32\bin\link /SUBSYSTEM:WINDOWS calculadora.obj
```

## Ejecutar

```bat
calculadora.exe
```

---

# Ejercicio 2 — Ordenamiento de Vector

## Compilar

```bat
\masm32\bin\ml /c /coff ordenamiento.asm
```

## Linkear

```bat
\masm32\bin\link /SUBSYSTEM:CONSOLE ordenamiento.obj
```

## Ejecutar

```bat
ordenamiento.exe
```

---

# Ejercicio 3 — Administración de Procesos

## Compilar

```bat
\masm32\bin\ml /c /coff procesos.asm
```

## Linkear

```bat
\masm32\bin\link /SUBSYSTEM:WINDOWS procesos.obj
```

## Ejecutar

```bat
procesos.exe
```