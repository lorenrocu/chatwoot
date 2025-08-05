<script setup>
import { ref, computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import filterQueryGenerator from 'dashboard/helper/filterQueryGenerator';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const emit = defineEmits(['export']);

const { t } = useI18n();
const route = useRoute();

const dialogRef = ref(null);
const downloadDirect = ref(true); // Por defecto, descarga directa

const segments = useMapGetter('customViews/getContactCustomViews');
const appliedFilters = useMapGetter('contacts/getAppliedContactFilters');
const uiFlags = useMapGetter('contacts/getUIFlags');
const isExportingContact = computed(() => uiFlags.value.isExporting);

const activeSegmentId = computed(() => route.params.segmentId);
const activeSegment = computed(() =>
  activeSegmentId.value
    ? segments.value.find(view => view.id === Number(activeSegmentId.value))
    : undefined
);

const exportContacts = async () => {
  let query = { payload: [] };

  if (activeSegmentId.value && activeSegment.value) {
    query = activeSegment.value.query;
  } else if (Object.keys(appliedFilters.value).length > 0) {
    query = filterQueryGenerator(appliedFilters.value);
  }

  emit('export', {
    ...query,
    label: route.params.label || '',
    download_direct: downloadDirect.value,
  });
};

const handleDialogConfirm = async () => {
  await exportContacts();
  dialogRef.value?.close();
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.TITLE')"
    :description="
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.DESCRIPTION')
    "
    :confirm-button-label="
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.CONFIRM')
    "
    :is-loading="isExportingContact"
    :disable-confirm-button="isExportingContact"
    @confirm="handleDialogConfirm"
  >
    <template #default>
      <div class="mt-4">
        <label class="flex items-center space-x-2">
          <input
            v-model="downloadDirect"
            type="checkbox"
            class="form-checkbox h-4 w-4 text-blue-600"
          />
          <span class="text-sm text-gray-700">
            {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.DOWNLOAD_DIRECT') }}
          </span>
        </label>
        <p class="text-xs text-gray-500 mt-1">
          {{ downloadDirect 
            ? t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.DOWNLOAD_DIRECT_DESCRIPTION') 
            : t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.EMAIL_DESCRIPTION') 
          }}
        </p>
      </div>
    </template>
  </Dialog>
</template>
