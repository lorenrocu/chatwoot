require 'rails_helper'

RSpec.describe WhatsappApi::SendMessageJob, type: :job do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:api_channel) { create(:channel_api_with_whatsapp_credentials, account: account) }
  let(:api_inbox) { api_channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: api_inbox, source_id: '+1234567890') }
  let(:campaign) { create(:whatsapp_api_campaign, account: account, inbox: api_inbox) }

  describe '#perform' do
    context 'with valid parameters' do
      let(:message_text) { 'Hello from campaign!' }

      before do
        stub_request(:post, 'https://api.evolution.com/message/sendText/test_instance')
          .with(
            headers: {
              'Content-Type' => 'application/json',
              'apikey' => 'test_api_token_123'
            },
            body: {
              number: '+1234567890',
              text: message_text
            }.to_json
          )
          .to return_status(200)
          .to return_body({ success: true, messageId: 'msg_123' }.to_json)
      end

      it 'sends message successfully and creates conversation' do
        expect {
          described_class.perform_now(campaign, contact, message_text)
        }.to change(Conversation, :count).by(1)
         .and change(Message, :count).by(1)

        expect(campaign.reload.delivery_stats['sent']).to eq(1)
        
        conversation = Conversation.last
        expect(conversation.inbox).to eq(api_inbox)
        expect(conversation.contact).to eq(contact)
        expect(conversation.account).to eq(account)
        
        message = Message.last
        expect(message.content).to eq(message_text)
        expect(message.message_type).to eq('outgoing')
        expect(message.conversation).to eq(conversation)
      end

      it 'uses existing conversation if available' do
        existing_conversation = create(:conversation, 
                                     account: account, 
                                     inbox: api_inbox, 
                                     contact: contact)
        
        expect {
          described_class.perform_now(campaign, contact, message_text)
        }.to change(Conversation, :count).by(0)
         .and change(Message, :count).by(1)

        message = Message.last
        expect(message.conversation).to eq(existing_conversation)
      end
    end

    context 'with multimedia message' do
      let(:message_text) { 'Check out this image!' }
      let(:multimedia) do
        {
          type: 'image',
          url: 'https://example.com/image.jpg',
          filename: 'campaign_image.jpg'
        }
      end

      before do
        stub_request(:post, 'https://api.evolution.com/message/sendMedia/test_instance')
          .with(
            headers: {
              'Content-Type' => 'application/json',
              'apikey' => 'test_api_token_123'
            },
            body: {
              number: '+1234567890',
              mediatype: 'image',
              media: 'https://example.com/image.jpg',
              fileName: 'campaign_image.jpg',
              caption: message_text
            }.to_json
          )
          .to return_status(200)
          .to return_body({ success: true, messageId: 'msg_456' }.to_json)
      end

      it 'sends multimedia message successfully' do
        campaign.update!(multimedia: multimedia)
        
        expect {
          described_class.perform_now(campaign, contact, message_text)
        }.to change(Message, :count).by(1)

        expect(campaign.reload.delivery_stats['sent']).to eq(1)
        
        message = Message.last
        expect(message.content).to eq(message_text)
      end
    end

    context 'with API errors' do
      let(:message_text) { 'Hello from campaign!' }

      context 'when API returns 4xx error' do
        before do
          stub_request(:post, 'https://api.evolution.com/message/sendText/test_instance')
            .to return_status(400)
            .to return_body({ error: 'Invalid phone number' }.to_json)
        end

        it 'increments failed count and does not retry' do
          expect {
            described_class.perform_now(campaign, contact, message_text)
          }.not_to change(Message, :count)

          expect(campaign.reload.delivery_stats['failed']).to eq(1)
        end
      end

      context 'when API returns 5xx error' do
        before do
          stub_request(:post, 'https://api.evolution.com/message/sendText/test_instance')
            .to return_status(500)
            .to return_body({ error: 'Internal server error' }.to_json)
        end

        it 'raises error for retry mechanism' do
          expect {
            described_class.perform_now(campaign, contact, message_text)
          }.to raise_error(StandardError, /API request failed/)
        end
      end

      context 'when network error occurs' do
        before do
          stub_request(:post, 'https://api.evolution.com/message/sendText/test_instance')
            .to_raise(Net::TimeoutError)
        end

        it 'raises error for retry mechanism' do
          expect {
            described_class.perform_now(campaign, contact, message_text)
          }.to raise_error(Net::TimeoutError)
        end
      end
    end

    context 'with missing API credentials' do
      let(:api_channel_without_creds) { create(:channel_api, account: account) }
      let(:api_inbox_without_creds) { api_channel_without_creds.inbox }
      let(:campaign_without_creds) { create(:whatsapp_api_campaign, account: account, inbox: api_inbox_without_creds) }

      it 'increments failed count when credentials are missing' do
        expect {
          described_class.perform_now(campaign_without_creds, contact, 'Hello')
        }.not_to change(Message, :count)

        expect(campaign_without_creds.reload.delivery_stats['failed']).to eq(1)
      end
    end

    context 'with missing contact_inbox' do
      let(:contact_without_inbox) { create(:contact, account: account) }

      it 'increments failed count when contact_inbox is missing' do
        expect {
          described_class.perform_now(campaign, contact_without_inbox, 'Hello')
        }.not_to change(Message, :count)

        expect(campaign.reload.delivery_stats['failed']).to eq(1)
      end
    end
  end

  describe 'private methods' do
    let(:job) { described_class.new }
    let(:credentials) do
      {
        'base_url' => 'https://api.evolution.com',
        'token' => 'test_token',
        'instance_name' => 'test_instance'
      }
    end

    describe '#build_text_payload' do
      it 'builds correct payload for text message' do
        payload = job.send(:build_text_payload, '+1234567890', 'Hello World')
        
        expect(payload).to eq({
          number: '+1234567890',
          text: 'Hello World'
        })
      end
    end

    describe '#build_media_payload' do
      let(:multimedia) do
        {
          'type' => 'image',
          'url' => 'https://example.com/image.jpg',
          'filename' => 'test.jpg'
        }
      end

      it 'builds correct payload for media message' do
        payload = job.send(:build_media_payload, '+1234567890', 'Caption text', multimedia)
        
        expect(payload).to eq({
          number: '+1234567890',
          mediatype: 'image',
          media: 'https://example.com/image.jpg',
          fileName: 'test.jpg',
          caption: 'Caption text'
        })
      end
    end

    describe '#get_api_endpoint' do
      it 'returns correct endpoint for text messages' do
        endpoint = job.send(:get_api_endpoint, credentials, false)
        expect(endpoint).to eq('https://api.evolution.com/message/sendText/test_instance')
      end

      it 'returns correct endpoint for media messages' do
        endpoint = job.send(:get_api_endpoint, credentials, true)
        expect(endpoint).to eq('https://api.evolution.com/message/sendMedia/test_instance')
      end
    end

    describe '#should_retry?' do
      it 'returns false for 4xx errors' do
        expect(job.send(:should_retry?, 400)).to be false
        expect(job.send(:should_retry?, 404)).to be false
        expect(job.send(:should_retry?, 422)).to be false
      end

      it 'returns true for 5xx errors' do
        expect(job.send(:should_retry?, 500)).to be true
        expect(job.send(:should_retry?, 502)).to be true
        expect(job.send(:should_retry?, 503)).to be true
      end

      it 'returns true for other status codes' do
        expect(job.send(:should_retry?, 0)).to be true
        expect(job.send(:should_retry?, 999)).to be true
      end
    end
  end

  describe 'job configuration' do
    it 'has correct queue name' do
      expect(described_class.queue_name).to eq('default')
    end

    it 'has retry configuration' do
      expect(described_class.retry_on).to include(StandardError)
    end
  end
end