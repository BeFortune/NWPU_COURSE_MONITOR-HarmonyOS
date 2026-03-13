import { Want } from '@kit.AbilityKit';
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import hilog from '@ohos.hilog';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  addFormId,
  createDefaultPayload,
  loadWidgetPayload,
  removeFormId,
  toBindingObject
} from './common/CourseWidgetStore';

const LOG_DOMAIN = 0xFF22;
const LOG_TAG = 'EntryFormAbility';

/**
 * HarmonyOS Form lifecycle for the course widget.
 *
 * Official Form Kit callbacks are `onAddForm`, `onUpdateForm`, and `onRemoveForm`.
 * To match the project naming convention, this file also exposes helper methods
 * `onCreateForm` and `onDeleteForm`, which are invoked from the official callbacks.
 */
export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    return this.onCreateForm(want);
  }

  onUpdateForm(formId: string): void {
    this.handleUpdate(formId);
  }

  onRemoveForm(formId: string): void {
    this.onDeleteForm(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    hilog.info(LOG_DOMAIN, LOG_TAG, `onAcquireFormState: ${JSON.stringify(want)}`);
    return formInfo.FormState.READY;
  }

  onCreateForm(want: Want): formBindingData.FormBindingData {
    const formId = String(want.parameters?.['ohos.extra.param.key.form_identity'] ?? '');
    hilog.info(LOG_DOMAIN, LOG_TAG, `onCreateForm: ${formId}`);

    this.persistFormId(formId);

    const initialData = toBindingObject(createDefaultPayload());
    this.refreshSingleForm(formId);
    return formBindingData.createFormBindingData(initialData);
  }

  onDeleteForm(formId: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, `onDeleteForm: ${formId}`);
    this.deleteFormId(formId);
  }

  private async handleUpdate(formId: string): Promise<void> {
    try {
      const payload = await loadWidgetPayload(this.context);
      const data = formBindingData.createFormBindingData(toBindingObject(payload));
      await formProvider.updateForm(formId, data);
      await formProvider.setFormNextRefreshTime(formId, 30);
      hilog.info(LOG_DOMAIN, LOG_TAG, `onUpdateForm success: ${formId}`);
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.error(
        LOG_DOMAIN,
        LOG_TAG,
        `onUpdateForm failed: ${formId}, code=${businessError.code}, msg=${businessError.message}`
      );
    }
  }

  private async refreshSingleForm(formId: string): Promise<void> {
    if (formId.length === 0) {
      return;
    }

    try {
      const payload = await loadWidgetPayload(this.context);
      const data = formBindingData.createFormBindingData(toBindingObject(payload));
      await formProvider.updateForm(formId, data);
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, `refreshSingleForm failed: ${JSON.stringify(error)}`);
    }
  }

  private async persistFormId(formId: string): Promise<void> {
    if (formId.length === 0) {
      return;
    }
    await addFormId(this.context, formId);
  }

  private async deleteFormId(formId: string): Promise<void> {
    if (formId.length === 0) {
      return;
    }
    await removeFormId(this.context, formId);
  }
}
