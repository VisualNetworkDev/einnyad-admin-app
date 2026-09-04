# Android 1.0.4 (5) — validación

Fecha: 2026-09-03.

- `flutter analyze`: sin incidencias.
- `flutter test`: 36 pruebas aprobadas (API/redirecciones, sesiones, acceso biométrico, notificaciones existentes y diseño adaptable).
- `flutter build apk --release`: correcto.
- APK instalado con `adb install -r` encima de la 1.0.3 en el emulador Android API 36, sin desinstalar ni borrar datos.
- Firma SHA-256: `729f0e384bfb2ea47a3640dcb9d77383f3d9d1a27f75ad581a2438e3a3b1a316` (misma llave de producción).
- SHA-256 APK: `b8197a830e241c5660d947e8cd87d81e42db308cd7b01bbda912152db82053b5`.
- En el emulador: login contra el backend real, activación del acceso biométrico, diálogo nativo de huella, cancelación sin entrar, reinicio de proceso sin saltarse el acceso y entrada por huella hasta el panel real. Huella simulada con el sensor del emulador; no se ha probado en el teléfono físico de la clienta ni con reconocimiento facial físico.
- Revisión visual de login a 1080×2400 / 420 dpi. Pruebas de diseño también a 320×568, 412×915 y 915×412 con texto aumentado.

El usuario pidió publicar y realizar personalmente las pruebas finales. Queda pendiente revisar la persistencia del acceso biométrico después de varios reinicios: durante la prueba del emulador hubo una reapertura sin el acceso rápido activo, cuya causa no quedó confirmada antes de detener las pruebas. No se presenta esta versión como validada completamente en el dispositivo de la clienta.

## Diagnóstico del 404

La versión 1.0.3 también consiguió entrar durante la comprobación; no se pudo reproducir el 404 de la captura de forma persistente. Web y app usan la misma URL Admin API. La ruta móvil obtiene JSON mediante redirección de Apps Script; la web usa un puente HTML.

Se corrigió una debilidad confirmada en el cliente: cualquier error al restaurar sesión, incluso un fallo HTTP temporal, borraba la sesión guardada. Ahora solo se borra por expiración/invalidez explícita o al cerrar/quitar el acceso. Los reintentos no duplican escrituras ni el POST de login. Esto mejora la recuperación, pero no demuestra una causa única del 404 histórico.

## Alcance

No se modificó ni desplegó Apps Script. No se modificó el frontend. Los 8 archivos recuperados del frontend coinciden con el contenido público actual: seis idénticos byte a byte; `admin.html` solo difiere en CRLF/LF y `assets/jsQR.js` en un salto de línea final. La comparación del código backend desplegado sigue pendiente de acceso a sus proyectos exactos.

Las notificaciones conservan su mecanismo anterior. No se generaron reservas ni correos de prueba y no se afirma haber comprobado una notificación nueva en vivo en esta revisión.
