<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

// Modal component is available globally as woot-modal
import WhatsAppApiCampaignForm from './WhatsAppApiCampaignForm.vue';

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();
const { showAlert } = useAlert();

const isCreating = ref(false);
const showModal = ref(true);

const inboxes = computed(() => {
  return store.getters['inboxes/getInboxes'].filter(
    inbox => inbox.channel_type === 'Channel::Api'
  );
});

const onClose = () => {
  showModal.value = false;
  emit('close');
};

const onSubmit = async campaignData => {
  try {
    isCreating.value = true;
    await store.dispatch('whatsappApiCampaigns/create', campaignData);
    showAlert(t('CAMPAIGN.WHATSAPP_API.CREATE.SUCCESS'));
    onClose();
  } catch (error) {
    showAlert(t('CAMPAIGN.WHATSAPP_API.CREATE.ERROR'));
  } finally {
    isCreating.value = false;
  }
};

onMounted(() => {
  store.dispatch('inboxes/get');
});
</script>

<template>
  <woot-modal
    v-model:show="showModal"
    :on-close="onClose"
    size="large"
  >
    <woot-modal-header
      :header-title="t('CAMPAIGN.WHATSAPP_API.NEW_CAMPAIGN')"
    />
    
    <div class="modal-content">
      <WhatsAppApiCampaignForm
        :inboxes="inboxes"
        :is-creating="isCreating"
        @submit="onSubmit"
        @cancel="onClose"
      />
    </div>
  </woot-modal>
</template>

<style scoped>
.modal-content {
  padding: 1.5625rem 2rem;
}
</style>