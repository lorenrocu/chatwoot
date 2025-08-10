import ApiClient from './ApiClient';

class WhatsAppApiCampaignsAPI extends ApiClient {
  constructor() {
    super('whatsapp_api_campaigns', { accountScoped: true });
  }

  trigger(id) {
    return this.axios.post(`${this.url}/${id}/trigger`);
  }
}

export default new WhatsAppApiCampaignsAPI();