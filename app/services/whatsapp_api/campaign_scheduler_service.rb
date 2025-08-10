class WhatsappApi::CampaignSchedulerService
  def self.schedule_pending_campaigns
    new.schedule_pending_campaigns
  end

  def schedule_pending_campaigns
    WhatsappApiCampaign.scheduled_for_execution.find_each do |campaign|
      begin
        campaign.trigger!
        Rails.logger.info "Triggered WhatsApp API campaign #{campaign.id} for account #{campaign.account_id}"
      rescue StandardError => e
        Rails.logger.error "Failed to trigger WhatsApp API campaign #{campaign.id}: #{e.message}"
        campaign.update!(
          status: :failed,
          error_message: "Scheduler error: #{e.message}"
        )
      end
    end
  end
end