class RecreateWhatsappApiCampaigns < ActiveRecord::Migration[7.0]
  def up
    # Drop the existing table if it exists to start fresh
    if table_exists?(:whatsapp_api_campaigns)
      drop_table :whatsapp_api_campaigns
    end
    
    # Drop the function if it exists
    execute "DROP FUNCTION IF EXISTS create_whatsapp_api_campaign_display_id_sequence() CASCADE;"
    
    # Create the table from scratch
    create_table :whatsapp_api_campaigns do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.integer :display_id, null: false
      t.string :title, null: false
      t.text :message, null: false
      t.jsonb :audience, default: {}
      t.datetime :scheduled_at
      t.integer :status, default: 0, null: false # 0: pending, 1: running, 2: completed, 3: failed
      t.jsonb :multimedia, default: {}
      t.jsonb :delivery_stats, default: { sent: 0, delivered: 0, failed: 0 }
      t.text :error_message
      t.integer :sender_id
      t.boolean :enabled, default: true
      t.timestamps
    end

    # Add all indexes
    add_index :whatsapp_api_campaigns, :account_id
    add_index :whatsapp_api_campaigns, :inbox_id
    add_index :whatsapp_api_campaigns, :status
    add_index :whatsapp_api_campaigns, :scheduled_at
    add_index :whatsapp_api_campaigns, [:account_id, :display_id], unique: true

    # Create sequence function for display_id per account
    execute <<-SQL
      CREATE OR REPLACE FUNCTION create_whatsapp_api_campaign_display_id_sequence()
      RETURNS TRIGGER AS $$
      DECLARE
        sequence_name TEXT;
      BEGIN
        sequence_name := 'whatsapp_api_camp_dpid_seq_' || NEW.account_id;
        
        -- Create sequence if it doesn't exist
        EXECUTE 'CREATE SEQUENCE IF NOT EXISTS ' || sequence_name || ' START 1';
        
        -- Set display_id
        EXECUTE 'SELECT nextval($1)' INTO NEW.display_id USING sequence_name;
        
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Create trigger
    execute <<-SQL
      CREATE TRIGGER set_whatsapp_api_campaign_display_id
        BEFORE INSERT ON whatsapp_api_campaigns
        FOR EACH ROW
        EXECUTE FUNCTION create_whatsapp_api_campaign_display_id_sequence();
    SQL
  end

  def down
    drop_table :whatsapp_api_campaigns if table_exists?(:whatsapp_api_campaigns)
    execute "DROP FUNCTION IF EXISTS create_whatsapp_api_campaign_display_id_sequence() CASCADE;"
  end
end