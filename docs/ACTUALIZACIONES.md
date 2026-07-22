# Actualizaciones sin GitHub

La app acepta una URL HTTPS configurable desde `Ajustes > Actualizaciones de la app`. Esa URL devuelve un JSON con Android e iOS.

Usa `release/update-manifest.example.json` como plantilla.

## Android

1. Incrementar `version` en `pubspec.yaml`, por ejemplo `1.0.1+2`.
2. Compilar el APK release con la misma llave de firma usada en la versión anterior.
3. Calcular SHA-256:

```powershell
Get-FileHash .\EinnyadNails-Admin-1.0.1.apk -Algorithm SHA256
```

4. Subir el APK a un servidor HTTPS y actualizar `downloadUrl` y `sha256`.

## iOS

1. Incrementar versión/build.
2. Ejecutar manualmente en GitHub Actions el workflow `Crear IPA EinnyadNails para iPhone`; GitHub usa temporalmente un runner macOS y no necesitas tener una Mac.
3. Subir IPA y actualizar el Source de AltStore.
4. Actualizar el manifiesto general con la URL del Source.

La URL del manifiesto puede cambiarse desde la app, así que no hace falta recompilar solo para cambiar el servidor de descargas.
