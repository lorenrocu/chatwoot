# == Schema Information
#
# Table name: whatsapp_api_campaigns
#
#  id             :bigint           not null, primary key
#  account_id     :bigint           not null
#  inbox_id       :bigint           not null
#  display_id     :integer          not null
#  title          :string           not null
#  message        :text             not null
#  audience       :jsonb            default({})
#  scheduled_at   :datetime
#  status         :integer          default("pending"), not null
#  multimedia     :jsonb            default({})
#  delivery_stats :jsonb            default({"sent"=>0, "delivered"=>0, "failed"=>0})
#  error_message  :text
#  sender_id      :integer
#  enabled        :boolean          default(true)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class WhatsappApiCampaign < ApplicationRecord
  include UrlHelper
  
  validates :account_id, presence: true
  validates :inbox_id, presence: true
  validates :title, presence: true
  validates :message, presence: true
  validate :validate_whatsapp_api_inbox
  validate :validate_scheduled_at_future
  validate :sender_must_belong_to_account
  validate :inbox_must_belong_to_account
  validate :prevent_completed_campaign_from_update, on: :update

  belongs_to :account
  belongs_to :inbox
  belongs_to :sender, class_name: 'User', optional: true

  enum status: { pending: 0, running: 1, completed: 2, failed: 3 }

  scope :scheduled_for_execution, -> { where('scheduled_at <= ? AND status = ?', Time.current, statuses[:pending]) }
  scope :by_account, ->(account_id) { where(account_id: account_id) }

  before_validation :set_default_scheduled_at
  after_commit :set_display_id, unless: :display_id?

  def trigger!
    return if completed? || failed?
    return if scheduled_at&.future?

    update!(status: :running)
    WhatsappApi::CampaignExecutorJob.perform_later(self)
  end

  def can_be_updated?
    pending? || failed?
  end

  def increment_sent!
    delivery_stats['sent'] = (delivery_stats['sent'] || 0) + 1
    save!
  end

  def increment_delivered!
    delivery_stats['delivered'] = (delivery_stats['delivered'] || 0) + 1
    save!
  end

  def increment_failed!
    delivery_stats['failed'] = (delivery_stats['failed'] || 0) + 1
    save!
  end

  def total_contacts
    return 0 if audience.blank?
    
    # Calculate based on audience filters
    # This will be implemented based on your audience selection logic
    audience['contact_ids']&.size || 0
  end

  def completion_percentage
    return 0 if total_contacts.zero?
    
    total_processed = delivery_stats['sent'] + delivery_stats['failed']
    (total_processed.to_f / total_contacts * 100).round(2)
  end

  private

  def validate_whatsapp_api_inbox
    return unless inbox

    unless inbox.channel_type == 'Channel::Api'
      errors.add(:inbox, 'must be an API Channel for WhatsApp API campaigns')
    end
  end

  def validate_scheduled_at_future
    return unless scheduled_at
    return if scheduled_at >= Time.current

    errors.add(:scheduled_at, 'must be in the future')
  end

  def set_default_scheduled_at
    self.scheduled_at ||= Time.current
  end

  def set_display_id
    reload
  end

  def inbox_must_belong_to_account
    return unless inbox
    return if inbox.account_id == account_id

    errors.add(:inbox_id, 'must belong to the same account as the campaign')
  end

  def sender_must_belong_to_account
    return unless sender
    return if account.users.exists?(id: sender.id)

    errors.add(:sender_id, 'must belong to the same account as the campaign')
  end

  def prevent_completed_campaign_from_update
    return unless status_changed?
    return unless status_was == 'completed'

    errors.add(:status, 'Cannot modify a completed campaign')
  end
end