<script setup>
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  subtitle: {
    type: String,
    required: true,
  },
});

const emit = defineEmits(['create-campaign']);

const { t } = useI18n();

const onCreate = () => {
  emit('create-campaign');
};
</script>

<template>
  <EmptyStateLayout
    :title="title"
    :subtitle="subtitle"
    class="py-16"
  >
    <template #icon>
      <div class="w-16 h-16 mx-auto mb-4 bg-green-100 rounded-full flex items-center justify-center">
        <svg
          class="w-8 h-8 text-green-600"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
          />
        </svg>
      </div>
    </template>
    
    <template #actions>
      <Button
        variant="primary"
        size="medium"
        @click="onCreate"
      >
        {{ t('CAMPAIGN.WHATSAPP_API.EMPTY_STATE.CREATE_BUTTON') }}
      </Button>
    </template>
    
    <template #additional-content>
      <div class="mt-8 max-w-md mx-auto">
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div class="flex items-start">
            <div class="flex-shrink-0">
              <svg
                class="w-5 h-5 text-blue-400"
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  fill-rule="evenodd"
                  d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-blue-800">
                {{ t('CAMPAIGN.WHATSAPP_API.EMPTY_STATE.INFO_TITLE') }}
              </h3>
              <div class="mt-2 text-sm text-blue-700">
                <ul class="list-disc list-inside space-y-1">
                  <li>{{ t('CAMPAIGN.WHATSAPP_API.EMPTY_STATE.INFO_POINT_1') }}</li>
                  <li>{{ t('CAMPAIGN.WHATSAPP_API.EMPTY_STATE.INFO_POINT_2') }}</li>
                  <li>{{ t('CAMPAIGN.WHATSAPP_API.EMPTY_STATE.INFO_POINT_3') }}</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>
  </EmptyStateLayout>
</template>