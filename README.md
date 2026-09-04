# EinnyadNails Admin Mobile

Aplicación Flutter nativa para Android y iOS que replica el panel administrativo de EinnyadNails.

## Funciones incluidas

- Login de dueña y sesión guardada en el almacenamiento seguro del sistema.
- Dashboard, métricas, agenda semanal y servicios más pedidos.
- Buscar, filtrar, crear, editar, cancelar y borrar citas.
- Cambiar estados, reenviar recibos y editar datos de pago.
- Escanear QR con cámara, leer QR desde una foto o pegar el token.
- Marcar llegada/inicio, agregar o remover extras, finalizar y enviar recibo.
- Crear, editar, activar y ocultar servicios.
- Subir fotos comprimidas, manejar antes/después y limpiar fotos sin uso.
- Aprobar, dejar pendiente u ocultar reseñas.
- Ajustes del negocio, Interac, horarios, bloqueos, promociones y recordatorios.
- Logs, limpieza de producción y actualización desde la app.

## Verificación local

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

El APK de prueba queda en `build/app/outputs/flutter-apk/app-debug.apk`.

## Documentación

- `docs/PARIDAD-FUNCIONAL.md`
- `docs/ANDROID.md`
- `docs/IOS-ALTSTORE.md`
- `docs/ACTUALIZACIONES.md`
- `docs/MEJORAS-Y-LIMITACIONES.md`

## iPhone desde Windows

El workflow `.github/workflows/build-ios-unsigned.yml` reproduce el procedimiento de GNZ Admin Pro y Payment Organizer: GitHub Actions compila el IPA sin firma en un runner macOS y AltStore/AltServer lo firma e instala desde Windows. Consulta `docs/IOS-ALTSTORE.md`.

El repositorio `VisualNetworkDev/einnyad-admin-app` contiene el codigo movil y el workflow de iOS. Apps Script se mantiene fuera de este repositorio y su deployment sigue siendo manual.
