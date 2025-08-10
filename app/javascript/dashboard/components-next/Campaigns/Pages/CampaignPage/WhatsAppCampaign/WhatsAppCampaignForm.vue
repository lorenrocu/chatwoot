<script setup>
import { reactive, computed, watch, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  inboxes: useMapGetter('inboxes/getApiInboxes'),
  getFilteredWhatsAppTemplates: useMapGetter(
    'inboxes/getFilteredWhatsAppTemplates'
  ),
};

const initialState = {
  title: '',
  inboxId: null,
  templateId: null,
  scheduledAt: null,
  selectedAudience: [],
};

const state = reactive({ ...initialState });
const templateParserRef = ref(null);

const rules = {
  title: { required, minLength: minLength(1) },
  inboxId: { required },
  templateId: { required },
  scheduledAt: { required },
  selectedAudience: { required },
};

const v$ = useVuelidate(rules, state);

const isCreating = computed(() => formState.uiFlags.value.isCreating);

const currentDateTime = computed(() => {
  // Added to disable the scheduled at field from being set to the current time
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({
    value: item[valueKey],
    label: item[labelKey],
  })) ?? [];

const audienceList = computed(() =>
  mapToOptions(formState.labels.value, 'id', 'title')
);

const inboxOptions = computed(() =>
  mapToOptions(formState.inboxes.value, 'id', 'name')
);

const hasNoEligibleInboxes = computed(() => inboxOptions.value.length === 0);

const templateOptions = computed(() => {
  if (!state.inboxId) return [];
  const templates = formState.getFilteredWhatsAppTemplates.value(state.inboxId);
  return templates.map(template => {
    // Create a more user-friendly label from template name
    const friendlyName = template.name
      .replace(/_/g, ' ')
      .replace(/\b\w/g, l => l.toUpperCase());

    return {
      value: template.id,
      label: `${friendlyName} (${template.language || 'en'})`,
      template: template,
    };
  });
});

const selectedTemplate = computed(() => {
  if (!state.templateId) return null;
  return templateOptions.value.find(option => option.value === state.templateId)
    ?.template;
});

const getErrorMessage = (field, errorKey) => {
  const baseKey = 'CAMPAIGN.WHATSAPP_API.CREATE.FORM';
  return v$.value[field].$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
};

const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  inbox: getErrorMessage('inboxId', 'INBOX'),
  template: getErrorMessage('templateId', 'TEMPLATE'),
  scheduledAt: getErrorMessage('scheduledAt', 'SCHEDULED_AT'),
  audience: getErrorMessage('selectedAudience', 'AUDIENCE'),
}));

const hasRequiredTemplateParams = computed(() => {
  return templateParserRef.value?.v$?.$invalid === false || true;
});

const isSubmitDisabled = computed(
  () => v$.value.$invalid || !hasRequiredTemplateParams.value
);

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const resetState = () => {
  Object.assign(state, initialState);
  v$.value.$reset();
};

const handleCancel = () => emit('cancel');

const prepareCampaignDetails = () => {
  // Find the selected template to get its content
  const currentTemplate = selectedTemplate.value;
  const parserData = templateParserRef.value;

  // Extract template content - this should be the template message body
  const templateContent = parserData?.renderedTemplate || '';

  // Prepare template_params object with the same structure as used in contacts
  const templateParams = {
    name: currentTemplate?.name || '',
    namespace: currentTemplate?.namespace || '',
    category: currentTemplate?.category || 'UTILITY',
    language: currentTemplate?.language || 'en_US',
    processed_params: parserData?.processedParams || {},
  };

  return {
    title: state.title,
    message: templateContent,
    template_params: templateParams,
    inbox_id: state.inboxId,
    scheduled_at: formatToUTCString(state.scheduledAt),
    audience: state.selectedAudience?.map(id => ({
      id,
      type: 'Label',
    })),
  };
};

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  emit('submit', prepareCampaignDetails());
  resetState();
  handleCancel();
};

// Reset template selection when inbox changes
watch(
  () => state.inboxId,
  () => {
    state.templateId = null;
  }
);
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="t('CAMPAIGN.WHATSAPP_API.CREATE.FORM.TITLE.LABEL')"
      :placeholder="t('CAMPAIGN.WHATSAPP_API.CREATE.FORM.TITLE.PLACEHOLDER')"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label for="inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP_API.CREATE.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        id="inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!formErrors.inbox"
        :placeholder="
          hasNoEligibleInboxes
            ? t('CAMPAIGN.WHATSAPP_API.CREATE.FORM.INBOX.EMPTY_STATE')
            : t('CAMPAIGN.WHATSAPP_API.CREATE.FORM.INBOX.PLACEHOLDER')
        "
        :message="formErrors.inbox || (hasNoEligibleInboxes ? t('CAMPAIGN.WHATSAPP_API.CREATE.FORM.INBOX.EMPTY_STATE_HELP') : '')"
        :disabled="hasNoEligibleInboxes"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label for="template" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP_API.CREATE.FORM.TEMPLATE.LABEL') }}
      </label>
      <ComboBox
        id="template"
        v-model="state.templateId"
        :options="templateOptions"
        :has-error="!!formErrors.template"
        :placeholder="t('CAMPAIGN.WHATSAPP_API.CREATE.FORM.TEMPLATE.PLACEHOLDER')"
        :message="formErrors.template"
      />
    </div>

    <!-- Template Parser -->
    <WhatsAppTemplateParser
      v-if="selectedTemplate"
      ref="templateParserRef"
      :template="selectedTemplate"
      class="flex flex-col gap-4 p-4 rounded-lg bg-n-alpha-black2"
    >
      <div class="flex justify-between items-center">
        <h3 class="text-sm font-medium text-n-slate-12">
          {{ selectedTemplate.name }}
        </h3>
        <span class="text-xs text-n-slate-11">
          {{ t('CAMPAIGN.WHATSAPP_API.CREATE.FORM.TEMPLATE.LANGUAGE') }}:
          {{ selectedTemplate.language || 'en' }}
        </span>
      </div>
    </WhatsAppTemplateParser>
    
    <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
      <div class="flex flex-col gap-1">
        <label for="scheduledAt" class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ t('CAMPAIGN.WHATSAPP_API.CREATE.FORM.SCHEDULED_AT.LABEL') }}
        </label>
        <input
          id="scheduledAt"
          v-model="state.scheduledAt"
          type="datetime-local"
          :min="currentDateTime"
          class="rounded border border-n-slate-7 bg-n-alpha-black2 px-4 py-2 text-n-slate-12 outline-none focus:!border-n-slate-8"
        />
      </div>
      <div class="flex flex-col gap-1">
        <label for="audience" class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ t('CAMPAIGN.WHATSAPP_API.CREATE.FORM.AUDIENCE.LABEL') }}
        </label>
        <TagMultiSelectComboBox
          id="audience"
          v-model="state.selectedAudience"
          :options="audienceList"
          :placeholder="t('CAMPAIGN.WHATSAPP_API.CREATE.FORM.AUDIENCE.PLACEHOLDER')"
        />
      </div>
    </div>

    <div class="flex flex-col gap-1">
      <label class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP_API.CREATE.FORM.TEMPLATE.PREVIEW') }}
      </label>
      <div class="rounded border border-n-slate-7 bg-n-alpha-black2 p-3 text-sm text-n-slate-12">
        {{ templateParserRef?.processedString || selectedTemplate?.components?.[0]?.text || '' }}
      </div>
    </div>

    <div class="mt-2 flex items-center gap-2">
      <Button
        variant="primary"
        type="submit"
        size="sm"
        :disabled="isSubmitDisabled"
        >{{ t('CAMPAIGN.WHATSAPP_API.CREATE.FORM.SUBMIT') }}</Button
      >
      <Button variant="clear" size="sm" @click="handleCancel">
        {{ t('CAMPAIGN.WHATSAPP_API.CREATE.FORM.CANCEL') }}
      </Button>
    </div>
  </form>
</template>
