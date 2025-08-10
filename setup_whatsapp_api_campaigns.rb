#!/usr/bin/env ruby
# Script para configurar las campañas de WhatsApp API

# Habilitar la feature flag para WhatsApp API Campaigns
Account.find_each do |account|
  account.enable_features('whatsapp_api_campaigns')
  puts "Feature flag 'whatsapp_api_campaigns' habilitada para la cuenta: #{account.name} (ID: #{account.id})"
end

# Crear un inbox API de ejemplo si no existe ninguno
Account.find_each do |account|
  # Verificar si ya existe un inbox API
  api_inbox = account.inboxes.joins(:channel).where(channels: { type: 'Channel::Api' }).first
  
  if api_inbox.nil?
    # Crear un canal API
    api_channel = Channel::Api.create!(
      account: account,
      webhook_url: 'https://example.com/webhook' # URL de ejemplo
    )
    
    # Crear el inbox
    api_inbox = Inbox.create!(
      account: account,
      name: "API Inbox para WhatsApp",
      channel: api_channel
    )
    
    puts "Inbox API creado para la cuenta: #{account.name} (ID: #{account.id})"
    puts "  - Inbox ID: #{api_inbox.id}"
    puts "  - Channel ID: #{api_channel.id}"
  else
    puts "Ya existe un inbox API para la cuenta: #{account.name} (ID: #{account.id})"
    puts "  - Inbox ID: #{api_inbox.id}"
  end
end

puts "\n✅ Configuración completada!"
puts "Ahora puedes acceder a /campaigns/whatsapp-api y crear campañas."
puts "\nNota: Recuerda configurar la URL del webhook en el inbox API creado si planeas usar webhooks reales."