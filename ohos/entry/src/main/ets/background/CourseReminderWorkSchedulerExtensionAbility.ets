import WorkSchedulerExtensionAbility from '@ohos.application.WorkSchedulerExtensionAbility';
import workScheduler from '@ohos.resourceschedule.workScheduler';
import hilog from '@ohos.hilog';
import notificationManager from '@ohos.notificationManager';
import wantAgent from '@ohos.wantAgent';

const LOG_DOMAIN = 0xFF14;
const LOG_TAG = 'CourseReminderWorkExt';
const SLOT_TYPE = notificationManager.SlotType.SERVICE_INFORMATION;

export default class CourseReminderWorkSchedulerExtensionAbility extends WorkSchedulerExtensionAbility {
  private slotPrepared = false;

  async onWorkStart(workInfo: workScheduler.WorkInfo): Promise<void> {
    try {
      const params = (workInfo.parameters ?? {}) as Record<string, string | number>;
      const triggerAt = Number(params['triggerAt'] ?? Date.now());
      const now = Date.now();

      // Runtime window validation: avoid accidental early trigger.
      if (now + 30_000 < triggerAt) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, `work triggered too early, id=${workInfo.workId}`);
        return;
      }

      const title = String(params['title'] ?? '课程提醒');
      const body = String(params['body'] ?? '即将上课');
      const id = Number(params['id'] ?? workInfo.workId);
      const courseName = String(params['courseName'] ?? '');
      const time = String(params['time'] ?? '');

      await this.ensureSlot();
      const clickAgent = await this.buildClickWantAgent(courseName, time);

      const request: notificationManager.NotificationRequest = {
        id,
        slotType: SLOT_TYPE,
        content: {
          contentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title,
            text: body,
            additionalText: time
          }
        },
        wantAgent: clickAgent,
        tapDismissed: true
      } as notificationManager.NotificationRequest;

      await notificationManager.publish(request);
      hilog.info(LOG_DOMAIN, LOG_TAG, `published from work, id=${id}`);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, `onWorkStart failed: ${JSON.stringify(error)}`);
    } finally {
      try {
        await workScheduler.stopWork(workInfo, false, false);
      } catch (_) {
      }
    }
  }

  onWorkStop(workInfo: workScheduler.WorkInfo): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, `onWorkStop, workId=${workInfo.workId}`);
  }

  private async ensureSlot(): Promise<void> {
    if (this.slotPrepared) {
      return;
    }
    const slot: notificationManager.NotificationSlot = {
      type: SLOT_TYPE,
      level: notificationManager.SlotLevel.LEVEL_3,
      desc: '课程开始前提醒',
      enableVibration: true,
      vibrationValues: [0, 180, 100, 220],
      enableLight: true,
      lockscreenVisibleness: notificationManager.SlotVisiblenessType.PUBLIC
    } as notificationManager.NotificationSlot;

    try {
      await notificationManager.addSlot(slot);
    } catch (_) {
    }
    this.slotPrepared = true;
  }

  private async buildClickWantAgent(courseName: string, time: string): Promise<wantAgent.WantAgent> {
    const info: wantAgent.WantAgentInfo = {
      wants: [{
        bundleName: this.context.abilityInfo.bundleName,
        abilityName: this.context.abilityInfo.name,
        parameters: {
          fromNotification: true,
          courseName,
          time
        }
      }],
      operationType: wantAgent.OperationType.START_ABILITY,
      requestCode: Date.now() & 0x7FFF,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    return await wantAgent.getWantAgent(info);
  }
}
