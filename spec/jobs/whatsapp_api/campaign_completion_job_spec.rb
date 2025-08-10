require 'rails_helper'

RSpec.describe WhatsappApi::CampaignCompletionJob, type: :job do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:api_inbox) { create(:inbox_with_api_channel, account: account) }
  let(:sender) { create(:user, account: account) }
  let(:campaign) do
    create(:whatsapp_api_campaign, 
           account: account, 
           inbox: api_inbox, 
           sender: sender,
           status: :running,
           audience: { contact_ids: [1, 2, 3, 4, 5] })
  end

  describe '#perform' do
    context 'when campaign is completed' do
      before do
        campaign.update!(
          delivery_stats: {
            sent: 3,
            delivered: 2,
            failed: 2
          }
        )
      end

      it 'marks campaign as completed' do
        described_class.perform_now(campaign)
        
        expect(campaign.reload.status).to eq('completed')
      end

      it 'sends completion notification' do
        expect_any_instance_of(described_class).to receive(:send_completion_notification)
        
        described_class.perform_now(campaign)
      end

      it 'does not schedule another check' do
        expect(described_class).not_to receive(:set)
        
        described_class.perform_now(campaign)
      end
    end

    context 'when campaign is not completed' do
      before do
        campaign.update!(
          delivery_stats: {
            sent: 2,
            delivered: 1,
            failed: 1
          }
        )
      end

      it 'does not change campaign status' do
        described_class.perform_now(campaign)
        
        expect(campaign.reload.status).to eq('running')
      end

      it 'schedules another check' do
        expect(described_class).to receive(:set).with(wait: 30.seconds).and_call_original
        allow_any_instance_of(ActiveJob::ConfiguredJob).to receive(:perform_later)
        
        described_class.perform_now(campaign)
      end

      it 'does not send completion notification' do
        expect_any_instance_of(described_class).not_to receive(:send_completion_notification)
        
        described_class.perform_now(campaign)
      end
    end

    context 'when campaign is already completed' do
      before do
        campaign.update!(status: :completed)
      end

      it 'does nothing' do
        expect(campaign).not_to receive(:update!)
        expect_any_instance_of(described_class).not_to receive(:send_completion_notification)
        expect(described_class).not_to receive(:set)
        
        described_class.perform_now(campaign)
      end
    end

    context 'when campaign is failed' do
      before do
        campaign.update!(status: :failed)
      end

      it 'does nothing' do
        expect(campaign).not_to receive(:update!)
        expect_any_instance_of(described_class).not_to receive(:send_completion_notification)
        expect(described_class).not_to receive(:set)
        
        described_class.perform_now(campaign)
      end
    end

    context 'when campaign has no audience' do
      before do
        campaign.update!(audience: {})
      end

      it 'marks campaign as completed immediately' do
        described_class.perform_now(campaign)
        
        expect(campaign.reload.status).to eq('completed')
      end
    end

    context 'with maximum check attempts reached' do
      before do
        campaign.update!(
          delivery_stats: {
            sent: 2,
            delivered: 1,
            failed: 1
          }
        )
      end

      it 'marks campaign as completed after max attempts' do
        # Simulate 20 attempts (max_attempts = 20)
        allow_any_instance_of(described_class).to receive(:executions).and_return(20)
        
        described_class.perform_now(campaign)
        
        expect(campaign.reload.status).to eq('completed')
      end

      it 'sends completion notification after max attempts' do
        allow_any_instance_of(described_class).to receive(:executions).and_return(20)
        expect_any_instance_of(described_class).to receive(:send_completion_notification)
        
        described_class.perform_now(campaign)
      end
    end
  end

  describe '#campaign_completed?' do
    let(:job) { described_class.new }

    context 'when all contacts are processed' do
      before do
        campaign.update!(
          audience: { contact_ids: [1, 2, 3] },
          delivery_stats: { sent: 2, delivered: 0, failed: 1 }
        )
      end

      it 'returns true' do
        expect(job.send(:campaign_completed?, campaign)).to be true
      end
    end

    context 'when not all contacts are processed' do
      before do
        campaign.update!(
          audience: { contact_ids: [1, 2, 3, 4] },
          delivery_stats: { sent: 2, delivered: 0, failed: 1 }
        )
      end

      it 'returns false' do
        expect(job.send(:campaign_completed?, campaign)).to be false
      end
    end

    context 'when campaign has no audience' do
      before do
        campaign.update!(audience: {})
      end

      it 'returns true' do
        expect(job.send(:campaign_completed?, campaign)).to be true
      end
    end
  end

  describe '#send_completion_notification' do
    let(:job) { described_class.new }

    before do
      campaign.update!(
        delivery_stats: {
          sent: 8,
          delivered: 6,
          failed: 2
        }
      )
    end

    it 'creates a notification message for the sender' do
      expect {
        job.send(:send_completion_notification, campaign)
      }.to change(Message, :count).by(1)

      notification = Message.last
      expect(notification.sender).to eq(sender)
      expect(notification.message_type).to eq('incoming')
      expect(notification.content).to include('WhatsApp API Campaign Completed')
      expect(notification.content).to include(campaign.title)
      expect(notification.content).to include('Total: 10')
      expect(notification.content).to include('Sent: 8')
      expect(notification.content).to include('Delivered: 6')
      expect(notification.content).to include('Failed: 2')
      expect(notification.content).to include('Success Rate: 80.0%')
    end

    it 'creates or finds conversation for notification' do
      expect {
        job.send(:send_completion_notification, campaign)
      }.to change(Conversation, :count).by(1)

      conversation = Conversation.last
      expect(conversation.inbox).to eq(api_inbox)
      expect(conversation.account).to eq(account)
    end

    it 'reuses existing conversation if available' do
      existing_conversation = create(:conversation, 
                                   account: account, 
                                   inbox: api_inbox)
      
      expect {
        job.send(:send_completion_notification, campaign)
      }.to change(Conversation, :count).by(0)

      notification = Message.last
      expect(notification.conversation).to eq(existing_conversation)
    end

    context 'when sender is nil' do
      before do
        campaign.update!(sender: nil)
      end

      it 'does not create notification' do
        expect {
          job.send(:send_completion_notification, campaign)
        }.not_to change(Message, :count)
      end
    end
  end

  describe '#calculate_success_rate' do
    let(:job) { described_class.new }

    it 'calculates correct success rate' do
      stats = { sent: 8, delivered: 6, failed: 2 }
      expect(job.send(:calculate_success_rate, stats)).to eq(80.0)
    end

    it 'handles zero total' do
      stats = { sent: 0, delivered: 0, failed: 0 }
      expect(job.send(:calculate_success_rate, stats)).to eq(0.0)
    end

    it 'handles missing delivered count' do
      stats = { sent: 5, failed: 2 }
      expect(job.send(:calculate_success_rate, stats)).to eq(60.0)
    end
  end

  describe 'error handling' do
    it 'handles errors gracefully' do
      allow(campaign).to receive(:reload).and_raise(StandardError, 'Database error')
      
      expect {
        described_class.perform_now(campaign)
      }.not_to raise_error
    end

    it 'logs errors appropriately' do
      allow(campaign).to receive(:reload).and_raise(StandardError, 'Database error')
      expect(Rails.logger).to receive(:error).with(/Error in CampaignCompletionJob/)
      
      described_class.perform_now(campaign)
    end
  end

  describe 'job configuration' do
    it 'has correct queue name' do
      expect(described_class.queue_name).to eq('default')
    end

    it 'has correct retry configuration' do
      expect(described_class.retry_on).to include(StandardError)
    end
  end
end