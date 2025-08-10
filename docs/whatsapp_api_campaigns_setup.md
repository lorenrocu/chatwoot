# Configuración de WhatsApp API Campaigns

Guía paso a paso para configurar y utilizar las campañas de WhatsApp API en Chatwoot.

## Prerrequisitos

1. **Cuenta de Evolution API** (o API compatible)
   - URL base de la API
   - Token de autenticación
   - Nombre de instancia configurada

2. **Chatwoot con Feature Flag Habilitado**
   - Acceso de administrador a la cuenta
   - Feature flag `whatsapp_api_campaigns` activado

## Paso 1: Habilitar Feature Flag

### Opción A: Desde la Interfaz de Administración
1. Ir a **Configuración de Cuenta** → **Features**
2. Buscar "WhatsApp API Campaigns"
3. Activar el toggle

### Opción B: Desde Rails Console
```ruby
# Habilitar para una cuenta específica
account = Account.find(ACCOUNT_ID)
account.enable_features('whatsapp_api_campaigns')

# Habilitar globalmente
InstallationConfig.where(name: 'whatsapp_api_campaigns').first_or_create(
  value: 'true',
  config_type: 'boolean'
)
```

## Paso 2: Crear Canal API

### Desde la Interfaz Web
1. Ir a **Configuración** → **Inboxes**
2. Hacer clic en **Agregar Inbox**
3. Seleccionar **API Channel**
4. Configurar:
   - **Nombre del Inbox**: "WhatsApp API - [Nombre]"
   - **Webhook URL**: Se generará automáticamente
   - **HMAC Token**: Se generará automáticamente

### Desde Rails Console
```ruby
account = Account.find(ACCOUNT_ID)

# Crear canal API
channel = Channel::Api.create!(
  account: account,
  webhook_url: '', # Se generará automáticamente
  additional_attributes: {
    whatsapp_api_credentials: {
      base_url: 'https://api.evolution.com',
      token: 'tu_token_aqui',
      instance_name: 'tu_instancia'
    }
  }
)

# El inbox se crea automáticamente
inbox = channel.inbox
inbox.update!(name: 'WhatsApp API - Evolution')
```

## Paso 3: Configurar Credenciales de API

### Actualizar Credenciales Existentes
```ruby
inbox = Inbox.find(INBOX_ID)
channel = inbox.channel

channel.update!(
  additional_attributes: {
    whatsapp_api_credentials: {
      base_url: 'https://tu-api.evolution.com',
      token: 'tu_token_de_api',
      instance_name: 'nombre_de_tu_instancia'
    }
  }
)
```

### Verificar Configuración
```ruby
inbox = Inbox.find(INBOX_ID)
credentials = inbox.channel.additional_attributes['whatsapp_api_credentials']

puts "Base URL: #{credentials['base_url']}"
puts "Token: #{credentials['token'][0..10]}..."
puts "Instance: #{credentials['instance_name']}"
```

## Paso 4: Configurar Contactos

### Importar Contactos con Números de WhatsApp
```ruby
account = Account.find(ACCOUNT_ID)
inbox = Inbox.find(INBOX_ID)

# Crear contacto
contact = Contact.create!(
  account: account,
  name: 'Juan Pérez',
  email: 'juan@example.com',
  phone_number: '+1234567890'
)

# Crear ContactInbox para el canal API
ContactInbox.create!(
  contact: contact,
  inbox: inbox,
  source_id: '+1234567890' # Número de WhatsApp
)
```

### Importación Masiva
```ruby
account = Account.find(ACCOUNT_ID)
inbox = Inbox.find(INBOX_ID)

contacts_data = [
  { name: 'Juan Pérez', phone: '+1234567890', email: 'juan@example.com' },
  { name: 'María García', phone: '+0987654321', email: 'maria@example.com' },
  # ... más contactos
]

contacts_data.each do |data|
  contact = Contact.create!(
    account: account,
    name: data[:name],
    email: data[:email],
    phone_number: data[:phone]
  )
  
  ContactInbox.create!(
    contact: contact,
    inbox: inbox,
    source_id: data[:phone]
  )
end
```

## Paso 5: Crear Primera Campaña

### Desde Rails Console
```ruby
account = Account.find(ACCOUNT_ID)
inbox = Inbox.find(INBOX_ID)
user = User.find(USER_ID) # Usuario que crea la campaña

# Obtener IDs de contactos
contact_ids = Contact.joins(:contact_inboxes)
                    .where(contact_inboxes: { inbox: inbox })
                    .pluck(:id)

# Crear campaña
campaign = WhatsappApiCampaign.create!(
  account: account,
  inbox: inbox,
  sender: user,
  title: 'Campaña de Prueba',
  message: '¡Hola! Este es un mensaje de prueba desde Chatwoot.',
  audience: { contact_ids: contact_ids },
  scheduled_at: 5.minutes.from_now,
  status: :pending
)

puts "Campaña creada con ID: #{campaign.id}"
puts "Programada para: #{campaign.scheduled_at}"
puts "Contactos objetivo: #{campaign.total_contacts}"
```

### Con Multimedia
```ruby
campaign = WhatsappApiCampaign.create!(
  account: account,
  inbox: inbox,
  sender: user,
  title: 'Campaña con Imagen',
  message: 'Mira esta imagen increíble!',
  audience: { contact_ids: contact_ids },
  multimedia: {
    type: 'image',
    url: 'https://example.com/imagen.jpg',
    filename: 'promocion.jpg'
  },
  scheduled_at: 10.minutes.from_now
)
```

## Paso 6: Configurar Programador Automático

### Opción A: Cron Job
Agregar a crontab:
```bash
# Ejecutar cada minuto
* * * * * cd /path/to/chatwoot && bundle exec rails runner "WhatsappApi::CampaignSchedulerJob.perform_later"
```

### Opción B: Sidekiq Cron (si está disponible)
```ruby
# En config/initializers/sidekiq.rb
Sidekiq::Cron::Job.create(
  name: 'WhatsApp API Campaign Scheduler',
  cron: '* * * * *', # Cada minuto
  class: 'WhatsappApi::CampaignSchedulerJob'
)
```

### Opción C: Ejecución Manual
```ruby
# Ejecutar manualmente el programador
WhatsappApi::CampaignSchedulerService.schedule_pending_campaigns

# O ejecutar una campaña específica
campaign = WhatsappApiCampaign.find(CAMPAIGN_ID)
campaign.trigger!
```

## Paso 7: Monitoreo y Verificación

### Verificar Estado de Campaña
```ruby
campaign = WhatsappApiCampaign.find(CAMPAIGN_ID)

puts "Estado: #{campaign.status}"
puts "Programada para: #{campaign.scheduled_at}"
puts "Estadísticas:"
puts "  - Enviados: #{campaign.delivery_stats['sent']}"
puts "  - Entregados: #{campaign.delivery_stats['delivered']}"
puts "  - Fallidos: #{campaign.delivery_stats['failed']}"
puts "Progreso: #{campaign.completion_percentage}%"
```

### Verificar Logs
```bash
# Logs de Rails
tail -f log/production.log | grep "WhatsApp"

# Logs de Sidekiq (si se usa)
tail -f log/sidekiq.log | grep "WhatsappApi"
```

### Verificar Jobs en Cola
```ruby
# Ver jobs pendientes
Sidekiq::Queue.new('default').select { |job| job.klass.include?('WhatsappApi') }

# Ver jobs programados
Sidekiq::ScheduledSet.new.select { |job| job.klass.include?('WhatsappApi') }
```

## Solución de Problemas

### Problema: Campaña no se ejecuta
**Verificaciones:**
1. Feature flag habilitado
2. Campaña en estado `pending`
3. `scheduled_at` en el pasado
4. Programador ejecutándose

```ruby
# Verificar campañas listas
WhatsappApiCampaign.scheduled_for_execution.count

# Ejecutar manualmente
WhatsappApi::CampaignSchedulerService.schedule_pending_campaigns
```

### Problema: Mensajes no se envían
**Verificaciones:**
1. Credenciales de API correctas
2. ContactInbox existe para el inbox
3. API externa accesible

```ruby
# Verificar credenciales
inbox = Inbox.find(INBOX_ID)
credentials = inbox.channel.additional_attributes['whatsapp_api_credentials']

# Verificar ContactInbox
contact = Contact.find(CONTACT_ID)
contact_inbox = contact.contact_inboxes.find_by(inbox: inbox)
puts "Source ID: #{contact_inbox&.source_id}"

# Test manual de API
require 'net/http'
uri = URI("#{credentials['base_url']}/message/sendText/#{credentials['instance_name']}")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Content-Type'] = 'application/json'
request['apikey'] = credentials['token']
request.body = {
  number: '+1234567890',
  text: 'Test message'
}.to_json

response = http.request(request)
puts "Status: #{response.code}"
puts "Body: #{response.body}"
```

### Problema: Estadísticas no se actualizan
**Verificaciones:**
1. Jobs de completion ejecutándose
2. Callbacks de API funcionando

```ruby
# Verificar jobs de completion
Sidekiq::ScheduledSet.new.select { |job| job.klass == 'WhatsappApi::CampaignCompletionJob' }

# Ejecutar manualmente
campaign = WhatsappApiCampaign.find(CAMPAIGN_ID)
WhatsappApi::CampaignCompletionJob.perform_now(campaign)
```

## Configuración Avanzada

### Personalizar Limitación de Velocidad
```ruby
# En app/jobs/whatsapp_api/campaign_executor_job.rb
# Cambiar RATE_LIMIT_DELAY de 5 a otro valor (segundos)
RATE_LIMIT_DELAY = 10 # 6 mensajes por minuto
```

### Configurar Reintentos
```ruby
# En app/jobs/whatsapp_api/send_message_job.rb
retry_on StandardError, wait: :exponentially_longer, attempts: 5
```

### Webhooks de Estado (Futuro)
```ruby
# Configurar webhook para recibir estados de entrega
# POST /webhooks/whatsapp_api/delivery_status
# Body: { messageId: 'msg_123', status: 'delivered', timestamp: '...' }
```

## Seguridad

### Recomendaciones
1. **Rotar tokens regularmente**
2. **Usar HTTPS para todas las URLs**
3. **Validar permisos de usuario**
4. **Monitorear logs de acceso**
5. **Limitar acceso por IP si es posible**

### Encriptación de Credenciales (Futuro)
```ruby
# Implementar encriptación con Rails credentials
# o gems como attr_encrypted
class Channel::Api
  encrypts :additional_attributes
end
```