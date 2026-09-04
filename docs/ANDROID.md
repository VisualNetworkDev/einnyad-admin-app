# Android

## APK de prueba

```powershell
flutter pub get
flutter test
flutter build apk --debug
```

Instalar con ADB:

```powershell
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

## Release definitivo

La llave de producción ya existe: `android/app/einnyad-release.jks`, con configuración privada en `android/key.properties`. No generar otra llave ni incluir estos archivos en GitHub. Todas las actualizaciones deben conservar esta firma.

Después:

```powershell
flutter build apk --release
```

No distribuyas una versión firmada con la llave debug como versión oficial.

## Actualización interna

La app descarga el APK indicado en el manifiesto, comprueba el SHA-256 cuando se proporciona y abre el instalador de Android. Android siempre solicita confirmación y puede pedir activar “Instalar apps desconocidas” para EinnyadNails Admin.

## Acceso rápido desde 1.0.4

1. Configurar una huella en los ajustes de seguridad del teléfono.
2. Entrar con el correo y la contraseña habituales y marcar “Activar acceso rápido en este teléfono”.
3. Confirmar la huella en el diálogo de Android. El correo y la contraseña se guardan cifrados con una llave Android Keystore que requiere biometría para cada lectura.
4. Al volver a abrir la app desde cero o después de cerrar sesión, pulsar “Entrar con huella o rostro”. El backend sigue validando el acceso; requiere internet.

Se acepta huella o reconocimiento facial clasificado por Android como biometría fuerte (Class 3). No todos los teléfonos admiten su desbloqueo facial para proteger claves. En esos casos se usa la huella; siempre queda disponible la contraseña del negocio. Esta versión no agrega Face ID a iOS.

“Quitar acceso rápido” elimina las credenciales biométricas y la sesión local. Cambiar la biometría del teléfono puede invalidar la llave y requerir activar el acceso otra vez. Las credenciales cifradas no se incluyen en copias de seguridad del sistema. La sesión ordinaria de notificaciones permanece separada de la llave biométrica.

## Errores temporales al entrar

La app distingue acceso rechazado de un fallo al cargar el panel. Un 404 temporal no borra una sesión válida. Se reintenta una respuesta GET redirigida por Apps Script y, si hace falta, la lectura de datos. No se reenvían automáticamente escrituras, reservas ni el POST de login. Un error persistente muestra una pantalla para reintentar sin volver a escribir la contraseña.
