# WhatsApp API Campaigns

Esta funcionalidad permite a los usuarios de Chatwoot crear y gestionar campañas de WhatsApp utilizando APIs personalizadas como Evolution API, en lugar del canal oficial de WhatsApp Business.

## Características Principales

- **Campañas Programadas**: Envío de mensajes masivos en horarios específicos
- **Limitación de Velocidad**: Respeta límites de 12 mensajes por minuto para evitar bloqueos
- **Soporte Multimedia**: Envío de imágenes, documentos y otros archivos
- **Segmentación de Audiencia**: Filtrado por contactos, etiquetas y atributos personalizados
- **Estadísticas de Entrega**: Seguimiento detallado de envíos, entregas y fallos
- **Gestión de Errores**: Reintentos automáticos y manejo robusto de errores

## Arquitectura

### Modelos

#### WhatsappApiCampaign
- **Propósito**: Modelo principal que representa una campaña de WhatsApp API
- **Campos Principales**:
  - `title`: Título descriptivo de la campaña
  - `message`: Contenido del mensaje a enviar
  - `audience`: Criterios de segmentación (JSON)
  - `scheduled_at`: Fecha y hora de ejecución
  - `status`: Estado de la campaña (pending, running, completed, failed)
  - `multimedia`: Configuración de archivos multimedia (JSON)
  - `delivery_stats`: Estadísticas de entrega (JSON)
  - `sender_id`: Usuario que creó la campaña

### Controladores

#### WhatsappApiCampaignsController
- **Ruta Base**: `/api/v1/accounts/:account_id/whatsapp_api_campaigns`
- **Endpoints**:
  - `GET /` - Listar campañas
  - `GET /:id` - Mostrar campaña específica
  - `POST /` - Crear nueva campaña
  - `PATCH /:id` - Actualizar campaña
  - `DELETE /:id` - Eliminar campaña
  - `POST /:id/trigger` - Ejecutar campaña manualmente

### Jobs (Trabajos en Segundo Plano)

#### CampaignExecutorJob
- **Propósito**: Ejecuta una campaña completa
- **Funcionalidades**:
  - Obtiene contactos según criterios de audiencia
  - Programa envíos individuales con limitación de velocidad
  - Programa verificación de finalización

#### SendMessageJob
- **Propósito**: Envía un mensaje individual a un contacto
- **Funcionalidades**:
  - Construye payload para API externa
  - Maneja reintentos automáticos
  - Actualiza estadísticas de entrega
  - Crea conversaciones y mensajes en Chatwoot

#### CampaignCompletionJob
- **Propósito**: Verifica y marca campañas como completadas
- **Funcionalidades**:
  - Verifica si todos los mensajes fueron procesados
  - Envía notificaciones de finalización
  - Programa verificaciones adicionales si es necesario

#### CampaignSchedulerJob
- **Propósito**: Job recurrente que ejecuta campañas programadas
- **Ejecución**: Debe ejecutarse cada minuto vía cron

### Servicios

#### CampaignSchedulerService
- **Propósito**: Lógica de negocio para programación automática
- **Funcionalidades**:
  - Identifica campañas listas para ejecución
  - Maneja errores de programación
  - Registra actividad en logs

## Configuración

### Feature Flag
```yaml
whatsapp_api_campaigns:
  display_name: "WhatsApp API Campaigns"
  enabled: false
  description: "Enable WhatsApp API campaigns for custom API providers like Evolution API"
```

### Credenciales de API
Las credenciales se almacenan en el campo `additional_attributes` del Canal API:

```json
{
  "whatsapp_api_credentials": {
    "base_url": "https://api.evolution.com",
    "token": "your_api_token",
    "instance_name": "your_instance_name"
  }
}
```

### Configuración de Cron
Para ejecutar el programador automáticamente:

```bash
# Ejecutar cada minuto
* * * * * cd /path/to/chatwoot && bundle exec rails runner "WhatsappApi::CampaignSchedulerJob.perform_later"
```

## Segmentación de Audiencia

### Por IDs de Contacto
```json
{
  "contact_ids": [1, 2, 3, 4, 5]
}
```

### Por Etiquetas
```json
{
  "labels": ["vip", "newsletter", "premium"]
}
```

### Por Atributos Personalizados
```json
{
  "custom_attributes": {
    "subscription_type": "premium",
    "region": "north_america",
    "active": true
  }
}
```

### Combinación de Criterios
```json
{
  "contact_ids": [1, 2, 3],
  "labels": ["vip"],
  "custom_attributes": {
    "subscription_type": "premium"
  }
}
```

## Multimedia

### Configuración de Imagen
```json
{
  "type": "image",
  "url": "https://example.com/image.jpg",
  "filename": "campaign_image.jpg"
}
```

### Configuración de Documento
```json
{
  "type": "document",
  "url": "https://example.com/document.pdf",
  "filename": "campaign_document.pdf"
}
```

## API Externa (Evolution API)

### Endpoint para Texto
```
POST {base_url}/message/sendText/{instance_name}
Headers:
  Content-Type: application/json
  apikey: {token}

Body:
{
  "number": "+1234567890",
  "text": "Mensaje de la campaña"
}
```

### Endpoint para Multimedia
```
POST {base_url}/message/sendMedia/{instance_name}
Headers:
  Content-Type: application/json
  apikey: {token}

Body:
{
  "number": "+1234567890",
  "mediatype": "image",
  "media": "https://example.com/image.jpg",
  "fileName": "image.jpg",
  "caption": "Mensaje de la campaña"
}
```

## Limitaciones y Consideraciones

### Limitación de Velocidad
- **Límite**: 12 mensajes por minuto
- **Implementación**: Delay de 5 segundos entre mensajes
- **Propósito**: Evitar bloqueos por parte de WhatsApp

### Manejo de Errores
- **4xx**: No se reintenta (error del cliente)
- **5xx**: Se reintenta automáticamente (error del servidor)
- **Timeout**: Se reintenta automáticamente

### Seguridad
- Las credenciales se almacenan en la base de datos (no encriptadas)
- Validación de permisos por cuenta
- Feature flag para control de acceso

## Testing

### Ejecutar Tests
```bash
# Tests del modelo
bundle exec rspec spec/models/whatsapp_api_campaign_spec.rb

# Tests del controlador
bundle exec rspec spec/controllers/api/v1/accounts/whatsapp_api_campaigns_controller_spec.rb

# Tests de jobs
bundle exec rspec spec/jobs/whatsapp_api/

# Tests de servicios
bundle exec rspec spec/services/whatsapp_api/
```

### Factories
Utiliza FactoryBot para crear datos de prueba:

```ruby
# Campaña básica
campaign = create(:whatsapp_api_campaign)

# Campaña con contactos
campaign = create(:whatsapp_api_campaign, :with_contacts, contact_count: 5)

# Campaña con multimedia
campaign = create(:whatsapp_api_campaign, :with_multimedia_image)
```

## Monitoreo y Logs

### Logs Importantes
- Ejecución de campañas
- Errores de API externa
- Estadísticas de entrega
- Fallos de programación

### Métricas Recomendadas
- Tasa de éxito de campañas
- Tiempo promedio de ejecución
- Errores por tipo
- Volumen de mensajes por hora

## Próximos Pasos

### Fase 2: Backend - Provider Integration ✅
- [x] Servicio de envío
- [x] Programador/cola con limitación de velocidad
- [x] Manejador de webhooks
- [x] Seguimiento de métricas

### Fase 3: Frontend
- [ ] Store de Vuex/Pinia dedicado
- [ ] Página y componentes
- [ ] Rutas e i18n
- [ ] Integración con API

### Fase 4: QA y Documentación
- [ ] Tests E2E
- [ ] Validación de rendimiento
- [ ] Documentación técnica completa

## Soporte

Para preguntas o problemas relacionados con esta funcionalidad, consulta:
- Logs de la aplicación
- Tests unitarios como documentación
- Código fuente en `app/models/whatsapp_api_campaign.rb`
- Controlador en `app/controllers/api/v1/accounts/whatsapp_api_campaigns_controller.rb`