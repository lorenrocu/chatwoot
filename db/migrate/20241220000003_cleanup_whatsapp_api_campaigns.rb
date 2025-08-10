class CleanupWhatsappApiCampaigns < ActiveRecord::Migration[7.0]
  def up
    # This migration ensures the WhatsApp API campaigns table is in a clean state
    # and handles any inconsistencies from previous migration attempts
    
    if table_exists?(:whatsapp_api_campaigns)
      # Remove any duplicate or problematic indexes if they exist
      begin
        remove_index :whatsapp_api_campaigns, name: "index_whatsapp_api_campaigns_on_account_id" if index_exists?(:whatsapp_api_campaigns, name: "index_whatsapp_api_campaigns_on_account_id")
      rescue ActiveRecord::StatementInvalid
        # Index might not exist or might be in use, continue
      end
      
      # Ensure all required indexes exist
      add_index :whatsapp_api_campaigns, :account_id, name: "index_whatsapp_api_campaigns_on_account_id" unless index_exists?(:whatsapp_api_campaigns, :account_id)
      add_index :whatsapp_api_campaigns, :inbox_id, name: "index_whatsapp_api_campaigns_on_inbox_id" unless index_exists?(:whatsapp_api_campaigns, :inbox_id)
      add_index :whatsapp_api_campaigns, :status, name: "index_whatsapp_api_campaigns_on_status" unless index_exists?(:whatsapp_api_campaigns, :status)
      add_index :whatsapp_api_campaigns, :scheduled_at, name: "index_whatsapp_api_campaigns_on_scheduled_at" unless index_exists?(:whatsapp_api_campaigns, :scheduled_at)
      add_index :whatsapp_api_campaigns, [:account_id, :display_id], unique: true, name: "index_whatsapp_api_campaigns_on_account_id_and_display_id" unless index_exists?(:whatsapp_api_campaigns, [:account_id, :display_id])
      
      # Ensure the function exists
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

      # Ensure the trigger exists
      execute <<-SQL
        DO $$
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'set_whatsapp_api_campaign_display_id') THEN
            CREATE TRIGGER set_whatsapp_api_campaign_display_id
              BEFORE INSERT ON whatsapp_api_campaigns
              FOR EACH ROW
              EXECUTE FUNCTION create_whatsapp_api_campaign_display_id_sequence();
          END IF;
        END
        $$;
      SQL
    end
  end

  def down
    # This is a cleanup migration, no rollback needed
  end
end