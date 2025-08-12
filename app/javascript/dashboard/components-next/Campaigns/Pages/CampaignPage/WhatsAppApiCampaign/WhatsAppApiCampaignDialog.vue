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
const showAlert = useAlert();

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
  console.log('Dialog received campaign data:', campaignData);
  try {
    isCreating.value = true;
    console.log('Dispatching create action...');
    const response = await store.dispatch('whatsappApiCampaigns/create', campaignData);
    console.log('Create response:', response);
    showAlert(t('CAMPAIGN.WHATSAPP_API.CREATE.SUCCESS'));
    onClose();
  } catch (error) {
    console.error('Create error:', error);
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
  <!-- Use Teleport to render modal outside the CampaignLayout clickaway zone -->
  <Teleport to="body">
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
  </Teleport>
</template>

<style scoped>
.modal-content {
  padding: 1.5625rem 2rem;
}
</style>