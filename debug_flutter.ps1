#!/usr/bin/env pwsh

# Script de Debug para Flutter App
# Uso: .\debug_flutter.ps1

Write-Host "🔧 Herramienta de Debug para Flutter App" -ForegroundColor Green
Write-Host "═══════════════════════════════════════" -ForegroundColor Green
Write-Host ""

$options = @(
    "1. Limpiar y Reconstruir (flutter clean)",
    "2. Obtener Dependencias (flutter pub get)",
    "3. Ejecutar con Logs Detallados (flutter run -v)",
    "4. Ver Logs en Tiempo Real (flutter logs)",
    "5. Limpiar Cache Gradle (Android)",
    "6. Ejecutar Todo (1+2+3)",
    "7. Salir"
)

foreach ($option in $options) {
    Write-Host $option
}

Write-Host ""
$choice = Read-Host "Selecciona una opción (1-7)"

switch ($choice) {
    "1" {
        Write-Host "🧹 Limpiando..." -ForegroundColor Yellow
        flutter clean
        Write-Host "✅ Limpeza completada" -ForegroundColor Green
    }
    "2" {
        Write-Host "📦 Obtieniendo dependencias..." -ForegroundColor Yellow
        flutter pub get
        Write-Host "✅ Dependencias obtenidas" -ForegroundColor Green
    }
    "3" {
        Write-Host "🚀 Ejecutando con logs detallados..." -ForegroundColor Yellow
        flutter run -v
    }
    "4" {
        Write-Host "👀 Viendo logs en tiempo real..." -ForegroundColor Yellow
        Write-Host "Presiona Ctrl+C para detener" -ForegroundColor Gray
        flutter logs
    }
    "5" {
        Write-Host "🧹 Limpiando Gradle..." -ForegroundColor Yellow
        Set-Location android
        ./gradlew clean
        Set-Location ..
        Write-Host "✅ Gradle limpiado" -ForegroundColor Green
    }
    "6" {
        Write-Host "🔄 Ejecutando secuencia completa..." -ForegroundColor Yellow
        Write-Host "1️⃣  Limpiando..." -ForegroundColor Cyan
        flutter clean
        Write-Host "2️⃣  Obteniendo dependencias..." -ForegroundColor Cyan
        flutter pub get
        Write-Host "3️⃣  Ejecutando..." -ForegroundColor Cyan
        flutter run -v
    }
    "7" {
        Write-Host "👋 Hasta luego" -ForegroundColor Green
        exit
    }
    default {
        Write-Host "❌ Opción no válida" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════" -ForegroundColor Green
Write-Host "✨ Script completado" -ForegroundColor Green
