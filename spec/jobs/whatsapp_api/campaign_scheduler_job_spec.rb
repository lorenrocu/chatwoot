require 'rails_helper'

RSpec.describe WhatsappApi::CampaignSchedulerJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    it 'calls the campaign scheduler service' do
      expect(WhatsappApi::CampaignSchedulerService).to receive(:schedule_pending_campaigns)
      
      described_class.perform_now
    end

    context 'when service raises an error' do
      let(:error_message) { 'Database connection failed' }

      before do
        allow(WhatsappApi::CampaignSchedulerService).to receive(:schedule_pending_campaigns)
          .and_raise(StandardError, error_message)
      end

      it 'logs the error and re-raises it' do
        expect(Rails.logger).to receive(:error).with(/Error in CampaignSchedulerJob: #{error_message}/)
        expect(Rails.logger).to receive(:error).with(/backtrace/)
        
        expect {
          described_class.perform_now
        }.to raise_error(StandardError, error_message)
      end
    end
  end

  describe 'job configuration' do
    it 'has correct queue name' do
      expect(described_class.queue_name).to eq('scheduled')
    end
  end

  describe 'job scheduling' do
    it 'can be enqueued' do
      expect {
        described_class.perform_later
      }.to have_enqueued_job(described_class)
    end

    it 'can be performed immediately' do
      expect(WhatsappApi::CampaignSchedulerService).to receive(:schedule_pending_campaigns)
      
      perform_enqueued_jobs do
        described_class.perform_later
      end
    end
  end
end