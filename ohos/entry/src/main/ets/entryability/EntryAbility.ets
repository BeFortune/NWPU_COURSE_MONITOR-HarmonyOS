import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { window } from '@kit.ArkUI';
import MyNotificationPlugin from '../MyNotificationPlugin';

/**
 * EntryAbility
 *
 * Registers Flutter generated plugins and custom notification plugin.
 * Keep the channel registration here to ensure MethodChannel is available
 * as soon as Flutter engine is configured.
 */
export default class EntryAbility extends FlutterAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    super.onWindowStageCreate(windowStage);
  }

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine);

    // 1) Register all auto-generated Flutter plugins.
    GeneratedPluginRegistrant.registerWith(flutterEngine);

    // 2) Register custom OHOS notification MethodChannel plugin.
    this.addPlugin(new MyNotificationPlugin());
  }
}
