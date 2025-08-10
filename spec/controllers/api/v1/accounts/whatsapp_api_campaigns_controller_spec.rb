require 'rails_helper'

RSpec.describe Api::V1::Accounts::WhatsappApiCampaignsController, type: :controller do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:api_inbox) { create(:inbox_with_api_channel, account: account) }
  let(:web_inbox) { create(:inbox, account: account) }

  before do
    # Enable the feature flag for testing
    allow(account).to receive(:feature_enabled?).with(:whatsapp_api_campaigns).and_return(true)
  end

  describe 'GET #index' do
    context 'when user is authenticated' do
      before { sign_in(administrator) }

      let!(:campaign1) { create(:whatsapp_api_campaign, account: account, inbox: api_inbox) }
      let!(:campaign2) { create(:whatsapp_api_campaign, account: account, inbox: api_inbox) }
      let!(:other_account_campaign) { create(:whatsapp_api_campaign) }

      it 'returns campaigns for the account' do
        get :index, params: { account_id: account.id }
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data'].length).to eq(2)
        expect(json_response['data'].map { |c| c['id'] }).to contain_exactly(campaign1.id, campaign2.id)
      end

      it 'filters by inbox_id when provided' do
        other_inbox = create(:inbox_with_api_channel, account: account)
        campaign3 = create(:whatsapp_api_campaign, account: account, inbox: other_inbox)
        
        get :index, params: { account_id: account.id, inbox_id: api_inbox.id }
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data'].length).to eq(2)
        expect(json_response['data'].map { |c| c['id'] }).to contain_exactly(campaign1.id, campaign2.id)
      end

      it 'returns empty array when no campaigns exist' do
        WhatsappApiCampaign.destroy_all
        
        get :index, params: { account_id: account.id }
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']).to eq([])
      end
    end

    context 'when feature is disabled' do
      before do
        allow(account).to receive(:feature_enabled?).with(:whatsapp_api_campaigns).and_return(false)
        sign_in(administrator)
      end

      it 'returns forbidden' do
        get :index, params: { account_id: account.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get :index, params: { account_id: account.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    let(:campaign) { create(:whatsapp_api_campaign, account: account, inbox: api_inbox) }

    context 'when user is authenticated' do
      before { sign_in(administrator) }

      it 'returns the campaign' do
        get :show, params: { account_id: account.id, id: campaign.id }
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['id']).to eq(campaign.id)
        expect(json_response['data']['title']).to eq(campaign.title)
      end

      it 'returns not found for non-existent campaign' do
        get :show, params: { account_id: account.id, id: 999999 }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    context 'when user is authenticated' do
      before { sign_in(administrator) }

      let(:valid_params) do
        {
          account_id: account.id,
          whatsapp_api_campaign: {
            title: 'Test Campaign',
            message: 'Hello World!',
            inbox_id: api_inbox.id,
            scheduled_at: 1.hour.from_now.iso8601,
            audience: { contact_ids: [1, 2, 3] }
          }
        }
      end

      it 'creates a new campaign with valid params' do
        expect {
          post :create, params: valid_params
        }.to change(WhatsappApiCampaign, :count).by(1)
        
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['title']).to eq('Test Campaign')
        expect(json_response['data']['message']).to eq('Hello World!')
      end

      it 'sets the sender to current user' do
        post :create, params: valid_params
        
        campaign = WhatsappApiCampaign.last
        expect(campaign.sender).to eq(administrator)
      end

      it 'returns validation errors for invalid params' do
        invalid_params = valid_params.deep_dup
        invalid_params[:whatsapp_api_campaign][:title] = ''
        
        post :create, params: invalid_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('title')
      end

      it 'rejects non-API inbox' do
        invalid_params = valid_params.deep_dup
        invalid_params[:whatsapp_api_campaign][:inbox_id] = web_inbox.id
        
        post :create, params: invalid_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('inbox')
      end
    end
  end

  describe 'PATCH #update' do
    let(:campaign) { create(:whatsapp_api_campaign, account: account, inbox: api_inbox, status: :pending) }

    context 'when user is authenticated' do
      before { sign_in(administrator) }

      it 'updates the campaign with valid params' do
        patch :update, params: {
          account_id: account.id,
          id: campaign.id,
          whatsapp_api_campaign: { title: 'Updated Title' }
        }
        
        expect(response).to have_http_status(:ok)
        expect(campaign.reload.title).to eq('Updated Title')
      end

      it 'prevents updating running campaigns' do
        campaign.update!(status: :running)
        
        patch :update, params: {
          account_id: account.id,
          id: campaign.id,
          whatsapp_api_campaign: { title: 'Updated Title' }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('cannot be updated')
      end

      it 'prevents updating completed campaigns' do
        campaign.update!(status: :completed)
        
        patch :update, params: {
          account_id: account.id,
          id: campaign.id,
          whatsapp_api_campaign: { title: 'Updated Title' }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:campaign) { create(:whatsapp_api_campaign, account: account, inbox: api_inbox, status: :pending) }

    context 'when user is authenticated' do
      before { sign_in(administrator) }

      it 'deletes pending campaigns' do
        expect {
          delete :destroy, params: { account_id: account.id, id: campaign.id }
        }.to change(WhatsappApiCampaign, :count).by(-1)
        
        expect(response).to have_http_status(:no_content)
      end

      it 'prevents deleting running campaigns' do
        campaign.update!(status: :running)
        
        expect {
          delete :destroy, params: { account_id: account.id, id: campaign.id }
        }.not_to change(WhatsappApiCampaign, :count)
        
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'allows deleting failed campaigns' do
        campaign.update!(status: :failed)
        
        expect {
          delete :destroy, params: { account_id: account.id, id: campaign.id }
        }.to change(WhatsappApiCampaign, :count).by(-1)
        
        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe 'POST #trigger' do
    let(:campaign) { create(:whatsapp_api_campaign, account: account, inbox: api_inbox, status: :pending, scheduled_at: 1.hour.ago) }

    context 'when user is authenticated' do
      before { sign_in(administrator) }

      it 'triggers the campaign' do
        expect(WhatsappApi::CampaignExecutorJob).to receive(:perform_later).with(campaign)
        
        post :trigger, params: { account_id: account.id, id: campaign.id }
        
        expect(response).to have_http_status(:ok)
        expect(campaign.reload.status).to eq('running')
      end

      it 'prevents triggering future campaigns' do
        campaign.update!(scheduled_at: 1.hour.from_now)
        
        post :trigger, params: { account_id: account.id, id: campaign.id }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('not ready')
      end

      it 'prevents triggering completed campaigns' do
        campaign.update!(status: :completed)
        
        post :trigger, params: { account_id: account.id, id: campaign.id }
        
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'authorization' do
    let(:campaign) { create(:whatsapp_api_campaign, account: account, inbox: api_inbox) }

    context 'when user is an agent' do
      before { sign_in(agent) }

      it 'allows read access' do
        get :index, params: { account_id: account.id }
        expect(response).to have_http_status(:ok)
        
        get :show, params: { account_id: account.id, id: campaign.id }
        expect(response).to have_http_status(:ok)
      end

      it 'denies write access' do
        post :create, params: {
          account_id: account.id,
          whatsapp_api_campaign: { title: 'Test' }
        }
        expect(response).to have_http_status(:forbidden)
        
        patch :update, params: {
          account_id: account.id,
          id: campaign.id,
          whatsapp_api_campaign: { title: 'Updated' }
        }
        expect(response).to have_http_status(:forbidden)
        
        delete :destroy, params: { account_id: account.id, id: campaign.id }
        expect(response).to have_http_status(:forbidden)
        
        post :trigger, params: { account_id: account.id, id: campaign.id }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end