# iPhone sin comprar una Mac: GitHub Actions y AltStore

## Resultado

Este proyecto usa el mismo metodo de GNZ Admin Pro y Payment Organizer:

1. Desde Windows se publica el proyecto en `VisualNetworkDev/einnyad-admin-app`.
2. GitHub Actions presta temporalmente un equipo `macos-latest` y genera un IPA sin firma.
3. Descargas el IPA en Windows.
4. AltStore Classic y AltServer lo firman localmente con tu cuenta gratuita de Apple y lo instalan en el iPhone.

No necesitas comprar ni tener una Mac. Este flujo es para instalacion privada; no publica la aplicacion en App Store ni en TestFlight.

Apps Script no forma parte de este repositorio y su deployment queda manual. El workflow movil no guarda credenciales de la duena.

## Identidad de la app

- Nombre: `EinnyadNails Admin`
- Bundle ID: `com.visualnetworkdev.einnyadAdminMobile`
- Version: tomada automaticamente de `pubspec.yaml`
- iOS minimo: 13.0

## Generar el IPA desde Windows

El archivo usado es:

`.github/workflows/build-ios-unsigned.yml`

Para crear una compilacion manual:

1. Abre el repositorio en GitHub.
2. Entra en `Actions`.
3. Selecciona `Crear IPA EinnyadNails para iPhone`.
4. Pulsa `Run workflow`.
5. Confirma la URL publica del Admin API.
6. Si ya publicaste el manifiesto de actualizaciones, escribe su URL HTTPS; de lo contrario, dejala vacia.
7. Espera a que termine el proceso.
8. Descarga el artefacto `EinnyadNails-Admin-iOS-unsigned`.
9. Extrae el ZIP. Contiene `EinnyadNails-Admin-1.0.0.ipa` y su SHA-256.

El Source publico de AltStore es:

`https://raw.githubusercontent.com/VisualNetworkDev/einnyad-admin-app/main/altstore-source.json`

Al publicar una etiqueta como `v1.0.1`, el workflow tambien crea el GitHub Release y actualiza automaticamente el Source y el manifiesto.

El workflow hace automaticamente lo siguiente:

- instala exactamente Flutter 3.44.6;
- ejecuta formato, analisis y pruebas;
- compila iOS en modo release y sin certificados;
- empaqueta `Runner.app` dentro de `Payload`;
- valida bundle ID, nombre, version, ejecutables y arquitectura ARM64;
- entrega el IPA como artefacto durante 14 dias.

No guarda cuentas, contrasenas, certificados ni perfiles de Apple.

## Instalar desde Windows con AltStore Classic

1. Instala iTunes e iCloud desde las descargas enlazadas por AltStore, no desde Microsoft Store.
2. Instala AltServer en Windows y ejecutalo como administrador.
3. Conecta el iPhone por USB, desbloquealo y acepta `Confiar en este ordenador`.
4. Activa la sincronizacion Wi-Fi en iTunes.
5. Desde AltServer, selecciona `Install AltStore` y el iPhone.
6. Introduce la cuenta de Apple solamente en AltServer.
7. En el iPhone, confia en el perfil desde `Ajustes > General > VPN y gestion de dispositivos`.
8. En iOS 16 o posterior, activa `Ajustes > Privacidad y seguridad > Modo de desarrollador`.
9. Pasa el IPA al iPhone y abrelo con AltStore.

Con una cuenta gratuita, la firma suele renovarse cada siete dias. Mantener AltServer abierto y ambos equipos en la misma red permite a AltStore intentar renovarla.

## Actualizaciones desde la aplicacion

La pantalla `Configuracion > Actualizaciones` abre el Source de AltStore configurado. Para publicar una version nueva:

1. Cambia `version` y el numero despues de `+` en `pubspec.yaml`.
2. Genera el nuevo IPA ejecutando manualmente el workflow.
3. Descarga el artefacto y sube el IPA al alojamiento HTTPS elegido por ti.
4. Agrega la version nueva al inicio de `release/altstore-source.example.json`.
5. Actualiza `downloadURL`, `size`, `date` y `sha256`.
6. Publica manualmente el Source JSON y el manifiesto de actualizacion.

La app abre AltStore para confirmar la instalacion; iOS no permite reemplazarse silenciosamente desde dentro de la propia aplicacion.

## Flujo alternativo

`scripts/build-ios-altstore.sh` queda disponible solo si algun dia deseas generar el IPA directamente en macOS. No es necesario para el procedimiento normal desde Windows.
