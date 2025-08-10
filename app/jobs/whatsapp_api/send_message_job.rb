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
    
    payload = build_message_payload(campaign, whatsapp_number)
    response = send_to_whatsapp_api(api_credentials, payload)
    
    # Log the response for debugging
    Rails.logger.info "WhatsApp API response for campaign #{campaign.id}: #{response}"
    
    # Create conversation and message record
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

  def build_message_payload(campaign, whatsapp_number)
    payload = {
      number: whatsapp_number,
      text: campaign.message
    }

    # Add multimedia if present
    if campaign.multimedia.present?
      case campaign.multimedia['type']
      when 'image'
        payload[:mediaMessage] = {
          mediatype: 'image',
          media: campaign.multimedia['url'],
          caption: campaign.message
        }
        payload.delete(:text) # Remove text when sending media with caption
      when 'document'
        payload[:mediaMessage] = {
          mediatype: 'document',
          media: campaign.multimedia['url'],
          fileName: campaign.multimedia['filename'] || 'document'
        }
      when 'audio'
        payload[:mediaMessage] = {
          mediatype: 'audio',
          media: campaign.multimedia['url']
        }
      end
    end

    payload
  end

  def send_to_whatsapp_api(credentials, payload)
    uri = URI("#{credentials[:base_url]}/message/sendText/#{credentials[:instance_name]}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['apikey'] = credentials[:token]
    request.body = payload.to_json
    
    response = http.request(request)
    
    unless response.code.to_i.between?(200, 299)
      raise "WhatsApp API request failed with status #{response.code}: #{response.body}"
    end
    
    JSON.parse(response.body)
  end

  def create_conversation_and_message(campaign, contact, contact_inbox)
    # Find or create conversation
    conversation = Conversation.find_or_create_by(
      account: campaign.account,
      inbox: campaign.inbox,
      contact: contact
    ) do |conv|
      conv.status = :open
      conv.assignee = campaign.sender
    end

    # Create outgoing message
    message = conversation.messages.create!(
      account: campaign.account,
      inbox: campaign.inbox,
      user: campaign.sender,
      contact: contact,
      message_type: :outgoing,
      content: campaign.message,
      source_id: SecureRandom.uuid
    )

    # Add multimedia attachment if present
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