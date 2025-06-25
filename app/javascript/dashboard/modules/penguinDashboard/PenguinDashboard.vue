<script>
export default {
  name: 'PenguinDashboard',
  data() {
    return {
      promptContent: '',
      isLoadingPrompt: false,
      isSavingPrompt: false,
      promptMessage: '',
      promptMessageType: '',

      envConfig: {
        SKIP_IF_AGENT_ONLINE: false,
        BOT_RESET_STATUS: true,
        ENABLE_FOLLOW_UP: true,
        FOLLOW_UP_DELAY_MINUTES: 5,
        ENABLE_CLOSE_TICKET: true,
        CLOSE_TICKET_DELAY_MINUTES: 10,
        HANDOVER_AGENT: true,
      },
      isLoadingEnv: false,
      isSavingEnv: false,
      envMessage: '',
      envMessageType: '',

      aiStatus: 'unknown',
      isLoadingAiStatus: false,
      isRestartingAi: false,
      aiServiceMessage: '',
      aiServiceMessageType: '',
      showRestartModal: false, // NEW: Control visibility of the restart confirmation modal
    };
  },
  mounted() {
    this.loadAiStatus();
  },
  methods: {
    // Helper for logging that respects production environment (fixes no-console)
    logError(message, error) {
      if (process.env.NODE_ENV !== 'production') {
        // eslint-disable-next-line no-console
        console.error(message, error);
      }
    },

    // --- System Prompt Methods ---
    async loadPrompt() {
      this.isLoadingPrompt = true;
      this.promptMessage = '';
      this.promptMessageType = '';
      try {
        const response = await fetch('/custom_api/system_prompt');
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.json();
        this.promptContent = data.content;
        this.showMessage(
          this.$t('penguin_dashboard.prompt_editor.loaded_success'),
          'success',
          'prompt'
        );
      } catch (error) {
        this.logError('Error loading system prompt:', error); // Using custom logger
        this.showMessage(
          this.$t('penguin_dashboard.prompt_editor.load_failed', {
            message: error.message,
          }),
          'error',
          'prompt'
        );
        this.promptContent = this.$t(
          'penguin_dashboard.prompt_editor.load_error_fallback'
        );
      } finally {
        this.isLoadingPrompt = false;
      }
    },
    async savePrompt() {
      this.isSavingPrompt = true;
      this.promptMessage = '';
      this.promptMessageType = '';
      try {
        const response = await fetch('/custom_api/system_prompt', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': document
              .querySelector('meta[name="csrf-token"]')
              .getAttribute('content'),
          },
          body: JSON.stringify({ content: this.promptContent }),
        });
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        this.showMessage(
          this.$t('penguin_dashboard.prompt_editor.saved_success'),
          'success',
          'prompt'
        );
      } catch (error) {
        this.logError('Error saving system prompt:', error); // Using custom logger
        this.showMessage(
          this.$t('penguin_dashboard.prompt_editor.save_failed', {
            message: error.message,
          }),
          'error',
          'prompt'
        );
      } finally {
        this.isSavingPrompt = false;
      }
    },

    // --- ENV Config Methods ---
    async loadEnvConfig() {
      this.isLoadingEnv = true;
      this.envMessage = '';
      this.envMessageType = '';
      try {
        const response = await fetch('/custom_api/env_config');
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.json();
        // Use Object.keys().forEach() for safer iteration (fixes no-restricted-syntax for for..in)
        Object.keys(this.envConfig).forEach(key => {
          if (Object.prototype.hasOwnProperty.call(data.content, key)) {
            if (typeof this.envConfig[key] === 'boolean') {
              this.envConfig[key] =
                String(data.content[key]).toLowerCase() === 'true';
            } else if (typeof this.envConfig[key] === 'number') {
              this.envConfig[key] = parseFloat(data.content[key]);
            } else {
              this.envConfig[key] = data.content[key];
            }
          }
        });
        this.showMessage(
          this.$t('penguin_dashboard.env_editor.loaded_success'),
          'success',
          'env'
        );
      } catch (error) {
        this.logError('Error loading ENV config:', error); // Using custom logger
        this.showMessage(
          this.$t('penguin_dashboard.env_editor.load_failed', {
            message: error.message,
          }),
          'error',
          'env'
        );
      } finally {
        this.isLoadingEnv = false;
      }
    },
    async saveEnvConfig() {
      this.isSavingEnv = true;
      this.envMessage = '';
      this.envMessageType = '';
      try {
        const response = await fetch('/custom_api/env_config', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ content: this.envConfig }),
        });
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        this.showMessage(
          this.$t('penguin_dashboard.env_editor.saved_success'),
          'success',
          'env',
          10000
        );
      } catch (error) {
        this.logError('Error saving ENV config:', error); // Using custom logger
        this.showMessage(
          this.$t('penguin_dashboard.env_editor.save_failed', {
            message: error.message,
          }),
          'error',
          'env'
        );
      } finally {
        this.isSavingEnv = false;
      }
    },

    // AI Service Management Methods
    async loadAiStatus() {
      this.isLoadingAiStatus = true;
      this.aiServiceMessage = '';
      this.aiServiceMessageType = '';
      try {
        const response = await fetch('/custom_api/ai_status');
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.json();
        this.aiStatus = data.status;
        this.showMessage(
          this.$t('penguin_dashboard.ai_service_mgmt.status_refreshed'),
          'success',
          'aiService'
        );
      } catch (error) {
        this.logError('Error loading AI service status:', error); // Using custom logger
        this.aiStatus = 'error';
        this.showMessage(
          this.$t('penguin_dashboard.ai_service_mgmt.status_load_failed', {
            message: error.message,
          }),
          'error',
          'aiService'
        );
      } finally {
        this.isLoadingAiStatus = false;
      }
    },

    // NEW: Methods for Confirmation Modal (fixes no-restricted-globals, no-alert for confirm)
    showRestartConfirmModal() {
      this.showRestartModal = true;
    },
    cancelRestart() {
      this.showRestartModal = false;
      this.showMessage(
        this.$t('penguin_dashboard.ai_service_mgmt.restart_cancelled'),
        'info',
        'aiService'
      );
    },
    async confirmRestart() {
      this.showRestartModal = false; // Hide modal immediately
      this.isRestartingAi = true;
      this.aiServiceMessage = '';
      this.aiServiceMessageType = '';
      try {
        const response = await fetch('/custom_api/restart_ai', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
        });
        if (!response.ok) {
          const errorData = await response.json();
          throw new Error(
            errorData.message || `HTTP error! status: ${response.status}`
          );
        }
        const data = await response.json();
        this.showMessage(data.message, 'success', 'aiService', 7000);
        await this.loadAiStatus(); // Refresh status after restart attempt
      } catch (error) {
        this.logError('Error restarting AI service:', error); // Using custom logger
        this.showMessage(
          this.$t('penguin_dashboard.ai_service_mgmt.restart_failed', {
            message: error.message,
          }),
          'error',
          'aiService',
          7000
        );
      } finally {
        this.isRestartingAi = false;
      }
    },

    showMessage(text, type, panel = 'prompt', timeout = 5000) {
      if (panel === 'prompt') {
        this.promptMessage = text;
        this.promptMessageType = type;
        setTimeout(() => {
          this.promptMessage = '';
          this.promptMessageType = '';
        }, timeout);
      } else if (panel === 'env') {
        this.envMessage = text;
        this.envMessageType = type;
        setTimeout(() => {
          this.envMessage = '';
          this.envMessageType = '';
        }, timeout);
      } else if (panel === 'aiService') {
        this.aiServiceMessage = text;
        this.aiServiceMessageType = type;
        setTimeout(() => {
          this.aiServiceMessage = '';
          this.aiServiceMessageType = '';
        }, timeout);
      }
    },
  },
};
</script>

<template>
  <div class="w-full max-w-full px-4 py-8">
    <!-- Main Title (fixed at top of our component) -->
    <h1 class="text-3xl font-semibold text-slate-900 dark:text-slate-100 mb-6">
      {{ $t('penguin_dashboard.overview_title') }}
    </h1>

    <!-- Scrollable Content Wrapper -->
    <!-- This div wraps all panels and enables vertical scrolling.
             max-h-[calc(100vh-180px)] tries to set its maximum height to the viewport height
             minus an estimated 180 pixels for Chatwoot's top navigation,
             our dashboard title, and surrounding padding.
             overflow-y-auto adds a scrollbar only when content overflows vertically.
             pb-4 adds some padding at the bottom of the scrollable area.
        -->
    <div class="max-h-[calc(100vh-180px)] overflow-y-auto pb-4">
      <!-- AI Middleware Service Management Panel (Full Width) -->
      <div class="grid grid-cols-1 gap-6 mb-6">
        <!-- This container is now a single column, full width -->
        <div class="bg-white dark:bg-slate-800 rounded-lg shadow p-6 min-w-0">
          <h2
            class="text-xl font-medium text-slate-800 dark:text-slate-200 mb-4"
          >
            {{ $t('penguin_dashboard.ai_service_mgmt.title') }}
          </h2>

          <!-- AI Status Display -->
          <div class="flex items-center mb-4">
            <span class="text-slate-700 dark:text-slate-300 font-medium mr-2"
              >{{ $t('penguin_dashboard.ai_service_mgmt.status_label') }}:</span
            >
            <span
              class="px-3 py-1 rounded-full text-sm font-semibold"
              :class="[
                aiStatus === 'active'
                  ? 'bg-green-100 text-green-800'
                  : aiStatus === 'inactive'
                    ? 'bg-orange-100 text-orange-800'
                    : aiStatus === 'failed'
                      ? 'bg-red-100 text-red-800'
                      : 'bg-slate-100 text-slate-800',
              ]"
            >
              {{ aiStatus.toUpperCase() }}
            </span>
            <span
              v-if="isLoadingAiStatus"
              class="ml-2 animate-spin h-4 w-4 border-2 border-blue-500 border-t-transparent rounded-full"
            />
          </div>

          <!-- Status Message for AI Service -->
          <div
            v-if="aiServiceMessage"
            class="p-3 rounded-lg mb-4 text-sm"
            :class="[
              aiServiceMessageType === 'success'
                ? 'bg-green-100 text-green-800'
                : 'bg-red-100 text-red-800',
            ]"
          >
            {{ aiServiceMessage }}
          </div>

          <!-- Buttons -->
          <div class="flex space-x-3">
            <button
              :disabled="isLoadingAiStatus"
              class="flex items-center px-4 py-2 bg-orange-600 text-white rounded-md hover:bg-orange-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
              @click="loadAiStatus"
            >
              <span
                v-if="isLoadingAiStatus"
                class="animate-spin mr-2 h-4 w-4 border-2 border-white border-t-transparent rounded-full"
              />
              {{
                isLoadingAiStatus
                  ? $t('penguin_dashboard.ai_service_mgmt.refreshing_status')
                  : $t('penguin_dashboard.ai_service_mgmt.refresh_status')
              }}
            </button>
            <button
              :disabled="isRestartingAi"
              class="flex items-center px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-yellow-500 disabled:opacity-50 disabled:cursor-not-allowed"
              @click="showRestartConfirmModal"
            >
              <span
                v-if="isRestartingAi"
                class="animate-spin mr-2 h-4 w-4 border-2 border-white border-t-transparent rounded-full"
              />
              {{
                isRestartingAi
                  ? $t('penguin_dashboard.ai_service_mgmt.restarting_service')
                  : $t('penguin_dashboard.ai_service_mgmt.restart_service')
              }}
            </button>
          </div>
          <p class="text-sm text-slate-500 dark:text-slate-400 mt-2">
            {{ $t('penguin_dashboard.ai_service_mgmt.restart_note') }}
          </p>
        </div>
      </div>

      <!-- Confirmation Modal for AI Restart -->
      <div
        v-if="showRestartModal"
        class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      >
        <div
          class="bg-white dark:bg-slate-800 p-6 rounded-lg shadow-xl max-w-sm w-full"
        >
          <h3
            class="text-lg font-semibold text-slate-800 dark:text-slate-100 mb-4"
          >
            {{ $t('penguin_dashboard.ai_service_mgmt.confirm_restart_title') }}
          </h3>
          <p class="text-slate-700 dark:text-slate-300 mb-6">
            {{
              $t('penguin_dashboard.ai_service_mgmt.confirm_restart_message')
            }}
          </p>
          <div class="flex justify-end space-x-3">
            <button
              class="px-4 py-2 bg-slate-200 dark:bg-slate-700 text-slate-800 dark:text-slate-200 rounded-md hover:bg-slate-300 dark:hover:bg-slate-600"
              @click="cancelRestart"
            >
              {{ $t('penguin_dashboard.ai_service_mgmt.cancel_button') }}
            </button>
            <button
              class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700"
              @click="confirmRestart"
            >
              {{ $t('penguin_dashboard.ai_service_mgmt.confirm_button') }}
            </button>
          </div>
        </div>
      </div>

      <!-- System Prompt and ENV Panels Container (Row 2, two columns) -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <!-- Panel 1: System Prompt Editor -->
        <div class="bg-white dark:bg-slate-800 rounded-lg shadow p-6 min-w-0">
          <h2
            class="text-xl font-medium text-slate-800 dark:text-slate-200 mb-4"
          >
            {{ $t('penguin_dashboard.prompt_editor.title') }}
          </h2>

          <!-- Status Message for Prompt -->
          <div
            v-if="promptMessage"
            class="p-3 rounded-lg mb-4 text-sm"
            :class="[
              promptMessageType === 'success'
                ? 'bg-green-100 text-green-800'
                : 'bg-red-100 text-red-800',
            ]"
          >
            {{ promptMessage }}
          </div>

          <!-- Textarea for Prompt Content -->
          <textarea
            v-model="promptContent"
            :placeholder="$t('penguin_dashboard.prompt_editor.placeholder')"
            class="w-full h-48 p-3 mb-4 border border-slate-300 dark:border-slate-600 rounded-md bg-slate-50 dark:bg-slate-700 text-slate-900 dark:text-slate-100 resize-y focus:outline-none focus:ring-2 focus:ring-blue-500"
          />

          <!-- Buttons for Prompt -->
          <div class="flex space-x-3">
            <button
              :disabled="isLoadingPrompt"
              class="flex items-center px-4 py-2 bg-orange-600 text-white rounded-md hover:bg-orange-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
              @click="loadPrompt"
            >
              <span
                v-if="isLoadingPrompt"
                class="animate-spin mr-2 h-4 w-4 border-2 border-white border-t-transparent rounded-full"
              />
              {{
                isLoadingPrompt
                  ? $t('penguin_dashboard.prompt_editor.loading_prompt')
                  : $t('penguin_dashboard.prompt_editor.refresh_prompt')
              }}
            </button>
            <button
              :disabled="isSavingPrompt"
              class="flex items-center px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 disabled:opacity-50 disabled:cursor-not-allowed"
              @click="savePrompt"
            >
              <span
                v-if="isSavingPrompt"
                class="animate-spin mr-2 h-4 w-4 border-2 border-white border-t-transparent rounded-full"
              />
              {{
                isSavingPrompt
                  ? $t('penguin_dashboard.prompt_editor.saving_prompt')
                  : $t('penguin_dashboard.prompt_editor.save_prompt')
              }}
            </button>
          </div>
        </div>

        <!-- Panel 2: ENV Variables Editor -->
        <div class="bg-white dark:bg-slate-800 rounded-lg shadow p-6 min-w-0">
          <h2
            class="text-xl font-medium text-slate-800 dark:text-slate-200 mb-4"
          >
            {{ $t('penguin_dashboard.env_editor.title') }}
          </h2>

          <!-- Status Message for ENV -->
          <div
            v-if="envMessage"
            class="p-3 rounded-lg mb-4 text-sm"
            :class="[
              envMessageType === 'success'
                ? 'bg-green-100 text-green-800'
                : 'bg-red-100 text-red-800',
            ]"
          >
            {{ envMessage }}
          </div>

          <div class="space-y-4">
            <!-- SKIP_IF_AGENT_ONLINE -->
            <div>
              <label class="inline-flex items-center">
                <input
                  v-model="envConfig.SKIP_IF_AGENT_ONLINE"
                  type="checkbox"
                  class="form-checkbox h-5 w-5 text-blue-600"
                />
                <span class="ml-2 text-slate-700 dark:text-slate-300">{{
                  $t('penguin_dashboard.env_editor.skip_if_agent_online')
                }}</span>
              </label>
            </div>

            <!-- BOT_RESET_STATUS -->
            <div>
              <label class="inline-flex items-center">
                <input
                  v-model="envConfig.BOT_RESET_STATUS"
                  type="checkbox"
                  class="form-checkbox h-5 w-5 text-blue-600"
                />
                <span class="ml-2 text-slate-700 dark:text-slate-300">{{
                  $t('penguin_dashboard.env_editor.bot_reset_status')
                }}</span>
              </label>
            </div>

            <!-- ENABLE_FOLLOW_UP -->
            <div>
              <label class="inline-flex items-center">
                <input
                  v-model="envConfig.ENABLE_FOLLOW_UP"
                  type="checkbox"
                  class="form-checkbox h-5 w-5 text-blue-600"
                />
                <span class="ml-2 text-slate-700 dark:text-slate-300">{{
                  $t('penguin_dashboard.env_editor.enable_follow_up')
                }}</span>
              </label>
            </div>

            <!-- FOLLOW_UP_DELAY_MINUTES -->
            <div>
              <label
                class="block text-slate-700 dark:text-slate-300 text-sm font-medium mb-1"
                >{{
                  $t('penguin_dashboard.env_editor.follow_up_delay_minutes')
                }}</label
              >
              <input
                v-model.number="envConfig.FOLLOW_UP_DELAY_MINUTES"
                type="number"
                class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-slate-50 dark:bg-slate-700 text-slate-900 dark:text-slate-100"
              />
            </div>

            <!-- ENABLE_CLOSE_TICKET -->
            <div>
              <label class="inline-flex items-center">
                <input
                  v-model="envConfig.ENABLE_CLOSE_TICKET"
                  type="checkbox"
                  class="form-checkbox h-5 w-5 text-blue-600"
                />
                <span class="ml-2 text-slate-700 dark:text-slate-300">{{
                  $t('penguin_dashboard.env_editor.enable_close_ticket')
                }}</span>
              </label>
            </div>

            <!-- CLOSE_TICKET_DELAY_MINUTES -->
            <div>
              <label
                class="block text-slate-700 dark:text-slate-300 text-sm font-medium mb-1"
                >{{
                  $t('penguin_dashboard.env_editor.close_ticket_delay_minutes')
                }}</label
              >
              <input
                v-model.number="envConfig.CLOSE_TICKET_DELAY_MINUTES"
                type="number"
                class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-slate-50 dark:bg-slate-700 text-slate-900 dark:text-slate-100"
              />
            </div>

            <!-- HANDOVER_AGENT -->
            <div>
              <label class="inline-flex items-center">
                <input
                  v-model="envConfig.HANDOVER_AGENT"
                  type="checkbox"
                  class="form-checkbox h-5 w-5 text-blue-600"
                />
                <span class="ml-2 text-slate-700 dark:text-slate-300">{{
                  $t('penguin_dashboard.env_editor.handover_agent')
                }}</span>
              </label>
            </div>
          </div>

          <!-- Buttons for ENV -->
          <div class="flex space-x-3 mt-6">
            <button
              :disabled="isLoadingEnv"
              class="flex items-center px-4 py-2 bg-orange-600 text-white rounded-md hover:bg-orange-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
              @click="loadEnvConfig"
            >
              <span
                v-if="isLoadingEnv"
                class="animate-spin mr-2 h-4 w-4 border-2 border-white border-t-transparent rounded-full"
              />
              {{
                isLoadingEnv
                  ? $t('penguin_dashboard.env_editor.loading_config')
                  : $t('penguin_dashboard.env_editor.refresh_config')
              }}
            </button>
            <button
              :disabled="isSavingEnv"
              class="flex items-center px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 disabled:opacity-50 disabled:cursor-not-allowed"
              @click="saveEnvConfig"
            >
              <span
                v-if="isSavingEnv"
                class="animate-spin mr-2 h-4 w-4 border-2 border-white border-t-transparent rounded-full"
              />
              {{
                isSavingEnv
                  ? $t('penguin_dashboard.env_editor.saving_config')
                  : $t('penguin_dashboard.env_editor.save_config')
              }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* No custom styles here. Rely on Chatwoot's global Tailwind configuration. */
</style>
