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

Antes de distribuir la primera versión, crea una llave Android privada y configura `android/key.properties` y el signing config de Gradle. Guarda esa llave en dos lugares seguros: todas las actualizaciones deben firmarse con exactamente la misma llave.

Después:

```powershell
flutter build apk --release
```

No distribuyas una versión firmada con la llave debug como versión oficial.

## Actualización interna

La app descarga el APK indicado en el manifiesto, comprueba el SHA-256 cuando se proporciona y abre el instalador de Android. Android siempre solicita confirmación y puede pedir activar “Instalar apps desconocidas” para EinnyadNails Admin.
