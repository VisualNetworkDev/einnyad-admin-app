# Recuperación Android 1.0.5 (6)

Fecha: 2026-09-04.

## Base comprobada

Esta versión se creó en la rama `restore-1.0.3-with-biometric` directamente desde la etiqueta publicada `v1.0.3`, commit `015c59bb6d583c8dc54a19226e33cc5db032af26`.

- La base contiene 115 archivos controlados y las 8 pantallas originales.
- No se eliminó ningún archivo de 1.0.3.
- Permanecen idénticos a 1.0.3: `AdminShell`, citas, resumen, QR, reseñas, servicios, ajustes, notificaciones, actualizador, widgets, tema y recursos.
- Solo se modificaron los archivos necesarios para integrar el acceso rápido Android y el número de versión.
- `Admin API.gs`, `Client API.gs` y los HTML no se modificaron ni desplegaron.

## Función nueva

Después de un login normal correcto, la dueña puede activar “Acceso rápido”. Android cifra el correo y la contraseña con Android Keystore; cada lectura requiere huella o un reconocimiento facial que Android clasifique como biometría fuerte. La contraseña normal continúa disponible.

La app conserva el comportamiento de sesión de 1.0.3: si existe una sesión válida, abre directamente el panel. Después de cerrar sesión, se puede entrar rápidamente con biometría; el backend vuelve a validar las credenciales.

## Validación

- `flutter analyze`: sin incidencias.
- `flutter test`: 21 pruebas aprobadas, incluyendo todas las pruebas de 1.0.3, conservación de datos/pantallas, login biométrico, cancelación sin llamar al backend y diseño estrecho.
- `flutter build apk --release`: correcto.
- Firma APK verificada: certificado SHA-256 `729f0e384bfb2ea47a3640dcb9d77383f3d9d1a27f75ad581a2438e3a3b1a316`, igual que 1.0.3.
- APK SHA-256: `f9928e5bd731936f8a862eb667cdbc894d1cc190d7139ebf608c5f8a4df1d4cd`.

No había emulador ni teléfono conectado durante esta recuperación. La compilación y las pruebas automáticas sí están verificadas; la instalación y la biometría física quedan para la prueba manual del usuario.
