require 'rails_helper'

RSpec.describe WhatsappApi::CampaignExecutorJob, type: :job do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:api_inbox) { create(:inbox_with_api_channel, account: account) }
  let(:campaign) { create(:whatsapp_api_campaign, :with_contacts, account: account, inbox: api_inbox, contact_count: 5) }

  describe '#perform' do
    context 'with valid campaign' do
      it 'processes all contacts with rate limiting' do
        expect(WhatsappApi::SendMessageJob).to receive(:set).with(wait: 0.seconds).and_call_original.exactly(1).times
        expect(WhatsappApi::SendMessageJob).to receive(:set).with(wait: 5.seconds).and_call_original.exactly(1).times
        expect(WhatsappApi::SendMessageJob).to receive(:set).with(wait: 10.seconds).and_call_original.exactly(1).times
        expect(WhatsappApi::SendMessageJob).to receive(:set).with(wait: 15.seconds).and_call_original.exactly(1).times
        expect(WhatsappApi::SendMessageJob).to receive(:set).with(wait: 20.seconds).and_call_original.exactly(1).times
        
        allow_any_instance_of(ActiveJob::ConfiguredJob).to receive(:perform_later)
        
        expect(WhatsappApi::CampaignCompletionJob).to receive(:set).with(wait: 30.seconds).and_call_original
        allow_any_instance_of(ActiveJob::ConfiguredJob).to receive(:perform_later)
        
        described_class.perform_now(campaign)
      end

      it 'schedules completion check job' do
        allow(WhatsappApi::SendMessageJob).to receive_message_chain(:set, :perform_later)
        
        expect(WhatsappApi::CampaignCompletionJob).to receive(:set).with(wait: 30.seconds).and_call_original
        allow_any_instance_of(ActiveJob::ConfiguredJob).to receive(:perform_later)
        
        described_class.perform_now(campaign)
      end
    end

    context 'with campaign using contact_ids audience' do
      let(:contacts) { create_list(:contact, 3, account: account) }
      let(:campaign) do
        create(:whatsapp_api_campaign, 
               account: account, 
               inbox: api_inbox,
               audience: { contact_ids: contacts.pluck(:id) })
      end

      before do
        # Create contact_inboxes for the API channel
        contacts.each_with_index do |contact, index|
          create(:contact_inbox, 
                 contact: contact, 
                 inbox: api_inbox, 
                 source_id: "+1555000#{1000 + index}")
        end
      end

      it 'fetches contacts by IDs' do
        allow(WhatsappApi::SendMessageJob).to receive_message_chain(:set, :perform_later)
        allow(WhatsappApi::CampaignCompletionJob).to receive_message_chain(:set, :perform_later)
        
        described_class.perform_now(campaign)
        
        expect(WhatsappApi::SendMessageJob).to have_received(:set).exactly(3).times
      end
    end

    context 'with campaign using labels audience' do
      let(:label) { create(:label, account: account) }
      let(:contacts) { create_list(:contact, 2, account: account) }
      let(:campaign) do
        create(:whatsapp_api_campaign, 
               account: account, 
               inbox: api_inbox,
               audience: { labels: [label.title] })
      end

      before do
        # Associate contacts with label
        contacts.each do |contact|
          contact.labels << label
          create(:contact_inbox, contact: contact, inbox: api_inbox, source_id: "+1555#{rand(1000..9999)}")
        end
      end

      it 'fetches contacts by labels' do
        allow(WhatsappApi::SendMessageJob).to receive_message_chain(:set, :perform_later)
        allow(WhatsappApi::CampaignCompletionJob).to receive_message_chain(:set, :perform_later)
        
        described_class.perform_now(campaign)
        
        expect(WhatsappApi::SendMessageJob).to have_received(:set).exactly(2).times
      end
    end

    context 'with campaign using custom attributes audience' do
      let(:contacts) { create_list(:contact, 2, account: account) }
      let(:campaign) do
        create(:whatsapp_api_campaign, 
               account: account, 
               inbox: api_inbox,
               audience: { 
                 custom_attributes: {
                   'subscription_type' => 'premium'
                 }
               })
      end

      before do
        contacts.each_with_index do |contact, index|
          contact.update!(custom_attributes: { 'subscription_type' => 'premium' })
          create(:contact_inbox, contact: contact, inbox: api_inbox, source_id: "+1555#{1000 + index}")
        end
        
        # Create a contact that shouldn't match
        other_contact = create(:contact, account: account, custom_attributes: { 'subscription_type' => 'basic' })
        create(:contact_inbox, contact: other_contact, inbox: api_inbox, source_id: "+15559999")
      end

      it 'fetches contacts by custom attributes' do
        allow(WhatsappApi::SendMessageJob).to receive_message_chain(:set, :perform_later)
        allow(WhatsappApi::CampaignCompletionJob).to receive_message_chain(:set, :perform_later)
        
        described_class.perform_now(campaign)
        
        expect(WhatsappApi::SendMessageJob).to have_received(:set).exactly(2).times
      end
    end

    context 'with empty audience' do
      let(:campaign) do
        create(:whatsapp_api_campaign, 
               account: account, 
               inbox: api_inbox,
               audience: {})
      end

      it 'does not schedule any message jobs' do
        expect(WhatsappApi::SendMessageJob).not_to receive(:set)
        expect(WhatsappApi::CampaignCompletionJob).not_to receive(:set)
        
        described_class.perform_now(campaign)
      end
    end

    context 'with contacts without contact_inbox for the campaign inbox' do
      let(:contacts) { create_list(:contact, 2, account: account) }
      let(:other_inbox) { create(:inbox, account: account) }
      let(:campaign) do
        create(:whatsapp_api_campaign, 
               account: account, 
               inbox: api_inbox,
               audience: { contact_ids: contacts.pluck(:id) })
      end

      before do
        # Create contact_inboxes for a different inbox
        contacts.each_with_index do |contact, index|
          create(:contact_inbox, 
                 contact: contact, 
                 inbox: other_inbox, 
                 source_id: "+1555000#{1000 + index}")
        end
      end

      it 'skips contacts without contact_inbox for campaign inbox' do
        allow(WhatsappApi::SendMessageJob).to receive_message_chain(:set, :perform_later)
        allow(WhatsappApi::CampaignCompletionJob).to receive_message_chain(:set, :perform_later)
        
        described_class.perform_now(campaign)
        
        expect(WhatsappApi::SendMessageJob).not_to have_received(:set)
      end
    end

    context 'error handling' do
      it 'handles errors gracefully and marks campaign as failed' do
        allow_any_instance_of(described_class).to receive(:fetch_contacts).and_raise(StandardError, 'Database error')
        
        expect {
          described_class.perform_now(campaign)
        }.not_to raise_error
        
        expect(campaign.reload.status).to eq('failed')
        expect(campaign.error_message).to include('Database error')
      end
    end
  end

  describe 'private methods' do
    let(:job) { described_class.new }

    describe '#calculate_delay' do
      it 'calculates correct delay for rate limiting' do
        expect(job.send(:calculate_delay, 0)).to eq(0)
        expect(job.send(:calculate_delay, 1)).to eq(5)
        expect(job.send(:calculate_delay, 2)).to eq(10)
        expect(job.send(:calculate_delay, 11)).to eq(55)
      end
    end

    describe '#fetch_contacts' do
      let(:contacts) { create_list(:contact, 3, account: account) }
      
      before do
        contacts.each_with_index do |contact, index|
          create(:contact_inbox, 
                 contact: contact, 
                 inbox: api_inbox, 
                 source_id: "+1555000#{1000 + index}")
        end
      end

      it 'fetches contacts with contact_inbox for the campaign inbox' do
        audience = { contact_ids: contacts.pluck(:id) }
        result = job.send(:fetch_contacts, campaign.account, api_inbox, audience)
        
        expect(result.count).to eq(3)
        expect(result.pluck(:id)).to match_array(contacts.pluck(:id))
      end
    end
  end
end