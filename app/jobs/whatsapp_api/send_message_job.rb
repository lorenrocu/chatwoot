class WhatsappApi::SendMessageJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: 30.seconds, attempts: 3

  def perform(campaign, contact)
    return unless campaign.running?
    return unless campaign.account.feature_enabled?(:whatsapp_api_campaigns)

    begin
      send_message_to_contact(campaign, contact)
      campaign.increment_sent!
    rescue StandardError => e
      Rails.logger.error "Failed to send WhatsApp API message for campaign #{campaign.id} to contact #{contact.id}: #{e.message}"
      campaign.increment_failed!
      raise e if executions < 3 # Allow retries
    end
  end

  private

  def send_message_to_contact(campaign, contact)
    contact_inbox = contact.contact_inboxes.find_by(inbox: campaign.inbox)
    
    unless contact_inbox&.source_id.present?
      raise "Contact #{contact.id} has no WhatsApp number for inbox #{campaign.inbox.id}"
    end

    whatsapp_number = contact_inbox.source_id
    api_credentials = get_api_credentials(campaign.inbox)

    has_media = campaign.multimedia.present?
    if has_media
      payload = build_media_payload(whatsapp_number, campaign.message, campaign.multimedia)
    else
      payload = build_text_payload(whatsapp_number, campaign.message)
    end

    response = send_to_whatsapp_api(api_credentials, payload, has_media)
    
    Rails.logger.info "WhatsApp API response for campaign #{campaign.id}: #{response}"
    
    create_conversation_and_message(campaign, contact, contact_inbox)
  end

  def get_api_credentials(inbox)
    credentials = inbox.channel.additional_attributes['whatsapp_api_credentials']
    
    unless credentials.present?
      raise "WhatsApp API credentials not configured for inbox #{inbox.id}"
    end

    {
      base_url: credentials['base_url'],
      token: credentials['token'],
      instance_name: credentials['instance_name']
    }
  end

  def build_text_payload(whatsapp_number, message_text)
    {
      number: whatsapp_number,
      text: message_text
    }
  end

  def build_media_payload(whatsapp_number, message_text, multimedia)
    payload = {
      number: whatsapp_number,
      mediatype: multimedia['type'],
      media: multimedia['url'],
      fileName: multimedia['filename'] || 'file'
    }

    payload[:mimetype] = multimedia['mimetype'] if multimedia['mimetype'].present?
    
    case multimedia['type']
    when 'image'
      payload[:caption] = message_text if message_text.present?
    when 'document', 'audio'
      # For documents/audio, we can keep caption empty and send text separately if needed
    end

    payload
  end

  def get_api_endpoint(credentials, has_multimedia)
    endpoint = has_multimedia ? 'sendMedia' : 'sendText'
    "#{credentials[:base_url]}/message/#{endpoint}/#{credentials[:instance_name]}"
  end

  def send_to_whatsapp_api(credentials, payload, has_multimedia = false)
    uri = URI(get_api_endpoint(credentials, has_multimedia))
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['apikey'] = credentials[:token]
    request.body = payload.to_json
    
    response = http.request(request)

    status = response.code.to_i
    unless status.between?(200, 299)
      raise "WhatsApp API request failed with status #{response.code}: #{response.body}"
    end
    
    JSON.parse(response.body)
  end

  def should_retry?(status_code)
    return false if status_code.between?(400, 499)
    true
  end

  def create_conversation_and_message(campaign, contact, contact_inbox)
    conversation = Conversation.find_or_create_by(
      account: campaign.account,
      inbox: campaign.inbox,
      contact: contact
    ) do |conv|
      conv.status = :open
      conv.assignee = campaign.sender
    end

    message = conversation.messages.create!(
      account: campaign.account,
      inbox: campaign.inbox,
      user: campaign.sender,
      contact: contact,
      message_type: :outgoing,
      content: campaign.message,
      source_id: SecureRandom.uuid
    )

    if campaign.multimedia.present? && campaign.multimedia['url'].present?
      message.attachments.create!(
        account: campaign.account,
        file_type: campaign.multimedia['type'] || 'file',
        external_url: campaign.multimedia['url']
      )
    end

    message
  end
end