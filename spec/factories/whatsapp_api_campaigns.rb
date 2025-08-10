FactoryBot.define do
  factory :whatsapp_api_campaign do
    account
    association :inbox, factory: :inbox_with_api_channel
    title { Faker::Lorem.sentence(word_count: 3) }
    message { Faker::Lorem.paragraph(sentence_count: 2) }
    scheduled_at { 1.hour.from_now }
    status { :pending }
    enabled { true }
    audience { { contact_ids: [] } }
    multimedia { {} }
    delivery_stats { { sent: 0, delivered: 0, failed: 0 } }
    
    association :sender, factory: :user

    trait :with_contacts do
      transient do
        contact_count { 3 }
      end
      
      after(:create) do |campaign, evaluator|
        contacts = create_list(:contact, evaluator.contact_count, account: campaign.account)
        
        # Create contact_inboxes for the API channel
        contacts.each_with_index do |contact, index|
          create(:contact_inbox, 
                 contact: contact, 
                 inbox: campaign.inbox, 
                 source_id: "+1555000#{1000 + index}")
        end
        
        campaign.update!(
          audience: { contact_ids: contacts.pluck(:id) }
        )
      end
    end

    trait :with_multimedia_image do
      multimedia do
        {
          type: 'image',
          url: 'https://example.com/image.jpg',
          filename: 'campaign_image.jpg'
        }
      end
    end

    trait :with_multimedia_document do
      multimedia do
        {
          type: 'document',
          url: 'https://example.com/document.pdf',
          filename: 'campaign_document.pdf'
        }
      end
    end

    trait :running do
      status { :running }
    end

    trait :completed do
      status { :completed }
      delivery_stats { { sent: 5, delivered: 4, failed: 1 } }
    end

    trait :failed do
      status { :failed }
      error_message { 'API connection failed' }
    end

    trait :scheduled_for_past do
      scheduled_at { 1.hour.ago }
    end

    trait :with_audience_filters do
      audience do
        {
          labels: ['vip', 'newsletter'],
          custom_attributes: {
            'subscription_type' => 'premium',
            'region' => 'north_america'
          }
        }
      end
    end
  end

  # Helper factory for inbox with API channel
  factory :inbox_with_api_channel, parent: :inbox do
    association :channel, factory: :channel_api_with_whatsapp_credentials
  end

  # Helper factory for API channel with WhatsApp credentials
  factory :channel_api_with_whatsapp_credentials, parent: :channel_api do
    additional_attributes do
      {
        whatsapp_api_credentials: {
          base_url: 'https://api.evolution.com',
          token: 'test_api_token_123',
          instance_name: 'test_instance'
        }
      }
    end
  end
end