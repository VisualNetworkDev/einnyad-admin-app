# Mejoras aplicadas y limitaciones

## Mejoras aplicadas

- Sesión administrativa en Keychain/Keystore, no en texto plano.
- Todas las llamadas móviles usan POST.
- Imágenes reducidas antes de subir para ahorrar Drive y datos móviles.
- Confirmaciones separadas para completar, cancelar, borrar, limpiar logs/fotos/producción.
- APK verificable por SHA-256 antes de abrir el instalador.
- Formularios desplazables y navegación lateral adaptable.
- Pruebas de layout en 430×932 (iPhone Pro Max), 412×915 (Android grande) y 932×430 horizontal.
- Dropdowns expandidos y formularios reorganizados en una columna para evitar superposición.

## Limitaciones reales

- Windows no ejecuta Xcode localmente, pero el workflow `.github/workflows/build-ios-unsigned.yml` genera el IPA sin firma mediante GitHub Actions, igual que GNZ Admin Pro y Payment Organizer; no hace falta comprar ni tener una Mac.
- AltStore/iOS exige confirmar la actualización fuera de la app.
- La API depende de Apps Script, Google Sheets, Drive y sus cuotas.
- El APK oficial necesita una llave de firma privada estable antes de distribuirse.
- No hay modo offline para editar: la información administrativa siempre se sincroniza con el servidor.

## Próximas mejoras recomendadas

1. Crear cambio de contraseña desde el panel y revocar todas las demás sesiones al usarlo.
2. Rotar la contraseña actual cuando la dueña esté disponible, porque antes estuvo escrita en el código.
3. Agregar notificaciones push para nuevas citas; requiere un servicio adicional y configuración de Apple/Google.
4. Crear reportes por mes y exportación CSV/PDF.
5. Agregar historial de cambios por cita y roles si en el futuro trabaja más de una administradora.
