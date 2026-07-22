# Paridad con el admin web

| Área web | App móvil | Acción de API |
|---|---|---|
| Resumen y agenda | Incluida | `getAdminData` |
| Listar y filtrar citas | Incluida | `getAdminData` |
| Crear cita manual | Incluida | `createManualAppointment` |
| Editar cita | Incluida | `updateAppointment` |
| Cambiar estado | Incluida | `updateAppointmentStatus` |
| Cancelar / borrar | Incluida con confirmación | `cancelAppointment`, `deleteAppointment` |
| Reenviar recibo | Incluida | `resendAppointmentReceipt` |
| Verificar QR | Cámara, foto y texto | `verifyAppointmentQr` |
| Llegada / inicio / final | Incluida | `updateQrStage`, `finishAppointment` |
| Extras del recibo | Agregar y remover | `saveAppointmentExtra`, `removeAppointmentExtra` |
| Servicios | Crear, editar, activar/ocultar | `saveService`, `toggleService` |
| Fotos | Principal, antes/después, compresión | POST `uploadImage` |
| Almacenamiento | Analizar y borrar sin uso | `getPhotoStorage`, `deleteUnusedPhotos` |
| Reseñas | Aprobar, pendiente, ocultar | `updateReviewStatus` |
| Negocio y políticas | Incluido | `saveSalonConfig` |
| Pagos / Interac | Incluido | `savePaymentsConfig` |
| Horarios | Incluido | `saveBusinessHours` |
| Bloqueos | Crear y remover | `saveBlockedSlot`, `removeBlockedSlot` |
| Promociones | Crear y actualizar por código | `savePromotion` |
| Recordatorios | Enviar y configurar trigger | `sendRemindersNow`, `setupReminderTrigger` |
| Logs | Ver y limpiar | `getAdminData`, `clearLogs` |
| Limpieza de producción | Incluida con doble advertencia | `cleanProductionData` |
| Actualización | Android APK / iOS AltStore | Manifiesto HTTPS configurable |

La app usa POST para las llamadas administrativas, evitando colocar contraseña o token de sesión en la URL.
