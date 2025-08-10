require 'rails_helper'

RSpec.describe WhatsappApi::CampaignSchedulerService do
  describe '.schedule_pending_campaigns' do
    it 'delegates to instance method' do
      service_instance = instance_double(described_class)
      expect(described_class).to receive(:new).and_return(service_instance)
      expect(service_instance).to receive(:schedule_pending_campaigns)
      
      described_class.schedule_pending_campaigns
    end
  end

  describe '#schedule_pending_campaigns' do
    let(:service) { described_class.new }
    let(:account) { create(:account) }
    let(:api_inbox) { create(:inbox_with_api_channel, account: account) }

    context 'with campaigns ready for execution' do
      let!(:ready_campaign1) do
        create(:whatsapp_api_campaign, 
               account: account, 
               inbox: api_inbox,
               status: :pending, 
               scheduled_at: 1.hour.ago)
      end
      
      let!(:ready_campaign2) do
        create(:whatsapp_api_campaign, 
               account: account, 
               inbox: api_inbox,
               status: :pending, 
               scheduled_at: 30.minutes.ago)
      end

      let!(:future_campaign) do
        create(:whatsapp_api_campaign, 
               account: account, 
               inbox: api_inbox,
               status: :pending, 
               scheduled_at: 1.hour.from_now)
      end

      let!(:running_campaign) do
        create(:whatsapp_api_campaign, 
               account: account, 
               inbox: api_inbox,
               status: :running, 
               scheduled_at: 2.hours.ago)
      end

      it 'triggers only campaigns ready for execution' do
        expect(ready_campaign1).to receive(:trigger!)
        expect(ready_campaign2).to receive(:trigger!)
        expect(future_campaign).not_to receive(:trigger!)
        expect(running_campaign).not_to receive(:trigger!)
        
        service.schedule_pending_campaigns
      end

      it 'logs successful triggers' do
        allow(ready_campaign1).to receive(:trigger!)
        allow(ready_campaign2).to receive(:trigger!)
        
        expect(Rails.logger).to receive(:info).with(/Triggered WhatsApp API campaign #{ready_campaign1.id}/)
        expect(Rails.logger).to receive(:info).with(/Triggered WhatsApp API campaign #{ready_campaign2.id}/)
        
        service.schedule_pending_campaigns
      end
    end

    context 'when campaign trigger fails' do
      let!(:failing_campaign) do
        create(:whatsapp_api_campaign, 
               account: account, 
               inbox: api_inbox,
               status: :pending, 
               scheduled_at: 1.hour.ago)
      end

      before do
        allow(failing_campaign).to receive(:trigger!).and_raise(StandardError, 'Job queue error')
      end

      it 'marks campaign as failed and logs error' do
        expect(Rails.logger).to receive(:error).with(/Failed to trigger WhatsApp API campaign #{failing_campaign.id}/)
        
        service.schedule_pending_campaigns
        
        failing_campaign.reload
        expect(failing_campaign.status).to eq('failed')
        expect(failing_campaign.error_message).to include('Scheduler error: Job queue error')
      end

      it 'continues processing other campaigns after failure' do
        successful_campaign = create(:whatsapp_api_campaign, 
                                   account: account, 
                                   inbox: api_inbox,
                                   status: :pending, 
                                   scheduled_at: 1.hour.ago)
        
        expect(successful_campaign).to receive(:trigger!)
        expect(Rails.logger).to receive(:error).with(/Failed to trigger WhatsApp API campaign #{failing_campaign.id}/)
        expect(Rails.logger).to receive(:info).with(/Triggered WhatsApp API campaign #{successful_campaign.id}/)
        
        service.schedule_pending_campaigns
      end
    end

    context 'with no campaigns ready for execution' do
      it 'does nothing' do
        expect(Rails.logger).not_to receive(:info)
        expect(Rails.logger).not_to receive(:error)
        
        service.schedule_pending_campaigns
      end
    end

    context 'with campaigns from different accounts' do
      let(:account2) { create(:account) }
      let(:api_inbox2) { create(:inbox_with_api_channel, account: account2) }
      
      let!(:campaign_account1) do
        create(:whatsapp_api_campaign, 
               account: account, 
               inbox: api_inbox,
               status: :pending, 
               scheduled_at: 1.hour.ago)
      end
      
      let!(:campaign_account2) do
        create(:whatsapp_api_campaign, 
               account: account2, 
               inbox: api_inbox2,
               status: :pending, 
               scheduled_at: 1.hour.ago)
      end

      it 'triggers campaigns from all accounts' do
        expect(campaign_account1).to receive(:trigger!)
        expect(campaign_account2).to receive(:trigger!)
        
        service.schedule_pending_campaigns
      end
    end

    context 'with large number of campaigns' do
      before do
        # Create 50 campaigns ready for execution
        50.times do |i|
          create(:whatsapp_api_campaign, 
                 account: account, 
                 inbox: api_inbox,
                 status: :pending, 
                 scheduled_at: (i + 1).minutes.ago)
        end
      end

      it 'processes all campaigns efficiently using find_each' do
        expect(WhatsappApiCampaign).to receive(:scheduled_for_execution).and_call_original
        expect_any_instance_of(ActiveRecord::Relation).to receive(:find_each).and_call_original
        
        service.schedule_pending_campaigns
      end
    end
  end
end