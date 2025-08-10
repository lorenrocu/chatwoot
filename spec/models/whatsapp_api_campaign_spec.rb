require 'rails_helper'

RSpec.describe WhatsappApiCampaign, type: :model do
  describe 'associations' do
    it { should belong_to(:account) }
    it { should belong_to(:inbox) }
    it { should belong_to(:sender).class_name('User').optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:account_id) }
    it { should validate_presence_of(:inbox_id) }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:message) }

    describe 'inbox validation' do
      let(:account) { create(:account) }
      let(:api_channel) { create(:channel_api, account: account) }
      let(:api_inbox) { api_channel.inbox }
      let(:web_inbox) { create(:inbox, account: account) }

      it 'allows API channel inbox' do
        campaign = build(:whatsapp_api_campaign, account: account, inbox: api_inbox)
        expect(campaign).to be_valid
      end

      it 'rejects non-API channel inbox' do
        campaign = build(:whatsapp_api_campaign, account: account, inbox: web_inbox)
        expect(campaign).not_to be_valid
        expect(campaign.errors[:inbox]).to include('must be an API Channel for WhatsApp API campaigns')
      end
    end

    describe 'scheduled_at validation' do
      it 'allows future scheduled_at' do
        campaign = build(:whatsapp_api_campaign, scheduled_at: 1.hour.from_now)
        expect(campaign).to be_valid
      end

      it 'rejects past scheduled_at' do
        campaign = build(:whatsapp_api_campaign, scheduled_at: 1.hour.ago)
        expect(campaign).not_to be_valid
        expect(campaign.errors[:scheduled_at]).to include('must be in the future')
      end
    end

    describe 'cross-account validation' do
      let(:account1) { create(:account) }
      let(:account2) { create(:account) }
      let(:inbox) { create(:inbox_with_api_channel, account: account2) }
      let(:sender) { create(:user, account: account2) }

      it 'rejects inbox from different account' do
        campaign = build(:whatsapp_api_campaign, account: account1, inbox: inbox)
        expect(campaign).not_to be_valid
        expect(campaign.errors[:inbox_id]).to include('must belong to the same account as the campaign')
      end

      it 'rejects sender from different account' do
        campaign = build(:whatsapp_api_campaign, account: account1, sender: sender)
        expect(campaign).not_to be_valid
        expect(campaign.errors[:sender_id]).to include('must belong to the same account as the campaign')
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 0, running: 1, completed: 2, failed: 3) }
  end

  describe 'scopes' do
    let!(:pending_campaign) { create(:whatsapp_api_campaign, :scheduled_for_past, status: :pending) }
    let!(:running_campaign) { create(:whatsapp_api_campaign, status: :running) }
    let!(:future_campaign) { create(:whatsapp_api_campaign, scheduled_at: 1.hour.from_now, status: :pending) }

    describe '.scheduled_for_execution' do
      it 'returns pending campaigns scheduled for past or now' do
        expect(WhatsappApiCampaign.scheduled_for_execution).to include(pending_campaign)
        expect(WhatsappApiCampaign.scheduled_for_execution).not_to include(running_campaign)
        expect(WhatsappApiCampaign.scheduled_for_execution).not_to include(future_campaign)
      end
    end

    describe '.by_account' do
      let(:account) { pending_campaign.account }
      let!(:other_campaign) { create(:whatsapp_api_campaign) }

      it 'returns campaigns for specific account' do
        expect(WhatsappApiCampaign.by_account(account.id)).to include(pending_campaign)
        expect(WhatsappApiCampaign.by_account(account.id)).not_to include(other_campaign)
      end
    end
  end

  describe '#trigger!' do
    let(:campaign) { create(:whatsapp_api_campaign, :scheduled_for_past) }

    it 'changes status to running and enqueues job' do
      expect(WhatsappApi::CampaignExecutorJob).to receive(:perform_later).with(campaign)
      
      campaign.trigger!
      
      expect(campaign.reload.status).to eq('running')
    end

    it 'does not trigger completed campaigns' do
      campaign.update!(status: :completed)
      expect(WhatsappApi::CampaignExecutorJob).not_to receive(:perform_later)
      
      campaign.trigger!
    end

    it 'does not trigger future campaigns' do
      campaign.update!(scheduled_at: 1.hour.from_now)
      expect(WhatsappApi::CampaignExecutorJob).not_to receive(:perform_later)
      
      campaign.trigger!
    end
  end

  describe '#can_be_updated?' do
    it 'returns true for pending campaigns' do
      campaign = create(:whatsapp_api_campaign, status: :pending)
      expect(campaign.can_be_updated?).to be true
    end

    it 'returns true for failed campaigns' do
      campaign = create(:whatsapp_api_campaign, status: :failed)
      expect(campaign.can_be_updated?).to be true
    end

    it 'returns false for running campaigns' do
      campaign = create(:whatsapp_api_campaign, status: :running)
      expect(campaign.can_be_updated?).to be false
    end

    it 'returns false for completed campaigns' do
      campaign = create(:whatsapp_api_campaign, status: :completed)
      expect(campaign.can_be_updated?).to be false
    end
  end

  describe 'delivery stats methods' do
    let(:campaign) { create(:whatsapp_api_campaign) }

    describe '#increment_sent!' do
      it 'increments sent count' do
        expect { campaign.increment_sent! }.to change { campaign.reload.delivery_stats['sent'] }.from(0).to(1)
      end
    end

    describe '#increment_delivered!' do
      it 'increments delivered count' do
        expect { campaign.increment_delivered! }.to change { campaign.reload.delivery_stats['delivered'] }.from(0).to(1)
      end
    end

    describe '#increment_failed!' do
      it 'increments failed count' do
        expect { campaign.increment_failed! }.to change { campaign.reload.delivery_stats['failed'] }.from(0).to(1)
      end
    end
  end

  describe '#total_contacts' do
    it 'returns 0 when audience is blank' do
      campaign = create(:whatsapp_api_campaign, audience: {})
      expect(campaign.total_contacts).to eq(0)
    end

    it 'returns contact count from contact_ids' do
      campaign = create(:whatsapp_api_campaign, audience: { contact_ids: [1, 2, 3] })
      expect(campaign.total_contacts).to eq(3)
    end
  end

  describe '#completion_percentage' do
    let(:campaign) { create(:whatsapp_api_campaign, audience: { contact_ids: [1, 2, 3, 4, 5] }) }

    it 'returns 0 when no contacts' do
      campaign.update!(audience: {})
      expect(campaign.completion_percentage).to eq(0)
    end

    it 'calculates percentage correctly' do
      campaign.update!(delivery_stats: { sent: 3, delivered: 0, failed: 1 })
      expect(campaign.completion_percentage).to eq(80.0) # 4 out of 5 processed
    end
  end

  describe 'callbacks' do
    describe 'set_default_scheduled_at' do
      it 'sets scheduled_at to current time if not provided' do
        travel_to Time.zone.parse('2023-01-01 12:00:00') do
          campaign = build(:whatsapp_api_campaign, scheduled_at: nil)
          campaign.valid?
          expect(campaign.scheduled_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'does not override provided scheduled_at' do
        future_time = 2.hours.from_now
        campaign = build(:whatsapp_api_campaign, scheduled_at: future_time)
        campaign.valid?
        expect(campaign.scheduled_at).to eq(future_time)
      end
    end
  end
end