class WhatsappApi::CampaignSchedulerJob < ApplicationJob
  queue_as :scheduled

  # This job should be scheduled to run every minute via cron or similar
  # Example cron entry: * * * * * cd /path/to/app && bundle exec rails runner "WhatsappApi::CampaignSchedulerJob.perform_later"
  
  def perform
    WhatsappApi::CampaignSchedulerService.schedule_pending_campaigns
  rescue StandardError => e
    Rails.logger.error "Error in CampaignSchedulerJob: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end