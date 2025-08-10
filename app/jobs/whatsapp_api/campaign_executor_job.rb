class WhatsappApi::CampaignExecutorJob < ApplicationJob
  queue_as :default
  
  RATE_LIMIT_DELAY = 5.seconds # 12 messages per minute = 5 seconds between messages

  def perform(campaign)
    return unless campaign.running?
    return unless campaign.account.feature_enabled?(:whatsapp_api_campaigns)

    begin
      execute_campaign(campaign)
    rescue StandardError => e
      Rails.logger.error "WhatsApp API Campaign #{campaign.id} failed: #{e.message}"
      campaign.update!(
        status: :failed,
        error_message: e.message
      )
    end
  end

  private

  def execute_campaign(campaign)
    contacts = fetch_campaign_contacts(campaign)
    
    if contacts.empty?
      campaign.update!(
        status: :completed,
        error_message: 'No contacts found for the specified audience'
      )
      return
    end

    contacts.each_with_index do |contact, index|
      # Add delay between messages for rate limiting (except for first message)
      WhatsappApi::SendMessageJob.set(wait: index * RATE_LIMIT_DELAY)
                                 .perform_later(campaign, contact)
    end

    # Schedule completion check after all messages are queued
    total_delay = (contacts.size - 1) * RATE_LIMIT_DELAY + 30.seconds
    WhatsappApi::CampaignCompletionJob.set(wait: total_delay)
                                      .perform_later(campaign)
  end

  def fetch_campaign_contacts(campaign)
    audience = campaign.audience
    return [] if audience.blank?

    # If specific contact IDs are provided
    if audience['contact_ids'].present?
      return campaign.account.contacts.where(id: audience['contact_ids'])
    end

    # If audience filters are provided (labels, custom attributes, etc.)
    contacts = campaign.account.contacts
    
    if audience['labels'].present?
      contacts = contacts.joins(:labels).where(labels: { name: audience['labels'] })
    end

    if audience['custom_attributes'].present?
      audience['custom_attributes'].each do |attr_name, attr_value|
        contacts = contacts.where(
          "custom_attributes ->> ? = ?", 
          attr_name, 
          attr_value.to_s
        )
      end
    end

    # Ensure contacts have WhatsApp contact info for the campaign inbox
    contacts.joins(:contact_inboxes)
            .where(contact_inboxes: { inbox_id: campaign.inbox_id })
            .where.not(contact_inboxes: { source_id: [nil, ''] })
            .distinct
  end
end