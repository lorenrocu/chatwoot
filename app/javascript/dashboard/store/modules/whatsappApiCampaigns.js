import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import WhatsAppApiCampaignAPI from '../../api/whatsappApiCampaigns';

const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getWhatsAppApiCampaigns(_state) {
    return (_state.records || []).filter(
      record => record.inbox?.channel_type === 'Channel::Api'
    );
  },
  getCampaign: _state => id => {
    return _state.records.find(record => record.id === Number(id));
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async function getWhatsAppApiCampaigns({ commit }) {
    commit(types.SET_WHATSAPP_API_CAMPAIGN_UI_FLAG, { isFetching: true });
    try {
      const response = await WhatsAppApiCampaignAPI.get();
      commit(types.SET_WHATSAPP_API_CAMPAIGNS, response.data);
    } catch (error) {
      // Handle error
    } finally {
      commit(types.SET_WHATSAPP_API_CAMPAIGN_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createWhatsAppApiCampaign({ commit }, campaignObj) {
    commit(types.SET_WHATSAPP_API_CAMPAIGN_UI_FLAG, { isCreating: true });
    try {
      // Wrap the campaign data in the expected format for the API
      const payload = {
        whatsapp_api_campaign: campaignObj
      };
      const response = await WhatsAppApiCampaignAPI.create(payload);
      commit(types.ADD_WHATSAPP_API_CAMPAIGN, response.data);
      return response;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_WHATSAPP_API_CAMPAIGN_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updateWhatsAppApiCampaign(
    { commit },
    { id, ...campaignObj }
  ) {
    commit(types.SET_WHATSAPP_API_CAMPAIGN_UI_FLAG, { isUpdating: true });
    try {
      const response = await WhatsAppApiCampaignAPI.update(id, campaignObj);
      commit(types.EDIT_WHATSAPP_API_CAMPAIGN, response.data);
      return response;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_WHATSAPP_API_CAMPAIGN_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteWhatsAppApiCampaign({ commit }, id) {
    commit(types.SET_WHATSAPP_API_CAMPAIGN_UI_FLAG, { isDeleting: true });
    try {
      await WhatsAppApiCampaignAPI.delete(id);
      commit(types.DELETE_WHATSAPP_API_CAMPAIGN, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_WHATSAPP_API_CAMPAIGN_UI_FLAG, { isDeleting: false });
    }
  },

  trigger: async function triggerWhatsAppApiCampaign({ commit }, id) {
    try {
      const response = await WhatsAppApiCampaignAPI.trigger(id);
      commit(types.EDIT_WHATSAPP_API_CAMPAIGN, response.data);
      return response;
    } catch (error) {
      throw new Error(error);
    }
  },
};

export const mutations = {
  [types.SET_WHATSAPP_API_CAMPAIGN_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_WHATSAPP_API_CAMPAIGNS]: MutationHelpers.set,
  [types.ADD_WHATSAPP_API_CAMPAIGN]: MutationHelpers.create,
  [types.EDIT_WHATSAPP_API_CAMPAIGN]: MutationHelpers.update,
  [types.DELETE_WHATSAPP_API_CAMPAIGN]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};