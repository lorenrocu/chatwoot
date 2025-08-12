<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Select from 'dashboard/components-next/selectmenu/SelectMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Accordion from 'dashboard/components-next/Accordion/Accordion.vue';
import Banner from 'dashboard/components-next/banner/Banner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import FileUpload from 'vue-upload-component';

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
  is_scheduled: false,
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
  <div class="space-y-6">
    <!-- Information Banner -->
    <Banner color="blue" class="mb-6">
      <div class="flex items-start gap-3">
        <Icon icon="i-lucide-info" class="w-4 h-4 mt-0.5 text-n-blue-11" />
        <div class="text-sm">
          <p class="font-medium mb-1">{{ t('CAMPAIGN.WHATSAPP_API.FORM.INFO_TITLE') }}</p>
          <p class="text-n-blue-11">{{ t('CAMPAIGN.WHATSAPP_API.FORM.INFO_DESCRIPTION') }}</p>
        </div>
      </div>
    </Banner>

    <form @submit.prevent="onSubmit" class="space-y-6">
      <!-- Basic Configuration Section -->
      <Accordion :title="t('CAMPAIGN.WHATSAPP_API.FORM.SECTIONS.BASIC_CONFIG')" :is-open="true">
        <div class="space-y-4 pt-4">
          <!-- Campaign Title -->
          <div>
            <label for="title" class="mb-2 text-sm font-medium text-n-slate-12 flex items-center gap-2">
              <Icon icon="i-lucide-type" class="w-4 h-4" />
              {{ t('CAMPAIGN.WHATSAPP_API.FORM.TITLE') }} *
            </label>
            <Input
              id="title"
              v-model="form.title"
              :placeholder="t('CAMPAIGN.WHATSAPP_API.FORM.TITLE_PLACEHOLDER')"
              :has-error="!!errors.title"
              :message="errors.title"
              required
            />
          </div>

          <!-- Inbox Selection -->
          <div>
            <label for="inbox" class="mb-2 text-sm font-medium text-n-slate-12 flex items-center gap-2">
              <Icon icon="i-lucide-inbox" class="w-4 h-4" />
              {{ t('CAMPAIGN.WHATSAPP_API.FORM.INBOX') }} *
            </label>
            <Select
              id="inbox"
              v-model="form.inbox_id"
              :options="inboxOptions"
              :placeholder="t('CAMPAIGN.WHATSAPP_API.FORM.INBOX_PLACEHOLDER')"
              :has-error="!!errors.inbox_id"
              :message="errors.inbox_id"
              required
            />
          </div>
        </div>
      </Accordion>

      <!-- Message Content Section -->
      <Accordion :title="t('CAMPAIGN.WHATSAPP_API.FORM.SECTIONS.MESSAGE_CONTENT')" :is-open="true">
        <div class="space-y-4 pt-4">
          <!-- Media Type -->
          <div>
            <label for="media-type" class="mb-2 text-sm font-medium text-n-slate-12 flex items-center gap-2">
              <Icon icon="i-lucide-image" class="w-4 h-4" />
              {{ t('CAMPAIGN.WHATSAPP_API.FORM.MEDIA_TYPE') }}
            </label>
            <Select
              id="media-type"
              v-model="form.media_type"
              :options="mediaTypes"
            />
          </div>

          <!-- Media Upload (if not text) -->
          <div v-if="form.media_type !== 'text'" class="p-4 bg-n-alpha-2 rounded-lg border border-dashed border-n-weak">
            <label for="media-upload" class="mb-2 text-sm font-medium text-n-slate-12 flex items-center gap-2">
              <Icon icon="i-lucide-upload" class="w-4 h-4" />
              {{ t('CAMPAIGN.WHATSAPP_API.FORM.MEDIA_UPLOAD') }}
            </label>
            <FileUpload
              id="media-upload"
              :accept="form.media_type === 'image' ? 'image/*' : form.media_type === 'video' ? 'video/*' : form.media_type === 'audio' ? 'audio/*' : '*/*'"
              @upload="onFileUpload"
              :has-error="!!errors.media_url"
              :message="errors.media_url"
            />
          </div>

          <!-- Message Content -->
          <div>
            <label for="message" class="mb-2 text-sm font-medium text-n-slate-12 flex items-center gap-2">
              <Icon icon="i-lucide-message-square" class="w-4 h-4" />
              {{ t('CAMPAIGN.WHATSAPP_API.FORM.MESSAGE') }} *
            </label>
            <TextArea
              id="message"
              v-model="form.message"
              :placeholder="t('CAMPAIGN.WHATSAPP_API.FORM.MESSAGE_PLACEHOLDER')"
              :has-error="!!errors.message"
              :message="errors.message"
              :show-character-count="true"
              :max-length="4096"
              :auto-height="true"
              :min-height="'6rem'"
              required
            />
            <div class="mt-2 p-3 bg-n-alpha-2 rounded-lg">
              <p class="text-sm text-n-slate-11 flex items-start gap-2">
                <Icon icon="i-lucide-lightbulb" class="w-4 h-4 mt-0.5 text-n-amber-9" />
                {{ t('CAMPAIGN.WHATSAPP_API.FORM.MESSAGE_HINT') }}
              </p>
            </div>
          </div>
        </div>
      </Accordion>

      <!-- Audience Section -->
      <Accordion :title="t('CAMPAIGN.WHATSAPP_API.FORM.SECTIONS.AUDIENCE')" :is-open="true">
        <div class="space-y-4 pt-4">
          <!-- Audience Selection -->
          <div>
            <label class="mb-2 text-sm font-medium text-n-slate-12 flex items-center gap-2">
              <Icon icon="i-lucide-users" class="w-4 h-4" />
              {{ t('CAMPAIGN.WHATSAPP_API.FORM.AUDIENCE') }}
            </label>
            <Select
              v-model="selectedAudience"
              :options="audienceOptions"
            />
          </div>

          <!-- Label Selection (if labels audience) -->
          <div v-if="selectedAudience === 'labels'">
            <label class="mb-2 text-sm font-medium text-n-slate-12 flex items-center gap-2">
              <Icon icon="i-lucide-tags" class="w-4 h-4" />
              {{ t('CAMPAIGN.WHATSAPP_API.FORM.SELECT_LABELS') }}
            </label>
            <Select
              v-model="selectedLabels"
              :options="labelOptions"
              multiple
              :placeholder="t('CAMPAIGN.WHATSAPP_API.FORM.SELECT_LABELS_PLACEHOLDER')"
            />
          </div>

          <!-- Custom Filters (if custom audience) -->
          <div v-if="selectedAudience === 'custom'" class="space-y-4">
            <label class="mb-2 text-sm font-medium text-n-slate-12 flex items-center gap-2">
              <Icon icon="i-lucide-filter" class="w-4 h-4" />
              {{ t('CAMPAIGN.WHATSAPP_API.FORM.CUSTOM_FILTERS') }}
            </label>
            <div class="p-4 bg-n-alpha-2 rounded-lg">
              <p class="text-sm text-n-slate-11 flex items-start gap-2">
                <Icon icon="i-lucide-info" class="w-4 h-4 mt-0.5" />
                {{ t('CAMPAIGN.WHATSAPP_API.FORM.CUSTOM_FILTERS_HINT') }}
              </p>
              <!-- Add custom filter components here -->
            </div>
          </div>
        </div>
      </Accordion>

      <!-- Scheduling Section -->
      <Accordion :title="t('CAMPAIGN.WHATSAPP_API.FORM.SECTIONS.SCHEDULING')">
        <div class="space-y-4 pt-4">
          <!-- Schedule Toggle -->
          <div class="flex items-center justify-between p-4 bg-n-alpha-2 rounded-lg">
            <div class="flex items-center gap-3">
              <Icon icon="i-lucide-clock" class="w-5 h-5 text-n-slate-11" />
              <div>
                <p class="text-sm font-medium text-n-slate-12">
                  {{ t('CAMPAIGN.WHATSAPP_API.FORM.SCHEDULE_CAMPAIGN') }}
                </p>
                <p class="text-xs text-n-slate-11">
                  {{ t('CAMPAIGN.WHATSAPP_API.FORM.SCHEDULE_DESCRIPTION') }}
                </p>
              </div>
            </div>
            <Switch v-model="form.is_scheduled" />
          </div>

          <!-- Scheduled Time (if enabled) -->
          <div v-if="form.is_scheduled" class="transition-all duration-200">
            <label for="scheduled-at" class="mb-2 text-sm font-medium text-n-slate-12 flex items-center gap-2">
              <Icon icon="i-lucide-calendar" class="w-4 h-4" />
              {{ t('CAMPAIGN.WHATSAPP_API.FORM.SCHEDULED_AT') }}
            </label>
            <Input
              id="scheduled-at"
              v-model="form.scheduled_at"
              type="datetime-local"
              :placeholder="t('CAMPAIGN.WHATSAPP_API.FORM.SCHEDULED_AT_PLACEHOLDER')"
            />
            <div class="mt-2 p-3 bg-n-alpha-2 rounded-lg">
              <p class="text-sm text-n-slate-11 flex items-start gap-2">
                <Icon icon="i-lucide-info" class="w-4 h-4 mt-0.5" />
                {{ t('CAMPAIGN.WHATSAPP_API.FORM.SCHEDULED_AT_HINT') }}
              </p>
            </div>
          </div>
        </div>
      </Accordion>

      <!-- Form Actions -->
      <div class="flex justify-end space-x-3 pt-6 border-t border-n-weak">
        <Button
          variant="outline"
          color="slate"
          @click="onCancel"
          :disabled="isCreating"
        >
          {{ t('CAMPAIGN.WHATSAPP_API.FORM.CANCEL') }}
        </Button>
        <Button
          type="submit"
          color="blue"
          :loading="isCreating"
          :disabled="isCreating"
        >
          <Icon icon="i-lucide-send" class="w-4 h-4 mr-2" />
          {{ form.is_scheduled ? t('CAMPAIGN.WHATSAPP_API.FORM.SCHEDULE') : t('CAMPAIGN.WHATSAPP_API.FORM.CREATE') }}
        </Button>
      </div>
    </form>
  </div>
</template>