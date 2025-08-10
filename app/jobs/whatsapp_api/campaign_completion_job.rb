class WhatsappApi::CampaignCompletionJob < ApplicationJob
  queue_as :default

  def perform(campaign)
    return unless campaign.running?
    
    # Check if all messages have been processed
    total_contacts = campaign.total_contacts
    total_processed = campaign.delivery_stats['sent'] + campaign.delivery_stats['failed']
    
    if total_processed >= total_contacts
      campaign.update!(status: :completed)
      
      # Send notification to campaign creator
      send_completion_notification(campaign)
      
      Rails.logger.info "WhatsApp API Campaign #{campaign.id} completed. Stats: #{campaign.delivery_stats}"
    else
      # If not all messages processed, schedule another check
      WhatsappApi::CampaignCompletionJob.set(wait: 1.minute).perform_later(campaign)
    end
  end

  private

  def send_completion_notification(campaign)
    return unless campaign.sender

    # Create a notification for the campaign creator
    # This could be extended to send email notifications as well
    
    notification_message = build_notification_message(campaign)
    
    # You can implement your notification system here
    # For example, creating an in-app notification or sending an email
    Rails.logger.info "Campaign completion notification: #{notification_message}"
  end

  def build_notification_message(campaign)
    stats = campaign.delivery_stats
    success_rate = calculate_success_rate(stats)
    
    "WhatsApp API Campaign '#{campaign.title}' has completed. " \
    "Sent: #{stats['sent']}, Failed: #{stats['failed']}, " \
    "Success Rate: #{success_rate}%"
  end

  def calculate_success_rate(stats)
    total = stats['sent'] + stats['failed']
    return 0 if total.zero?
    
    ((stats['sent'].to_f / total) * 100).round(2)
  end
end