// Copyright (c) 2026 NWPU Course Monitor
// HarmonyOS NEXT local notification bridge (API 16 compatible)

import common from '@ohos.app.ability.common';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import hilog from '@ohos.hilog';
import notificationManager from '@ohos.notificationManager';
import vibrator from '@ohos.vibrator';
import { FlutterPlugin, MethodCall, MethodChannel } from '@ohos/flutter_ohos';
import { FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import { MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { BusinessError } from '@kit.BasicServicesKit';

const LOG_DOMAIN = 0xFF10;
const LOG_TAG = 'NotificationAbility';
const METHOD_CHANNEL_NAME = 'nwpu/course_monitor/notification';
const REQUIRED_PERMISSIONS: Array<string> = [
  'ohos.permission.PUBLISH_AGENT_REMINDER',
  'ohos.permission.VIBRATE',
  'ohos.permission.USE_SPEAKER'
];

function logInfo(message: string) {
  hilog.info(LOG_DOMAIN, LOG_TAG, message);
}

function logError(message: string) {
  hilog.error(LOG_DOMAIN, LOG_TAG, message);
}

function logWarn(message: string) {
  hilog.warn(LOG_DOMAIN, LOG_TAG, message);
}

export default class NotificationAbility implements FlutterPlugin {
  private channel?: MethodChannel;
  private context?: common.UIAbilityContext;
  private grantedPermissions: Set<string> = new Set();
  private slotCache: Map<string, notificationManager.SlotType> = new Map();

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.context = binding.getPluginContext() as common.UIAbilityContext;
    this.channel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL_NAME);
    this.channel.setMethodCallHandler({
      onMethodCall: async (call: MethodCall, result: MethodResult) => {
        switch (call.method) {
          case 'showNotification':
            await this.handleShowNotification(call, result);
            break;
          default:
            result.notImplemented();
            break;
        }
      }
    });

    logInfo('NotificationAbility attached and listening for MethodChannel calls');
  }

  onDetachedFromEngine(_: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = undefined;
    this.context = undefined;
    this.grantedPermissions.clear();
    this.slotCache.clear();
    logInfo('NotificationAbility detached');
  }

  getUniqueClassName(): string {
    return 'NotificationAbility';
  }

  private async handleShowNotification(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const title = String(call.argument('title') ?? '');
      const body = String(call.argument('body') ?? '');
      const channelId = String(call.argument('channelId') ?? 'default');

      if (!title && !body) {
        throw new Error('title or body is required');
      }

      await this.ensurePermissions();
      await this.ensureNotificationsEnabled();
      const slotType = await this.ensureNotificationSlot(channelId);

      const request = this.buildNotificationRequest(title, body, slotType, channelId);
      await notificationManager.publish(request);
      await this.triggerVibration();

      result.success(true);
    } catch (error) {
      const businessError = error as BusinessError;
      const message = businessError?.message ?? (error as Error).message ?? String(error);
      logError(`showNotification failed: ${message}`);
      if (businessError && typeof businessError.code === 'number') {
        result.error(`ERROR_${businessError.code}`, message, businessError);
      } else {
        result.error('ERROR_NOTIFICATION', message, error);
      }
    }
  }

  private async ensurePermissions(): Promise<void> {
    if (!this.context) {
      throw new Error('Ability context is not available');
    }

    const denied = REQUIRED_PERMISSIONS.filter(permission => {
      if (this.grantedPermissions.has(permission)) {
        return false;
      }
      try {
        const status = this.context!.verifySelfPermission(permission);
        return status !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      } catch (error) {
        logWarn(`verifySelfPermission failed for ${permission}: ${JSON.stringify(error)}`);
        return true;
      }
    });

    if (denied.length > 0) {
      logInfo(`Requesting permissions: ${denied.join(',')}`);
      await this.context.requestPermissionsFromUser(denied);
      denied.forEach(permission => this.grantedPermissions.add(permission));
    }
  }

  private async ensureNotificationsEnabled(): Promise<void> {
    try {
      const enabled = await notificationManager.isNotificationEnabled();
      if (!enabled && this.context && typeof notificationManager.requestEnableNotification === 'function') {
        await notificationManager.requestEnableNotification(this.context);
      }
    } catch (error) {
      logWarn(`Checking notification switch failed: ${JSON.stringify(error)}`);
    }
  }

  private async ensureNotificationSlot(channelId: string): Promise<notificationManager.SlotType> {
    if (this.slotCache.has(channelId)) {
      return this.slotCache.get(channelId) as notificationManager.SlotType;
    }

    const slotType = this.resolveSlotType(channelId);
    const slot = {
      type: slotType,
      level: notificationManager.SlotLevel.LEVEL_3,
      desc: `NWPU Course Monitor - ${channelId}`,
      enableLight: true,
      lightColor: 0x33B5E5,
      enableVibration: true,
      vibrationValues: [0, 150, 80, 150],
      lockscreenVisibleness: notificationManager.SlotVisiblenessType.PUBLIC,
      sound: {
        soundUri: 'system/media/audio/notifications/Base.ogg'
      } as notificationManager.Sound
    } as notificationManager.NotificationSlot;

    // Cache custom slot ids for OpenHarmony API16 (slotId is not part of the type definition)
    (slot as Record<string, unknown>)['slotId'] = channelId;

    try {
      await notificationManager.addSlot(slot);
      logInfo(`Notification slot created for ${channelId}`);
    } catch (error) {
      logWarn(`addSlot failed for ${channelId}: ${JSON.stringify(error)}`);
    }

    this.slotCache.set(channelId, slotType);
    return slotType;
  }

  private resolveSlotType(channelId: string): notificationManager.SlotType {
    if (channelId.toLowerCase().includes('urgent')) {
      return notificationManager.SlotType.SOCIAL_COMMUNICATION;
    }
    if (channelId.toLowerCase().includes('silent')) {
      return notificationManager.SlotType.OTHER;
    }
    return notificationManager.SlotType.SERVICE_INFORMATION;
  }

  private buildNotificationRequest(
    title: string,
    body: string,
    slotType: notificationManager.SlotType,
    channelId: string
  ): notificationManager.NotificationRequest {
    const content = {
      contentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
      normal: {
        title,
        text: body,
        additionalText: channelId
      }
    } as notificationManager.NotificationContent;

    return {
      id: Date.now() & 0x7FFFFFFF,
      slotType,
      label: channelId,
      content,
      classification: channelId,
      deliveryTime: Date.now(),
      autoDeletedTime: 0,
      vibrationEnabled: true,
      vibrationValues: [0, 120, 60, 120],
      isAlertOnce: true
    } as notificationManager.NotificationRequest;
  }

  private async triggerVibration(): Promise<void> {
    try {
      await vibrator.startVibration({
        type: 'time',
        duration: 200
      }, {
        usage: 'notification'
      });
    } catch (error) {
      logWarn(`startVibration failed: ${JSON.stringify(error)}`);
    }
  }
}
