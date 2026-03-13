import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import notificationManager from '@ohos.notificationManager';
import wantAgent from '@ohos.wantAgent';
import workScheduler from '@ohos.resourceschedule.workScheduler';
import { FlutterPlugin, MethodCall, MethodChannel } from '@ohos/flutter_ohos';
import { FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import { MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { BusinessError } from '@kit.BasicServicesKit';

const CHANNEL_NAME = 'com.befortune.nwpu/course_notification';
const LOG_DOMAIN = 0xFF11;
const LOG_TAG = 'MyNotificationPlugin';
const DEFAULT_SLOT = notificationManager.SlotType.SERVICE_INFORMATION;

/**
 * MyNotificationPlugin
 *
 * Flutter -> ArkTS bridge for HarmonyOS local notifications.
 *
 * Exposed methods:
 * - showReminder({title, body, id, courseName, time})
 */
export default class MyNotificationPlugin implements FlutterPlugin {
  private context?: common.UIAbilityContext;
  private channel?: MethodChannel;
  private slotPrepared = false;
  private activeWorkIds: Set<number> = new Set();

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.context = binding.getPluginContext() as common.UIAbilityContext;
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
    this.channel.setMethodCallHandler({
      onMethodCall: async (call: MethodCall, result: MethodResult) => {
        switch (call.method) {
          case 'showReminder':
            await this.handleShowReminder(call, result);
            return;
          case 'scheduleReminder':
            await this.handleScheduleReminder(call, result);
            return;
          case 'cancelReminder':
            await this.handleCancelReminder(call, result);
            return;
          case 'cancelAllReminders':
            await this.handleCancelAllReminders(result);
            return;
          default:
            result.notImplemented();
            return;
        }
      }
    });

    hilog.info(LOG_DOMAIN, LOG_TAG, 'Attached to Flutter engine');
  }

  onDetachedFromEngine(_: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = undefined;
    this.context = undefined;
    this.slotPrepared = false;
    this.activeWorkIds.clear();
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Detached from Flutter engine');
  }

  getUniqueClassName(): string {
    return 'MyNotificationPlugin';
  }

  /**
   * Handles course reminder notifications from Flutter.
   *
   * Best practices:
   * 1) Validate all incoming args from MethodChannel.
   * 2) Create/reuse notification slot before publish.
   * 3) Provide click action (WantAgent) for app deep-link wakeup.
   * 4) Always return explicit success/failure to Flutter.
   */
  private async handleShowReminder(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const title = String(call.argument('title') ?? '课程提醒');
      const body = String(call.argument('body') ?? '即将上课');
      const id = Number(call.argument('id') ?? Date.now() & 0x7FFFFFFF);
      const courseName = String(call.argument('courseName') ?? '');
      const time = String(call.argument('time') ?? '');

      await this.ensureSlotPrepared();
      const clickAgent = await this.buildClickWantAgent(courseName, time);

      const request: notificationManager.NotificationRequest = {
        id,
        slotType: DEFAULT_SLOT,
        tapDismissed: true,
        autoDeletedTime: 0,
        isAlertOnce: false,
        content: {
          contentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title,
            text: body,
            additionalText: time
          }
        },
        wantAgent: clickAgent
      } as notificationManager.NotificationRequest;

      await notificationManager.publish(request);
      hilog.info(LOG_DOMAIN, LOG_TAG, `Reminder published, id=${id}`);
      result.success(true);
    } catch (error) {
      const businessError = error as BusinessError;
      const code = businessError?.code ?? -1;
      const message = businessError?.message ?? (error as Error).message ?? 'unknown error';
      hilog.error(LOG_DOMAIN, LOG_TAG, `showReminder failed, code=${code}, msg=${message}`);
      result.error(`REMINDER_ERROR_${code}`, message, { code, message });
    }
  }

  /**
   * Schedules one future reminder with WorkScheduler.
   *
   * Plugin contract (MethodChannel args):
   * - id: number
   * - title: string
   * - body: string
   * - courseName: string
   * - time: string
   * - triggerAt: number (unix milliseconds)
   */
  private async handleScheduleReminder(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      if (!this.context) {
        throw new Error('UIAbilityContext unavailable');
      }

      const id = Number(call.argument('id') ?? Date.now() & 0x7FFFFFFF);
      const title = String(call.argument('title') ?? '课程提醒');
      const body = String(call.argument('body') ?? '即将上课');
      const courseName = String(call.argument('courseName') ?? '');
      const time = String(call.argument('time') ?? '');
      const triggerAt = Number(call.argument('triggerAt') ?? Date.now());

      const now = Date.now();
      const delay = Math.max(0, triggerAt - now);

      // WorkScheduler best practice:
      // - Use unique workId per reminder, and cancel old one before re-scheduling.
      // - Carry business parameters in `parameters` and validate at task runtime.
      await workScheduler.stopWorkById(id);

      const workInfo = {
        workId: id,
        bundleName: this.context.abilityInfo.bundleName,
        abilityName: 'CourseReminderWorkSchedulerExtensionAbility',
        // API versions differ across SDKs. Keep delay value in parameter for runtime check.
        repeatCycleTime: delay,
        isPersisted: true,
        parameters: {
          id,
          title,
          body,
          courseName,
          time,
          triggerAt
        }
      } as workScheduler.WorkInfo;

      await workScheduler.startWork(workInfo, true);
      this.activeWorkIds.add(id);
      hilog.info(LOG_DOMAIN, LOG_TAG, `scheduleReminder success, id=${id}, delay=${delay}`);
      result.success(true);
    } catch (error) {
      const businessError = error as BusinessError;
      const code = businessError?.code ?? -1;
      const message = businessError?.message ?? (error as Error).message ?? 'unknown error';
      hilog.error(LOG_DOMAIN, LOG_TAG, `scheduleReminder failed, code=${code}, msg=${message}`);
      result.error(`SCHEDULE_ERROR_${code}`, message, { code, message });
    }
  }

  private async handleCancelReminder(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const id = Number(call.argument('id'));
      if (Number.isNaN(id)) {
        throw new Error('invalid id');
      }
      await workScheduler.stopWorkById(id);
      this.activeWorkIds.delete(id);
      result.success(true);
    } catch (error) {
      const businessError = error as BusinessError;
      const code = businessError?.code ?? -1;
      const message = businessError?.message ?? (error as Error).message ?? 'unknown error';
      result.error(`CANCEL_ERROR_${code}`, message, { code, message });
    }
  }

  private async handleCancelAllReminders(result: MethodResult): Promise<void> {
    try {
      for (const workId of this.activeWorkIds) {
        await workScheduler.stopWorkById(workId);
      }
      this.activeWorkIds.clear();
      result.success(true);
    } catch (error) {
      const businessError = error as BusinessError;
      const code = businessError?.code ?? -1;
      const message = businessError?.message ?? (error as Error).message ?? 'unknown error';
      result.error(`CANCEL_ALL_ERROR_${code}`, message, { code, message });
    }
  }

  /**
   * Creates a high-priority slot once.
   *
   * Slot-level capabilities (vibration/sound) are configured here,
   * not in each publish call. This is the recommended Notification Kit pattern.
   */
  private async ensureSlotPrepared(): Promise<void> {
    if (this.slotPrepared) {
      return;
    }

    const slot: notificationManager.NotificationSlot = {
      type: DEFAULT_SLOT,
      level: notificationManager.SlotLevel.LEVEL_3,
      desc: '课程开始前提醒',
      enableVibration: true,
      vibrationValues: [0, 200, 120, 220],
      enableLight: true,
      lightColor: 0x33B5E5,
      lockscreenVisibleness: notificationManager.SlotVisiblenessType.PUBLIC
    } as notificationManager.NotificationSlot;

    try {
      await notificationManager.addSlot(slot);
      this.slotPrepared = true;
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Notification slot prepared');
    } catch (error) {
      // addSlot may throw when slot already exists in some ROM/API combinations.
      // Keep going and let publish verify final availability.
      this.slotPrepared = true;
      hilog.warn(LOG_DOMAIN, LOG_TAG, `addSlot warning: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Builds a click action so user can tap notification to return to app.
   *
   * Optional extras (courseName/time) are put into parameters and can be parsed
   * in EntryAbility for deep-link routing.
   */
  private async buildClickWantAgent(courseName: string, time: string): Promise<wantAgent.WantAgent> {
    if (!this.context) {
      throw new Error('UIAbilityContext unavailable');
    }

    const want: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: this.context.abilityInfo.bundleName,
          abilityName: this.context.abilityInfo.name,
          parameters: {
            fromNotification: true,
            courseName,
            time
          }
        }
      ],
      operationType: wantAgent.OperationType.START_ABILITY,
      requestCode: Date.now() & 0x7FFF,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };

    return await wantAgent.getWantAgent(want);
  }
}
