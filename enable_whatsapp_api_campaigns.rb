#!/usr/bin/env ruby
# Script para habilitar el feature flag de WhatsApp API Campaigns

# Cargar el entorno de Rails
require_relative 'config/environment'

begin
  puts "Habilitando feature flag 'whatsapp_api_campaigns'..."
  
  # Obtener todas las cuentas
  accounts = Account.all
  
  if accounts.empty?
    puts "No se encontraron cuentas en el sistema."
    exit 1
  end
  
  # Habilitar el feature flag para todas las cuentas
  accounts.each do |account|
    if account.feature_enabled?('whatsapp_api_campaigns')
      puts "✓ Cuenta ##{account.id} (#{account.name}) ya tiene habilitado el feature flag"
    else
      account.enable_features!('whatsapp_api_campaigns')
      puts "✓ Feature flag habilitado para cuenta ##{account.id} (#{account.name})"
    end
  end
  
  # También habilitar a nivel global para nuevas cuentas
  config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
  
  if config
    features = config.value || []
    whatsapp_api_feature = features.find { |f| f['name'] == 'whatsapp_api_campaigns' }
    
    if whatsapp_api_feature
      if whatsapp_api_feature['enabled']
        puts "✓ Feature flag ya está habilitado por defecto para nuevas cuentas"
      else
        whatsapp_api_feature['enabled'] = true
        config.save!
        puts "✓ Feature flag habilitado por defecto para nuevas cuentas"
      end
    else
      features << { 'name' => 'whatsapp_api_campaigns', 'enabled' => true }
      config.value = features
      config.save!
      puts "✓ Feature flag agregado y habilitado por defecto para nuevas cuentas"
    end
  else
    InstallationConfig.create!(
      name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS',
      value: [{ 'name' => 'whatsapp_api_campaigns', 'enabled' => true }]
    )
    puts "✓ Configuración creada y feature flag habilitado por defecto"
  end
  
  puts "\n🎉 ¡Feature flag 'whatsapp_api_campaigns' habilitado exitosamente!"
  puts "\nAhora puedes acceder a /campaigns/whatsapp-api en tu aplicación."
  
rescue => e
  puts "❌ Error al habilitar el feature flag: #{e.message}"
  puts e.backtrace.join("\n")
  exit 1
end