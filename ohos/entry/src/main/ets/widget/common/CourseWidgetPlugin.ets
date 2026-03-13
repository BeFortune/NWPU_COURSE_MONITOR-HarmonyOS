import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import { FlutterPlugin, MethodCall, MethodChannel } from '@ohos/flutter_ohos';
import { FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import { MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { BusinessError } from '@kit.BasicServicesKit';
import { WidgetPayload, refreshAllForms, saveWidgetPayload } from './CourseWidgetStore';

const CHANNEL_NAME = 'com.befortune.nwpu/course_widget';
const LOG_DOMAIN = 0xFF21;
const LOG_TAG = 'CourseWidgetPlugin';

export default class CourseWidgetPlugin implements FlutterPlugin {
  private channel?: MethodChannel;
  private context?: common.UIAbilityContext;

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.context = binding.getPluginContext() as common.UIAbilityContext;
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
    this.channel.setMethodCallHandler({
      onMethodCall: async (call: MethodCall, result: MethodResult) => {
        switch (call.method) {
          case 'updateWidget':
            await this.handleUpdateWidget(call, result);
            return;
          default:
            result.notImplemented();
            return;
        }
      }
    });

    hilog.info(LOG_DOMAIN, LOG_TAG, 'Course widget channel attached');
  }

  onDetachedFromEngine(_: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = undefined;
    this.context = undefined;
  }

  getUniqueClassName(): string {
    return 'CourseWidgetPlugin';
  }

  private async handleUpdateWidget(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      if (!this.context) {
        throw new Error('UIAbilityContext unavailable');
      }

      const payload = this.parsePayload(call);
      await saveWidgetPayload(this.context, payload);
      await refreshAllForms(this.context, payload);
      result.success(true);
    } catch (error) {
      const businessError = error as BusinessError;
      const code = businessError?.code ?? -1;
      const message = businessError?.message ?? (error as Error).message ?? 'unknown error';
      hilog.error(LOG_DOMAIN, LOG_TAG, `updateWidget failed: ${code} ${message}`);
      result.error(`WIDGET_UPDATE_${code}`, message, { code, message });
    }
  }

  private parsePayload(call: MethodCall): WidgetPayload {
    const rawCourses = call.argument('courses');
    const dateText = String(call.argument('dateText') ?? '今日课程');
    const generatedAt = String(call.argument('generatedAt') ?? '--:--');

    const courses = Array.isArray(rawCourses)
      ? rawCourses.map(item => {
          const map = item as Record<string, Object>;
          return {
            courseName: String(map['courseName'] ?? '未命名课程'),
            timeRange: String(map['timeRange'] ?? '--:--'),
            location: String(map['location'] ?? '未设置'),
            status: String(map['status'] ?? 'upcoming')
          };
        })
      : [];

    return {
      dateText,
      generatedAt,
      courses
    };
  }
}
