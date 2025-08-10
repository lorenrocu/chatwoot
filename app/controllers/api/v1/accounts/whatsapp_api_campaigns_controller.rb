class Api::V1::Accounts::WhatsappApiCampaignsController < Api::V1::Accounts::BaseController
  before_action :check_whatsapp_api_campaigns_feature
  before_action :set_whatsapp_api_campaign, only: [:show, :update, :destroy, :trigger]
  before_action :validate_api_inbox, only: [:create, :update]

  def index
    @whatsapp_api_campaigns = Current.account.whatsapp_api_campaigns
                                             .includes(:inbox, :sender)
                                             .order(created_at: :desc)
                                             .page(params[:page])
  end

  def show; end

  def create
    @whatsapp_api_campaign = Current.account.whatsapp_api_campaigns.build(whatsapp_api_campaign_params)
    @whatsapp_api_campaign.sender = current_user
    
    if @whatsapp_api_campaign.save
      render json: @whatsapp_api_campaign, status: :created
    else
      render json: { errors: @whatsapp_api_campaign.errors }, status: :unprocessable_entity
    end
  end

  def update
    unless @whatsapp_api_campaign.can_be_updated?
      return render json: { error: 'Campaign cannot be updated in current status' }, status: :unprocessable_entity
    end

    if @whatsapp_api_campaign.update(whatsapp_api_campaign_params)
      render json: @whatsapp_api_campaign
    else
      render json: { errors: @whatsapp_api_campaign.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    unless @whatsapp_api_campaign.can_be_updated?
      return render json: { error: 'Campaign cannot be deleted in current status' }, status: :unprocessable_entity
    end

    @whatsapp_api_campaign.destroy!
    head :no_content
  end

  def trigger
    unless @whatsapp_api_campaign.pending?
      return render json: { error: 'Campaign can only be triggered when pending' }, status: :unprocessable_entity
    end

    @whatsapp_api_campaign.trigger!
    render json: { message: 'Campaign triggered successfully' }
  end

  private

  def set_whatsapp_api_campaign
    @whatsapp_api_campaign = Current.account.whatsapp_api_campaigns.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'WhatsApp API Campaign not found' }, status: :not_found
  end

  def whatsapp_api_campaign_params
    params.require(:whatsapp_api_campaign).permit(
      :title,
      :message,
      :inbox_id,
      :scheduled_at,
      :enabled,
      audience: {},
      multimedia: {}
    )
  end

  def validate_api_inbox
    return unless params.dig(:whatsapp_api_campaign, :inbox_id)

    inbox = Current.account.inboxes.find_by(id: params[:whatsapp_api_campaign][:inbox_id])
    
    unless inbox&.channel_type == 'Channel::Api'
      return render json: { error: 'Inbox must be an API Channel' }, status: :unprocessable_entity
    end

    # Ensure the API inbox is explicitly enabled for WhatsApp API campaigns (B1 flag)
    unless inbox.channel.whatsapp_api_enabled?
      return render json: { error: 'API Inbox is not enabled for WhatsApp API campaigns' }, status: :unprocessable_entity
    end
  end

  def check_whatsapp_api_campaigns_feature
    unless Current.account.feature_enabled?(:whatsapp_api_campaigns)
      render json: { error: 'WhatsApp API Campaigns feature is not enabled' }, status: :forbidden
    end
  end
end