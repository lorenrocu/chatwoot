<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';

import Input from 'dashboard/components-next/Input/Input.vue';
import Textarea from 'dashboard/components-next/Textarea/Textarea.vue';
import Select from 'dashboard/components-next/Select/Select.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Label from 'dashboard/components-next/Label/Label.vue';
import FileUpload from 'dashboard/components-next/FileUpload/FileUpload.vue';

const props = defineProps({
  inboxes: {
    type: Array,
    required: true,
  },
  isCreating: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();
const store = useStore();

const form = ref({
  title: '',
  message: '',
  inbox_id: null,
  audience: [],
  scheduled_at: null,
  enabled: true,
  media_url: '',
  media_type: 'text',
});

const errors = ref({});

const mediaTypes = [
  { label: t('CAMPAIGN.WHATSAPP_API.MEDIA_TYPE.TEXT'), value: 'text' },
  { label: t('CAMPAIGN.WHATSAPP_API.MEDIA_TYPE.IMAGE'), value: 'image' },
  { label: t('CAMPAIGN.WHATSAPP_API.MEDIA_TYPE.DOCUMENT'), value: 'document' },
  { label: t('CAMPAIGN.WHATSAPP_API.MEDIA_TYPE.VIDEO'), value: 'video' },
  { label: t('CAMPAIGN.WHATSAPP_API.MEDIA_TYPE.AUDIO'), value: 'audio' },
];

const inboxOptions = computed(() => {
  return props.inboxes.map(inbox => ({
    label: inbox.name,
    value: inbox.id,
  }));
});

const audienceOptions = [
  { label: t('CAMPAIGN.WHATSAPP_API.AUDIENCE.ALL_CONTACTS'), value: 'all_contacts' },
  { label: t('CAMPAIGN.WHATSAPP_API.AUDIENCE.LABELS'), value: 'labels' },
  { label: t('CAMPAIGN.WHATSAPP_API.AUDIENCE.CUSTOM'), value: 'custom' },
];

const selectedAudience = ref('all_contacts');
const selectedLabels = ref([]);
const customFilters = ref({});

const labels = computed(() => store.getters['labels/getLabels']);

const labelOptions = computed(() => {
  return labels.value.map(label => ({
    label: label.title,
    value: label.id,
  }));
});

const validateForm = () => {
  errors.value = {};
  
  if (!form.value.title.trim()) {
    errors.value.title = t('CAMPAIGN.WHATSAPP_API.VALIDATIONS.TITLE_REQUIRED');
  }
  
  if (!form.value.message.trim()) {
    errors.value.message = t('CAMPAIGN.WHATSAPP_API.VALIDATIONS.MESSAGE_REQUIRED');
  }
  
  if (!form.value.inbox_id) {
    errors.value.inbox_id = t('CAMPAIGN.WHATSAPP_API.VALIDATIONS.INBOX_REQUIRED');
  }
  
  if (form.value.media_type !== 'text' && !form.value.media_url.trim()) {
    errors.value.media_url = t('CAMPAIGN.WHATSAPP_API.VALIDATIONS.MEDIA_URL_REQUIRED');
  }
  
  return Object.keys(errors.value).length === 0;
};

const onSubmit = () => {
  if (!validateForm()) return;
  
  const campaignData = {
    ...form.value,
    audience: buildAudienceConfig(),
  };
  
  emit('submit', campaignData);
};

const buildAudienceConfig = () => {
  switch (selectedAudience.value) {
    case 'all_contacts':
      return { type: 'all_contacts' };
    case 'labels':
      return { type: 'labels', label_ids: selectedLabels.value };
    case 'custom':
      return { type: 'custom', filters: customFilters.value };
    default:
      return { type: 'all_contacts' };
  }
};

const onCancel = () => {
  emit('cancel');
};

const onFileUpload = (file) => {
  // Handle file upload logic here
  form.value.media_url = file.url;
};

watch(() => form.value.media_type, (newType) => {
  if (newType === 'text') {
    form.value.media_url = '';
  }
});
</script>

<template>
  <form @submit.prevent="onSubmit" class="space-y-6">
    <!-- Campaign Title -->
    <div>
      <Label for="title" required>
        {{ t('CAMPAIGN.WHATSAPP_API.FORM.TITLE') }}
      </Label>
      <Input
        id="title"
        v-model="form.title"
        :placeholder="t('CAMPAIGN.WHATSAPP_API.FORM.TITLE_PLACEHOLDER')"
        :error="errors.title"
        required
      />
    </div>

    <!-- Inbox Selection -->
    <div>
      <Label for="inbox" required>
        {{ t('CAMPAIGN.WHATSAPP_API.FORM.INBOX') }}
      </Label>
      <Select
        id="inbox"
        v-model="form.inbox_id"
        :options="inboxOptions"
        :placeholder="t('CAMPAIGN.WHATSAPP_API.FORM.INBOX_PLACEHOLDER')"
        :error="errors.inbox_id"
        required
      />
    </div>

    <!-- Media Type -->
    <div>
      <Label for="media-type">
        {{ t('CAMPAIGN.WHATSAPP_API.FORM.MEDIA_TYPE') }}
      </Label>
      <Select
        id="media-type"
        v-model="form.media_type"
        :options="mediaTypes"
      />
    </div>

    <!-- Media Upload (if not text) -->
    <div v-if="form.media_type !== 'text'">
      <Label for="media-upload">
        {{ t('CAMPAIGN.WHATSAPP_API.FORM.MEDIA_UPLOAD') }}
      </Label>
      <FileUpload
        id="media-upload"
        :accept="form.media_type === 'image' ? 'image/*' : form.media_type === 'video' ? 'video/*' : form.media_type === 'audio' ? 'audio/*' : '*/*'"
        @upload="onFileUpload"
        :error="errors.media_url"
      />
    </div>

    <!-- Message Content -->
    <div>
      <Label for="message" required>
        {{ t('CAMPAIGN.WHATSAPP_API.FORM.MESSAGE') }}
      </Label>
      <Textarea
        id="message"
        v-model="form.message"
        :placeholder="t('CAMPAIGN.WHATSAPP_API.FORM.MESSAGE_PLACEHOLDER')"
        :error="errors.message"
        rows="4"
        required
      />
      <p class="text-sm text-slate-600 mt-1">
        {{ t('CAMPAIGN.WHATSAPP_API.FORM.MESSAGE_HINT') }}
      </p>
    </div>

    <!-- Audience Selection -->
    <div>
      <Label>
        {{ t('CAMPAIGN.WHATSAPP_API.FORM.AUDIENCE') }}
      </Label>
      <Select
        v-model="selectedAudience"
        :options="audienceOptions"
      />
    </div>

    <!-- Label Selection (if labels audience) -->
    <div v-if="selectedAudience === 'labels'">
      <Label>
        {{ t('CAMPAIGN.WHATSAPP_API.FORM.SELECT_LABELS') }}
      </Label>
      <Select
        v-model="selectedLabels"
        :options="labelOptions"
        multiple
        :placeholder="t('CAMPAIGN.WHATSAPP_API.FORM.SELECT_LABELS_PLACEHOLDER')"
      />
    </div>

    <!-- Custom Filters (if custom audience) -->
    <div v-if="selectedAudience === 'custom'" class="space-y-4">
      <Label>
        {{ t('CAMPAIGN.WHATSAPP_API.FORM.CUSTOM_FILTERS') }}
      </Label>
      <p class="text-sm text-slate-600">
        {{ t('CAMPAIGN.WHATSAPP_API.FORM.CUSTOM_FILTERS_HINT') }}
      </p>
      <!-- Add custom filter components here -->
    </div>

    <!-- Scheduled Time -->
    <div>
      <Label for="scheduled-at">
        {{ t('CAMPAIGN.WHATSAPP_API.FORM.SCHEDULED_AT') }}
      </Label>
      <Input
        id="scheduled-at"
        v-model="form.scheduled_at"
        type="datetime-local"
        :placeholder="t('CAMPAIGN.WHATSAPP_API.FORM.SCHEDULED_AT_PLACEHOLDER')"
      />
      <p class="text-sm text-slate-600 mt-1">
        {{ t('CAMPAIGN.WHATSAPP_API.FORM.SCHEDULED_AT_HINT') }}
      </p>
    </div>

    <!-- Form Actions -->
    <div class="flex justify-end space-x-3 pt-6 border-t">
      <Button
        variant="outline"
        @click="onCancel"
        :disabled="isCreating"
      >
        {{ t('CAMPAIGN.WHATSAPP_API.FORM.CANCEL') }}
      </Button>
      <Button
        type="submit"
        :loading="isCreating"
        :disabled="isCreating"
      >
        {{ t('CAMPAIGN.WHATSAPP_API.FORM.CREATE') }}
      </Button>
    </div>
  </form>
</template>