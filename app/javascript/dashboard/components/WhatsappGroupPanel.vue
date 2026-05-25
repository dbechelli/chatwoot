<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import axios from 'axios';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  conversationId: {
    type: [String, Number],
    required: true,
  },
  accountId: {
    type: [String, Number],
    required: true,
  },
});

const { t } = useI18n();
const alert = useAlert();

const loading = ref(false);
const groupInfo = ref(null);
const showAddMemberModal = ref(false);
const showEditNameModal = ref(false);
const newMemberPhone = ref('');
const newMemberName = ref('');
const newGroupName = ref('');

const groupName = computed(
  () => groupInfo.value?.name || t('WHATSAPP_GROUPS.UNKNOWN_GROUP')
);
const members = computed(() => groupInfo.value?.members || []);
const participantCount = computed(
  () => groupInfo.value?.participant_count || 0
);

const loadGroupInfo = async () => {
  loading.value = true;
  try {
    const response = await axios.get(
      `/api/v1/accounts/${props.accountId}/conversations/${props.conversationId}/whatsapp_groups`
    );
    groupInfo.value = response.data;
  } catch (error) {
    alert.error(t('WHATSAPP_GROUPS.LOAD_ERROR'));
  } finally {
    loading.value = false;
  }
};

const updateGroupName = async () => {
  if (!newGroupName.value.trim()) return;

  loading.value = true;
  try {
    await axios.post(
      `/api/v1/accounts/${props.accountId}/conversations/${props.conversationId}/whatsapp_groups/update_name`,
      { name: newGroupName.value }
    );
    alert.success(t('WHATSAPP_GROUPS.NAME_UPDATED'));
    showEditNameModal.value = false;
    await loadGroupInfo();
  } catch (error) {
    alert.error(t('WHATSAPP_GROUPS.UPDATE_ERROR'));
  } finally {
    loading.value = false;
  }
};

const addMember = async () => {
  if (!newMemberPhone.value.trim()) return;

  loading.value = true;
  try {
    await axios.post(
      `/api/v1/accounts/${props.accountId}/conversations/${props.conversationId}/whatsapp_groups/add_member`,
      {
        phone_number: newMemberPhone.value,
        name: newMemberName.value,
      }
    );
    alert.success(t('WHATSAPP_GROUPS.MEMBER_ADDED'));
    showAddMemberModal.value = false;
    newMemberPhone.value = '';
    newMemberName.value = '';
    await loadGroupInfo();
  } catch (error) {
    alert.error(t('WHATSAPP_GROUPS.ADD_MEMBER_ERROR'));
  } finally {
    loading.value = false;
  }
};

const showConfirmRemove = ref(false);
const memberToRemove = ref(null);

const confirmRemoveMember = phoneNumber => {
  memberToRemove.value = phoneNumber;
  showConfirmRemove.value = true;
};

const removeMember = async () => {
  if (!memberToRemove.value) return;

  loading.value = true;
  try {
    await axios.post(
      `/api/v1/accounts/${props.accountId}/conversations/${props.conversationId}/whatsapp_groups/remove_member`,
      { phone_number: memberToRemove.value }
    );
    alert.success(t('WHATSAPP_GROUPS.MEMBER_REMOVED'));
    showConfirmRemove.value = false;
    memberToRemove.value = null;
    await loadGroupInfo();
  } catch (error) {
    alert.error(t('WHATSAPP_GROUPS.REMOVE_MEMBER_ERROR'));
  } finally {
    loading.value = false;
  }
};

const promoteAdmin = async phoneNumber => {
  loading.value = true;
  try {
    await axios.post(
      `/api/v1/accounts/${props.accountId}/conversations/${props.conversationId}/whatsapp_groups/promote_admin`,
      { phone_number: phoneNumber }
    );
    alert.success(t('WHATSAPP_GROUPS.ADMIN_PROMOTED'));
    await loadGroupInfo();
  } catch (error) {
    alert.error(t('WHATSAPP_GROUPS.PROMOTE_ERROR'));
  } finally {
    loading.value = false;
  }
};

const demoteAdmin = async phoneNumber => {
  loading.value = true;
  try {
    await axios.post(
      `/api/v1/accounts/${props.accountId}/conversations/${props.conversationId}/whatsapp_groups/demote_admin`,
      { phone_number: phoneNumber }
    );
    alert.success(t('WHATSAPP_GROUPS.ADMIN_DEMOTED'));
    await loadGroupInfo();
  } catch (error) {
    alert.error(t('WHATSAPP_GROUPS.DEMOTE_ERROR'));
  } finally {
    loading.value = false;
  }
};

const syncMembers = async () => {
  loading.value = true;
  try {
    await axios.post(
      `/api/v1/accounts/${props.accountId}/conversations/${props.conversationId}/whatsapp_groups/sync_members`
    );
    alert.success(t('WHATSAPP_GROUPS.MEMBERS_SYNCED'));
    await loadGroupInfo();
  } catch (error) {
    alert.error(t('WHATSAPP_GROUPS.SYNC_ERROR'));
  } finally {
    loading.value = false;
  }
};

const openEditNameModal = () => {
  newGroupName.value = groupName.value;
  showEditNameModal.value = true;
};

onMounted(() => {
  loadGroupInfo();
});
</script>

<template>
  <div class="flex flex-col h-full bg-white">
    <div class="p-4 border-b border-slate-200">
      <div class="flex items-center justify-between">
        <h3 class="text-lg font-semibold text-slate-900">
          {{ t('WHATSAPP_GROUPS.TITLE') }}
        </h3>
        <button
          class="px-3 py-1 text-sm font-medium text-blue-700 bg-blue-100 rounded-lg hover:bg-blue-200"
          @click="syncMembers"
        >
          {{ t('WHATSAPP_GROUPS.SYNC_MEMBERS') }}
        </button>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center flex-1 p-4">
      <span class="text-slate-600">{{ t('WHATSAPP_GROUPS.LOADING') }}</span>
    </div>

    <div v-else class="flex-1 overflow-y-auto">
      <!-- Group Info -->
      <div class="p-4 border-b border-slate-200">
        <div class="flex items-center justify-between mb-2">
          <h4 class="text-base font-medium text-slate-900">{{ groupName }}</h4>
          <button
            class="text-sm text-blue-600 hover:text-blue-800"
            @click="openEditNameModal"
          >
            {{ t('WHATSAPP_GROUPS.EDIT_NAME') }}
          </button>
        </div>
        <p class="text-sm text-slate-600">
          {{
            t('WHATSAPP_GROUPS.PARTICIPANT_COUNT', { count: participantCount })
          }}
        </p>
      </div>

      <!-- Members List -->
      <div class="p-4">
        <div class="flex items-center justify-between mb-3">
          <h5 class="text-sm font-semibold text-slate-700">
            {{ t('WHATSAPP_GROUPS.MEMBERS') }}
          </h5>
          <button
            class="px-3 py-1 text-sm font-medium text-green-700 bg-green-100 rounded-lg hover:bg-green-200"
            @click="showAddMemberModal = true"
          >
            {{ t('WHATSAPP_GROUPS.ADD_MEMBER') }}
          </button>
        </div>

        <div class="space-y-2">
          <div
            v-for="member in members"
            :key="member.phone_number"
            class="flex items-center justify-between p-3 rounded-lg bg-slate-50"
          >
            <div class="flex-1">
              <p class="text-sm font-medium text-slate-900">
                {{ member.name || member.phone_number }}
                <span
                  v-if="member.is_admin"
                  class="ml-2 px-2 py-0.5 text-xs font-medium text-orange-800 bg-orange-100 rounded-full"
                >
                  {{ t('WHATSAPP_GROUPS.ADMIN') }}
                </span>
              </p>
              <p v-if="member.name" class="text-xs text-slate-600">
                {{ member.phone_number }}
              </p>
            </div>
            <div class="flex gap-2">
              <button
                v-if="!member.is_admin"
                class="px-2 py-1 text-xs text-blue-700 bg-blue-100 rounded hover:bg-blue-200"
                @click="promoteAdmin(member.phone_number)"
              >
                {{ t('WHATSAPP_GROUPS.PROMOTE') }}
              </button>
              <button
                v-else
                class="px-2 py-1 text-xs text-orange-700 bg-orange-100 rounded hover:bg-orange-200"
                @click="demoteAdmin(member.phone_number)"
              >
                {{ t('WHATSAPP_GROUPS.DEMOTE') }}
              </button>
              <button
                class="px-2 py-1 text-xs text-red-700 bg-red-100 rounded hover:bg-red-200"
                @click="confirmRemoveMember(member.phone_number)"
              >
                {{ t('WHATSAPP_GROUPS.REMOVE') }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Add Member Modal -->
    <teleport to="body">
      <div
        v-if="showAddMemberModal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
        @click.self="showAddMemberModal = false"
      >
        <div class="w-full max-w-md p-6 bg-white rounded-lg shadow-xl">
          <h4 class="mb-4 text-lg font-semibold text-slate-900">
            {{ t('WHATSAPP_GROUPS.ADD_MEMBER') }}
          </h4>
          <div class="mb-4">
            <label class="block mb-1 text-sm font-medium text-slate-700">
              {{ t('WHATSAPP_GROUPS.PHONE_NUMBER') }}
            </label>
            <input
              v-model="newMemberPhone"
              type="text"
              class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              :placeholder="t('WHATSAPP_GROUPS.PHONE_PLACEHOLDER')"
            />
          </div>
          <div class="mb-4">
            <label class="block mb-1 text-sm font-medium text-slate-700">
              {{ t('WHATSAPP_GROUPS.NAME_LABEL') }}
            </label>
            <input
              v-model="newMemberName"
              type="text"
              class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              :placeholder="t('WHATSAPP_GROUPS.NAME_PLACEHOLDER')"
            />
          </div>
          <div class="flex justify-end gap-2">
            <button
              class="px-4 py-2 text-sm font-medium text-slate-700 bg-slate-100 rounded-lg hover:bg-slate-200"
              @click="showAddMemberModal = false"
            >
              {{ t('WHATSAPP_GROUPS.CANCEL') }}
            </button>
            <button
              class="px-4 py-2 text-sm font-medium text-white bg-green-600 rounded-lg hover:bg-green-700"
              @click="addMember"
            >
              {{ t('WHATSAPP_GROUPS.ADD') }}
            </button>
          </div>
        </div>
      </div>
    </teleport>

    <!-- Confirm Remove Modal -->
    <teleport to="body">
      <div
        v-if="showConfirmRemove"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
        @click.self="showConfirmRemove = false"
      >
        <div class="w-full max-w-md p-6 bg-white rounded-lg shadow-xl">
          <h4 class="mb-4 text-lg font-semibold text-slate-900">
            {{ t('WHATSAPP_GROUPS.CONFIRM_REMOVE_TITLE') }}
          </h4>
          <p class="mb-6 text-sm text-slate-600">
            {{ t('WHATSAPP_GROUPS.CONFIRM_REMOVE_MEMBER') }}
          </p>
          <div class="flex justify-end gap-2">
            <button
              class="px-4 py-2 text-sm font-medium text-slate-700 bg-slate-100 rounded-lg hover:bg-slate-200"
              @click="showConfirmRemove = false"
            >
              {{ t('WHATSAPP_GROUPS.CANCEL') }}
            </button>
            <button
              class="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-lg hover:bg-red-700"
              @click="removeMember"
            >
              {{ t('WHATSAPP_GROUPS.REMOVE') }}
            </button>
          </div>
        </div>
      </div>
    </teleport>

    <!-- Edit Name Modal -->
    <teleport to="body">
      <div
        v-if="showEditNameModal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
        @click.self="showEditNameModal = false"
      >
        <div class="w-full max-w-md p-6 bg-white rounded-lg shadow-xl">
          <h4 class="mb-4 text-lg font-semibold text-slate-900">
            {{ t('WHATSAPP_GROUPS.EDIT_GROUP_NAME') }}
          </h4>
          <div class="mb-4">
            <label class="block mb-1 text-sm font-medium text-slate-700">
              {{ t('WHATSAPP_GROUPS.GROUP_NAME') }}
            </label>
            <input
              v-model="newGroupName"
              type="text"
              class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              :placeholder="t('WHATSAPP_GROUPS.GROUP_NAME_PLACEHOLDER')"
            />
          </div>
          <div class="flex justify-end gap-2">
            <button
              class="px-4 py-2 text-sm font-medium text-slate-700 bg-slate-100 rounded-lg hover:bg-slate-200"
              @click="showEditNameModal = false"
            >
              {{ t('WHATSAPP_GROUPS.CANCEL') }}
            </button>
            <button
              class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700"
              @click="updateGroupName"
            >
              {{ t('WHATSAPP_GROUPS.SAVE') }}
            </button>
          </div>
        </div>
      </div>
    </teleport>
  </div>
</template>
